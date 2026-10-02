import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';
import '../models/geofence_state.dart';
import '../models/heritage_challenge.dart';
import '../models/heritage_site.dart';
import '../models/trek_session.dart';
import '../providers/heritage_trek_providers.dart';
import '../services/geofence_checker.dart';
import '../services/location_service.dart';
import '../services/step_tracker_service.dart';
import '../services/trek_distance_calculator.dart';
import '../services/walking_route_service.dart';

/// Extension to replicate FlutterFlow's `.divide(...)` convenience method.
extension ListDivideExtension on List<Widget> {
  List<Widget> divide(Widget separator) {
    if (isEmpty || length == 1) return this;
    final List<Widget> result = [];
    for (var i = 0; i < length; i++) {
      result.add(this[i]);
      if (i != length - 1) {
        result.add(separator);
      }
    }
    return result;
  }
}

/// FlutterFlow-compatible Stat Item widget.
class StatItemWidget extends StatelessWidget {
  final Widget icon;
  final Color color;
  final String value;
  final String label;

  const StatItemWidget({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// FlutterFlow-compatible Icon Button widget.
class FlutterFlowIconButton extends StatelessWidget {
  final double borderRadius;
  final double buttonSize;
  final Color fillColor;
  final Widget icon;
  final VoidCallback onPressed;

  const FlutterFlowIconButton({
    super.key,
    required this.borderRadius,
    required this.buttonSize,
    required this.fillColor,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onPressed,
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Center(child: icon),
        ),
      ),
    );
  }
}

/// Heritage Trek Screen / Widget.
///
/// Implements the FlutterFlow presentation design:
/// - Full-screen background map layout
/// - Glassmorphic top navigation bar with blur
/// - Floating destination card with temple badge, name, distance & walk-time
/// - Open map viewport
/// - Bottom gradient overlay with rounded HUD card
/// - 3-column stats: Steps (pedometer), Distance (GPS), Progress (%)
/// - Linear progress indicator bar
/// - Live guidance and arrival flow
///
/// Binds directly to Phase 1 & 2 Riverpod services:
/// - Foreground GPS via [LocationService]
/// - GPS distance accumulation via [TrekDistanceCalculator] (25m accuracy filter)
/// - Pedometer steps via [StepTrackerService] (kept completely separate from GPS)
/// - 30m geofence with 5 consecutive readings via [GeofenceChecker]
/// - [HeritageSiteRepository] for destination data
class HeritageTrekWidget extends ConsumerStatefulWidget {
  final String siteId;

  const HeritageTrekWidget({
    super.key,
    required this.siteId,
  });

  static const String routeName = 'HeritageTrek';
  static const String routePath = '/heritageTrek';

  @override
  ConsumerState<HeritageTrekWidget> createState() => _HeritageTrekWidgetState();
}

/// Alias for router and backward compatibility.
typedef HeritageTrekScreen = HeritageTrekWidget;

class _HeritageTrekWidgetState extends ConsumerState<HeritageTrekWidget> {
  final MapController _mapController = MapController();
  final TrekDistanceCalculator _distanceCalculator = TrekDistanceCalculator();
  final GeofenceChecker _geofenceChecker = GeofenceChecker();

  LocationService? _locationService;
  StepTrackerService? _stepTrackerService;
  WalkingRouteService? _walkingRouteService;

  late HeritageSite _destination;
  TrekSession? _session;
  bool _isInitializing = true;
  String? _errorMessage;

  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription<int>? _stepSubscription;

  // Live display metrics
  double _distanceToDestination = 0.0;
  LatLng? _currentPosition;

  // Real road walking route to destination
  List<LatLng> _walkingRoutePoints = [];
  LatLng? _lastRoutedPosition;
  DateTime? _lastRouteFetchTime;
  bool _isFetchingRoute = false;

  @override
  void initState() {
    super.initState();
    _initializeTrek();
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  Future<void> _initializeTrek() async {
    final repo = ref.read(heritageSiteRepositoryProvider);
    final site = repo.getSiteById(widget.siteId);

    if (site == null) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Heritage site "${widget.siteId}" not found.';
      });
      return;
    }

    _destination = site;

    // Cache services before any async gap
    final locationService = ref.read(locationServiceProvider);
    final stepTracker = ref.read(stepTrackerServiceProvider);
    final walkingRouteService = ref.read(walkingRouteServiceProvider);
    _locationService = locationService;
    _stepTrackerService = stepTracker;
    _walkingRouteService = walkingRouteService;

    // Request location permission
    final granted = await locationService.requestPermission();

    if (!granted) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage =
            'Location permission is required for Heritage Trek.\n\n'
            'Please grant location access in device settings to '
            'track your walking distance to ${site.nameEn}.';
      });
      return;
    }

    // Initialize session
    _session = TrekSession(
      destination: _destination,
      startedAt: DateTime.now(),
    );

    // Initial estimation to destination
    _distanceToDestination = _destination.distanceFromStartKm * 1000.0;

    // Start GPS tracking
    await locationService.startListening();
    _gpsSubscription = locationService.positionStream.listen(
      _onGpsUpdate,
      onError: (Object err) {
        debugPrint('[HeritageTrek] GPS stream error: $err');
      },
      cancelOnError: false,
    );

    // Start pedometer tracking (completely separate from GPS distance)
    stepTracker.startListening();
    _stepSubscription = stepTracker.stepStream.listen(
      _onStepUpdate,
      onError: (Object err) {
        debugPrint('[HeritageTrek] Pedometer stream error: $err');
      },
      cancelOnError: false,
    );

    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  void _onGpsUpdate(Position position) {
    if (_session == null || _session!.isCompleted) return;

    final currentLatLng = LatLng(position.latitude, position.longitude);

    // 1. Accumulate GPS distance through accuracy and jitter filters
    _distanceCalculator.addPosition(position);

    // 2. Geofence evaluation: 30m radius + 5 consecutive valid readings
    final newGeofenceState = _geofenceChecker.check(
      currentPosition: position,
      destination: _destination,
      currentState: _session!.geofenceState,
    );

    // 3. Real-time distance to destination
    final distToDest = _geofenceChecker.distanceToSite(
      currentPosition: position,
      destination: _destination,
    );

    // 4. Update session state
    setState(() {
      _currentPosition = currentLatLng;
      _distanceToDestination = distToDest;
      _session = _session!.copyWith(
        gpsDistanceMeters: _distanceCalculator.totalDistanceMeters,
        breadcrumbs: _distanceCalculator.breadcrumbs,
        geofenceState: newGeofenceState,
        isCompleted: newGeofenceState.hasArrived,
      );
    });

    // 5. Follow user on map
    try {
      _mapController.move(currentLatLng, _mapController.camera.zoom);
    } catch (_) {
      // Map controller may not be mounted yet
    }

    // 6. Update road walking route to destination
    _updateWalkingRoute(currentLatLng);

    // 7. Handle arrival when confirmed
    if (newGeofenceState.hasArrived) {
      _onArrival();
    }
  }

  Future<void> _updateWalkingRoute(LatLng origin) async {
    if (_isFetchingRoute || _session == null || _session!.isCompleted) return;
    final now = DateTime.now();

    // Re-query routing when:
    // 1. First time (_lastRoutedPosition == null)
    // 2. OR user has moved >= 35m from last routed position AND at least 10s elapsed
    if (_lastRoutedPosition != null) {
      final movedMeters = Geolocator.distanceBetween(
        _lastRoutedPosition!.latitude,
        _lastRoutedPosition!.longitude,
        origin.latitude,
        origin.longitude,
      );
      if (movedMeters < 35.0) return;
      if (_lastRouteFetchTime != null &&
          now.difference(_lastRouteFetchTime!).inSeconds < 10) {
        return;
      }
    }

    _isFetchingRoute = true;
    _lastRouteFetchTime = now;
    _lastRoutedPosition = origin;

    final destLatLng = LatLng(_destination.latitude, _destination.longitude);
    final routeService = _walkingRouteService ?? WalkingRouteService();

    try {
      final points = await routeService.fetchWalkingRoute(
        origin: origin,
        destination: destLatLng,
      );
      if (mounted && points.isNotEmpty) {
        setState(() {
          _walkingRoutePoints = points;
        });
      }
    } catch (e) {
      debugPrint('[HeritageTrek] Route fetch error: $e');
    } finally {
      _isFetchingRoute = false;
    }
  }

  void _onStepUpdate(int steps) {
    if (_session == null || _session!.isCompleted) return;
    // Step count is tracked separately and NEVER added to GPS distance
    setState(() {
      _session = _session!.copyWith(pedometerSteps: steps);
    });
  }

  void _onArrival() {
    _stopTracking();
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.primaryGold.withValues(alpha: 0.5),
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: AppTheme.primaryGold, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'You\'ve Arrived!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to ${_destination.nameEn}!',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              _destination.nameOr,
              style: TextStyle(
                color: AppTheme.primaryGold.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.accentGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppTheme.primaryGold, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '+${_destination.bonusXp} XP earned!',
                    style: const TextStyle(
                      color: AppTheme.accentGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ready for your fitness challenge?',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/journey');
            },
            child: const Text('Later', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.fitness_center, size: 18),
            label: const Text('Start Challenge'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              final challenge = HeritageChallenge.fromSite(_destination);
              context.push('/live-squat-test', extra: challenge);
            },
          ),
        ],
      ),
    );
  }

  void _stopTracking() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _stepSubscription?.cancel();
    _stepSubscription = null;

    _locationService?.stopListening();
    _stepTrackerService?.stopListening();
    _walkingRoutePoints.clear();
  }

  void _showInfoDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.temple_hindu_rounded, color: AppTheme.primaryGold, size: 24),
                const SizedBox(width: 10),
                Text(
                  _destination.nameEn,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _destination.nameOr,
              style: TextStyle(
                color: AppTheme.primaryGold.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _destination.descEn,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GPS Accuracy Gate: ≤ 25m',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                ),
                Text(
                  'Geofence: 30m (5 hits)',
                  style: TextStyle(color: AppTheme.accentGreen.withValues(alpha: 0.8), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E14),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryGold),
              const SizedBox(height: 16),
              Text(
                'Initializing GPS & step tracker...',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E14),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, color: AppTheme.alertRed, size: 56),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Open Settings'),
                  onPressed: () => Geolocator.openLocationSettings(),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isInitializing = true;
                      _errorMessage = null;
                    });
                    _initializeTrek();
                  },
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final session = _session!;
    final destLatLng = LatLng(_destination.latitude, _destination.longitude);
    final mapCenter = _currentPosition ?? destLatLng;

    // Distance metrics
    final gpsDistKm = session.gpsDistanceMeters / 1000.0;
    final totalTargetMeters = _destination.distanceFromStartKm > 0
        ? _destination.distanceFromStartKm * 1000.0
        : 2400.0;
    final totalTargetKm = totalTargetMeters / 1000.0;
    final distRemainingKm = _distanceToDestination / 1000.0;

    // Walk time estimate (~4.5 km/h)
    final walkTimeMinutes = ((_distanceToDestination / 1000.0) / 4.5 * 60).ceil().clamp(1, 999);

    // Progress percentage
    final progressFraction = (session.gpsDistanceMeters / totalTargetMeters).clamp(0.0, 1.0);
    final progressPercent = (progressFraction * 100).toInt();

    // Distance display formatting
    final String distWalkedDisplay = gpsDistKm < 1.0
        ? '${session.gpsDistanceMeters.toStringAsFixed(0)} m'
        : '${gpsDistKm.toStringAsFixed(1)} km';
    final String distRemainingDisplay = distRemainingKm < 1.0
        ? '${_distanceToDestination.toStringAsFixed(0)} m'
        : '${distRemainingKm.toStringAsFixed(1)} km';

    // Guidance text
    String guidanceText;
    if (session.isCompleted) {
      guidanceText = 'You have arrived at ${_destination.nameEn}!';
    } else if (session.geofenceState.consecutiveHitsInZone > 0) {
      guidanceText =
          'Entering arrival zone (${session.geofenceState.consecutiveHitsInZone}/${GeofenceState.requiredConsecutiveHits})...';
    } else if (_distanceToDestination <= 30) {
      guidanceText = 'Hold position inside the site boundary to confirm arrival.';
    } else {
      guidanceText = 'Walk to the heritage site to complete this challenge';
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFF0A0E14),
        body: Stack(
          alignment: AlignmentDirectional.topStart,
          children: [
            // ── LAYER 1: Full-Screen Map (flutter_map replacing Google Maps) ──
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: 15.0,
                  minZoom: 6,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.fitodyssey.app',
                  ),
                  // Walking route to destination following real pedestrian roads/paths
                  if (_walkingRoutePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        // Luminous amber background glow for high visibility against dark map tiles
                        Polyline(
                          points: [
                            if (_currentPosition != null) _currentPosition!,
                            ..._walkingRoutePoints,
                          ],
                          color: AppTheme.primaryGold.withValues(alpha: 0.35),
                          strokeWidth: 8.0,
                        ),
                        // Crisp road walking line
                        Polyline(
                          points: [
                            if (_currentPosition != null) _currentPosition!,
                            ..._walkingRoutePoints,
                          ],
                          color: AppTheme.primaryGold,
                          strokeWidth: 4.5,
                        ),
                      ],
                    ),
                  // User breadcrumb polyline
                  if (session.breadcrumbs.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: session.breadcrumbs,
                          color: AppTheme.secondaryCyan,
                          strokeWidth: 4.0,
                        ),
                      ],
                    ),
                  // 30m Geofence arrival radius around destination
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: destLatLng,
                        radius: GeofenceState.arrivalRadiusMeters,
                        useRadiusInMeter: true,
                        color: AppTheme.accentGreen.withValues(alpha: 0.18),
                        borderColor: AppTheme.accentGreen.withValues(alpha: 0.6),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // Destination marker (Heritage site)
                      Marker(
                        point: destLatLng,
                        width: 48,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryGold,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGold.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.temple_hindu_rounded,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      // Current user position marker
                      if (_currentPosition != null)
                        Marker(
                          point: _currentPosition!,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.secondaryCyan,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.secondaryCyan.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── LAYER 2: FlutterFlow Floating HUD Presentation Layer ──
            SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Blurred Navigation Bar
                  ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xCC0A0E14),
                          shape: BoxShape.rectangle,
                        ),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FlutterFlowIconButton(
                                borderRadius: 8,
                                buttonSize: 40,
                                fillColor: Colors.transparent,
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _stopTracking();
                                  context.pop();
                                },
                              ),
                              const Text(
                                'Heritage Trek',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.0,
                                ),
                              ),
                              FlutterFlowIconButton(
                                borderRadius: 8,
                                buttonSize: 40,
                                fillColor: Colors.transparent,
                                icon: const Icon(
                                  Icons.info_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 22,
                                ),
                                onPressed: _showInfoDialog,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. Floating Destination Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(16),
                        shape: BoxShape.rectangle,
                        border: Border.all(
                          color: const Color(0xFF282832),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0x26FF9F1C),
                                borderRadius: BorderRadius.circular(12),
                                shape: BoxShape.rectangle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.temple_hindu_rounded,
                                color: AppTheme.primaryGold,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _destination.nameEn,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$distRemainingDisplay away • $walkTimeMinutes min walk',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Open Viewport Spacer for the Map
                  const Spacer(),

                  // 4. Bottom Controls with Gradient Background
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0A0E14), Color(0x000A0E14)],
                        stops: [0.65, 1.0],
                        begin: AlignmentDirectional(0, 1),
                        end: AlignmentDirectional(0, -1),
                      ),
                      shape: BoxShape.rectangle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Inner HUD Card
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF161B22),
                              borderRadius: BorderRadius.circular(24),
                              shape: BoxShape.rectangle,
                              border: Border.all(
                                color: session.isCompleted
                                    ? AppTheme.accentGreen.withValues(alpha: 0.5)
                                    : const Color(0xFF282832),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 3 Stats Row: Steps (pedometer), Distance (GPS), Progress (%)
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: StatItemWidget(
                                          icon: const Icon(
                                            Icons.directions_walk_rounded,
                                            color: AppTheme.primaryGold,
                                            size: 20,
                                          ),
                                          color: AppTheme.primaryGold,
                                          value: '${session.pedometerSteps}',
                                          label: 'Steps',
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 32,
                                        color: const Color(0xFF282832),
                                      ),
                                      Expanded(
                                        child: StatItemWidget(
                                          icon: const Icon(
                                            Icons.route_rounded,
                                            color: AppTheme.secondaryCyan,
                                            size: 20,
                                          ),
                                          color: AppTheme.secondaryCyan,
                                          value: distWalkedDisplay,
                                          label: 'Distance',
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 32,
                                        color: const Color(0xFF282832),
                                      ),
                                      Expanded(
                                        child: StatItemWidget(
                                          icon: const Icon(
                                            Icons.flag_rounded,
                                            color: AppTheme.accentGreen,
                                            size: 20,
                                          ),
                                          color: AppTheme.accentGreen,
                                          value: '$progressPercent%',
                                          label: 'Progress',
                                        ),
                                      ),
                                    ].divide(const SizedBox(width: 16)),
                                  ),
                                  const SizedBox(height: 24),

                                  // Trek Progress Bar
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Trek Progress',
                                            style: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${gpsDistKm.toStringAsFixed(1)} / ${totalTargetKm.toStringAsFixed(1)} km',
                                            style: const TextStyle(
                                              color: AppTheme.primaryGold,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progressFraction,
                                          minHeight: 8,
                                          backgroundColor: const Color(0xFF282832),
                                          color: session.isCompleted
                                              ? AppTheme.accentGreen
                                              : AppTheme.primaryGold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Guidance message or Arrival CTA
                          if (session.isCompleted)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.fitness_center, size: 20),
                              label: const Text('Start Fitness Challenge'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGold,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                final challenge =
                                    HeritageChallenge.fromSite(_destination);
                                context.push('/live-squat-test', extra: challenge);
                              },
                            )
                          else
                            Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Text(
                                    guidanceText,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  icon: const Icon(Icons.fast_forward,
                                      size: 16, color: Colors.white54),
                                  label: const Text(
                                    'Skip to Arrival (Demo)',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _session = _session!.copyWith(
                                        isCompleted: true,
                                        geofenceState: const GeofenceState(
                                          consecutiveHitsInZone: 5,
                                          hasArrived: true,
                                        ),
                                      );
                                    });
                                    _onArrival();
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
