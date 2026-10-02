import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/heritage_site.dart';
import '../models/journey_progress_state.dart';
import '../repositories/heritage_site_repository.dart';
import '../services/geofence_checker.dart';
import '../services/location_service.dart';
import '../services/step_tracker_service.dart';
import '../services/trek_distance_calculator.dart';
import '../services/walking_route_service.dart';

// ---------------------------------------------------------------------------
// Service Providers (singletons within the provider scope)
// ---------------------------------------------------------------------------

/// Provides the [LocationService] — foreground-only GPS stream wrapper.
final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provides the [StepTrackerService] — pedometer step counter wrapper.
final stepTrackerServiceProvider = Provider<StepTrackerService>((ref) {
  final service = StepTrackerService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provides the [HeritageSiteRepository] — data-driven site catalog.
/// In a future phase, this provider can be overridden to fetch from
/// MongoDB/API instead of the in-memory offline dataset.
final heritageSiteRepositoryProvider = Provider<HeritageSiteRepository>((ref) {
  return HeritageSiteRepository();
});

/// Provides the [GeofenceChecker] — stateless arrival distance calculator.
final geofenceCheckerProvider = Provider<GeofenceChecker>((ref) {
  return GeofenceChecker();
});

/// Provides the [TrekDistanceCalculator] — Haversine distance accumulator.
/// A new calculator is created per trek session via this provider.
final trekDistanceCalculatorProvider = Provider<TrekDistanceCalculator>((ref) {
  return TrekDistanceCalculator();
});

/// Provides the [WalkingRouteService] for pedestrian road routing.
final walkingRouteServiceProvider = Provider<WalkingRouteService>((ref) {
  final service = WalkingRouteService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ---------------------------------------------------------------------------
// Data Providers
// ---------------------------------------------------------------------------

/// All heritage sites for the Odisha Golden Triangle journey.
final odishaSitesProvider = Provider<List<HeritageSite>>((ref) {
  final repo = ref.read(heritageSiteRepositoryProvider);
  return repo.getSitesForJourney('odisha_golden_triangle');
});

/// StateNotifier managing runtime progression across heritage sites.
class JourneyProgressNotifier extends StateNotifier<JourneyProgressState> {
  JourneyProgressNotifier() : super(const JourneyProgressState());

  /// Marks a site as completed and credits its XP reward.
  void completeSite(String siteId, int rewardXp) {
    if (state.completedSiteIds.contains(siteId)) return;
    state = state.copyWith(
      completedSiteIds: {...state.completedSiteIds, siteId},
      totalXp: state.totalXp + rewardXp,
    );
  }

  /// Resets journey progress to fresh state (useful for testing or replay).
  void resetProgress() {
    state = const JourneyProgressState();
  }

  /// Alias for [resetProgress].
  void reset() => resetProgress();
}

/// Provides the active [JourneyProgressState].
final journeyProgressProvider =
    StateNotifierProvider<JourneyProgressNotifier, JourneyProgressState>((ref) {
  return JourneyProgressNotifier();
});
