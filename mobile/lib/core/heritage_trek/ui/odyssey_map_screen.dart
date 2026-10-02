import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';
import '../models/heritage_site.dart';
import '../models/journey_progress_state.dart';
import '../providers/heritage_trek_providers.dart';

/// Odyssey Map Screen — heritage site selection via an interactive map.
///
/// Shows all heritage sites in the Odisha Golden Triangle journey on a
/// flutter_map OSM tile layer. Tapping a marker opens the site details.
/// Uses the data-driven [HeritageSiteRepository] and [journeyProgressProvider]
/// to display sequential unlocking, completion badges, and accumulated XP.
class OdysseyMapScreen extends ConsumerStatefulWidget {
  const OdysseyMapScreen({super.key});

  @override
  ConsumerState<OdysseyMapScreen> createState() => _OdysseyMapScreenState();
}

class _OdysseyMapScreenState extends ConsumerState<OdysseyMapScreen> {
  final MapController _mapController = MapController();
  HeritageSite? _selectedSite;

  // Odisha Golden Triangle center
  static const LatLng _defaultCenter = LatLng(20.17, 85.85);
  static const double _defaultZoom = 10.0;

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(odishaSitesProvider);
    final progress = ref.watch(journeyProgressProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Heritage Trek'),
        actions: [
          // XP Balance badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryGold.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: AppTheme.primaryGold, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${progress.totalXp} XP',
                  style: const TextStyle(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: AppTheme.primaryGold),
            tooltip: 'Center Map',
            onPressed: () {
              _mapController.move(_defaultCenter, _defaultZoom);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Map area
          Expanded(
            flex: 6,
            child: _buildMap(sites, progress),
          ),
          // Site list / selection panel
          Expanded(
            flex: 4,
            child: _buildSiteList(sites, progress),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(List<HeritageSite> sites, JourneyProgressState progress) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: _defaultZoom,
        minZoom: 6,
        maxZoom: 18,
        onTap: (_, __) {
          setState(() => _selectedSite = null);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.fitodyssey.app',
        ),
        // Connection polyline between sites
        if (sites.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: sites
                    .map((s) => LatLng(s.latitude, s.longitude))
                    .toList(),
                color: AppTheme.primaryGold.withValues(alpha: 0.6),
                strokeWidth: 3.0,
                borderStrokeWidth: 1.0,
                borderColor: AppTheme.primaryGoldDark.withValues(alpha: 0.3),
              ),
            ],
          ),
        // Site markers
        MarkerLayer(
          markers: sites.map((site) {
            final isSelected = _selectedSite?.id == site.id;
            final isCompleted = progress.isSiteCompleted(site.id);
            final isUnlocked = progress.isSiteUnlocked(site.id, sites);

            Color bgColor;
            Color borderColor;
            Widget childWidget;

            if (isCompleted) {
              bgColor = AppTheme.accentGreen;
              borderColor = Colors.white;
              childWidget = Icon(
                Icons.check,
                color: Colors.white,
                size: isSelected ? 24 : 18,
              );
            } else if (isUnlocked) {
              bgColor = isSelected
                  ? AppTheme.primaryGold
                  : AppTheme.surfaceElevated;
              borderColor = isSelected
                  ? AppTheme.primaryGoldDark
                  : AppTheme.primaryGold;
              childWidget = Text(
                '${site.unlockOrder}',
                style: TextStyle(
                  color: isSelected ? Colors.black : AppTheme.primaryGold,
                  fontWeight: FontWeight.w900,
                  fontSize: isSelected ? 18 : 14,
                ),
              );
            } else {
              bgColor = const Color(0xFF222225);
              borderColor = Colors.white24;
              childWidget = const Icon(
                Icons.lock_outline,
                color: Colors.white38,
                size: 16,
              );
            }

            return Marker(
              point: LatLng(site.latitude, site.longitude),
              width: isSelected ? 56 : 44,
              height: isSelected ? 56 : 44,
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedSite = site);
                  _mapController.move(
                    LatLng(site.latitude, site.longitude),
                    14.0,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bgColor,
                    border: Border.all(
                      color: borderColor,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: (isCompleted
                                      ? AppTheme.accentGreen
                                      : AppTheme.primaryGold)
                                  .withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(child: childWidget),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSiteList(
      List<HeritageSite> sites, JourneyProgressState progress) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'HERITAGE CHECKPOINTS',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: sites.length,
              itemBuilder: (context, index) {
                final site = sites[index];
                final isSelected = _selectedSite?.id == site.id;
                final isCompleted = progress.isSiteCompleted(site.id);
                final isUnlocked = progress.isSiteUnlocked(site.id, sites);
                return _buildSiteCard(
                    site, isSelected, isCompleted, isUnlocked);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(
    HeritageSite site,
    bool isSelected,
    bool isCompleted,
    bool isUnlocked,
  ) {
    Widget leadingBadge;
    if (isCompleted) {
      leadingBadge = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.accentGreen.withValues(alpha: 0.2),
          border: Border.all(
            color: AppTheme.accentGreen,
            width: 1.5,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.check,
            color: AppTheme.accentGreen,
            size: 20,
          ),
        ),
      );
    } else if (isUnlocked) {
      leadingBadge = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryGold.withValues(alpha: 0.2),
          border: Border.all(
            color: AppTheme.primaryGold,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            '${site.unlockOrder}',
            style: const TextStyle(
              color: AppTheme.primaryGold,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      );
    } else {
      leadingBadge = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: Colors.white24,
            width: 1.5,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.lock_outline,
            color: Colors.white38,
            size: 16,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() => _selectedSite = site);
        _mapController.move(
          LatLng(site.latitude, site.longitude),
          14.0,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isCompleted
                  ? AppTheme.accentGreen.withValues(alpha: 0.12)
                  : AppTheme.primaryGold.withValues(alpha: 0.12))
              : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isCompleted ? AppTheme.accentGreen : AppTheme.primaryGold)
                : (isCompleted
                    ? AppTheme.accentGreen.withValues(alpha: 0.3)
                    : Colors.white10),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            leadingBadge,
            const SizedBox(width: 12),
            // Site info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          site.nameEn,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isUnlocked || isCompleted
                                ? Colors.white
                                : Colors.white54,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'COMPLETED',
                            style: TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (!isUnlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LOCKED',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    site.nameOr,
                    style: TextStyle(
                      color: isUnlocked || isCompleted
                          ? AppTheme.primaryGold.withValues(alpha: 0.8)
                          : Colors.white24,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${site.distanceFromStartKm.toStringAsFixed(1)} km  ·  ${site.bonusXp} XP',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Navigate arrow
            if (isUnlocked || isCompleted)
              IconButton(
                icon: Icon(
                  isCompleted ? Icons.check_circle : Icons.arrow_forward_ios,
                  color: isCompleted
                      ? AppTheme.accentGreen
                      : AppTheme.primaryGold,
                  size: isCompleted ? 22 : 18,
                ),
                onPressed: () {
                  context.push('/challenge/${site.id}');
                },
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.lock_outline,
                  color: Colors.white24,
                  size: 18,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.surfaceDark,
                      content: Text(
                        'Complete the previous heritage site to unlock ${site.nameEn}!',
                        style: const TextStyle(color: Colors.white),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
