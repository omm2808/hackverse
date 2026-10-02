import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fit_odyssey/core/heritage_trek/models/heritage_challenge.dart';
import 'package:fit_odyssey/core/heritage_trek/models/heritage_site.dart';
import 'package:fit_odyssey/core/heritage_trek/models/journey_progress_state.dart';
import 'package:fit_odyssey/core/heritage_trek/providers/heritage_trek_providers.dart';
import 'package:fit_odyssey/core/heritage_trek/repositories/heritage_site_repository.dart';
import 'package:fit_odyssey/core/pose_engine/ui/live_squat_test_screen.dart';
import 'package:fit_odyssey/core/router/app_router.dart';

void main() {
  late HeritageSiteRepository repository;
  late List<HeritageSite> sites;

  setUp(() {
    repository = HeritageSiteRepository();
    sites = repository.getSitesForJourney('odisha_golden_triangle');
  });

  group('HeritageChallenge Model Tests', () {
    test('creates challenge from heritage site with proper defaults', () {
      final lingaraj = repository.getSiteById('lingaraj_temple')!;
      final challenge = HeritageChallenge.fromSite(lingaraj);

      expect(challenge.siteId, equals('lingaraj_temple'));
      expect(challenge.siteNameEn, equals('Lingaraj Temple'));
      expect(challenge.siteNameOr, equals('ଲିଙ୍ଗରାଜ ମନ୍ଦିର'));
      expect(challenge.exerciseType, equals('squat')); // odd unlockOrder 1 -> squat
      expect(challenge.targetReps, equals(10));
      expect(challenge.rewardXp, equals(lingaraj.bonusXp));
    });

    test('alternates exercise type based on unlockOrder', () {
      final site1 = repository.getSiteById('lingaraj_temple')!; // order 1
      final site2 = repository.getSiteById('dhauli_shanti_stupa')!; // order 2

      final challenge1 = HeritageChallenge.fromSite(site1);
      final challenge2 = HeritageChallenge.fromSite(site2);

      expect(challenge1.exerciseType, equals('squat'));
      expect(challenge2.exerciseType, equals('push_up'));
    });

    test('calculates rep progress accurately', () {
      final site = repository.getSiteById('lingaraj_temple')!;
      final challenge = HeritageChallenge.fromSite(site, targetReps: 10);

      expect(challenge.getProgress(0), equals(0.0));
      expect(challenge.getProgress(5), equals(0.5));
      expect(challenge.getProgress(7), equals(0.7));
      expect(challenge.getProgress(10), equals(1.0));
      expect(challenge.getProgress(15), equals(1.0)); // clamped
    });

    test('goal reached conditions', () {
      final site = repository.getSiteById('lingaraj_temple')!;
      final challenge = HeritageChallenge.fromSite(site, targetReps: 10);

      // Prevents completion before target reps
      expect(challenge.isGoalReached(0), isFalse);
      expect(challenge.isGoalReached(9), isFalse);

      // Allows completion at or above target reps
      expect(challenge.isGoalReached(10), isTrue);
      expect(challenge.isGoalReached(12), isTrue);
    });
  });

  group('JourneyProgressState & Sequential Unlocking', () {
    test('initial state has 0 completed sites and first site unlocked', () {
      const state = JourneyProgressState();

      expect(state.completedSiteIds, isEmpty);
      expect(state.totalXp, equals(0));

      // Site 1 (Lingaraj) should be unlocked initially
      expect(state.isSiteUnlocked('lingaraj_temple', sites), isTrue);

      // Site 2 (Dhauli) should be locked initially
      expect(state.isSiteUnlocked('dhauli_shanti_stupa', sites), isFalse);

      // Next available site should be Site 1
      expect(state.getNextAvailableSite(sites)?.id, equals('lingaraj_temple'));
    });

    test('completing Site 1 unlocks Site 2 and leaves Site 3 locked', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(journeyProgressProvider.notifier);

      // Complete Site 1
      notifier.completeSite('lingaraj_temple', 150);

      final state = container.read(journeyProgressProvider);

      expect(state.isSiteCompleted('lingaraj_temple'), isTrue);
      expect(state.totalXp, equals(150));

      // Site 1 is completed
      expect(state.isSiteCompleted('lingaraj_temple'), isTrue);

      // Site 2 (Dhauli) is now unlocked!
      expect(state.isSiteUnlocked('dhauli_shanti_stupa', sites), isTrue);

      // Site 3 (Udayagiri) remains locked
      expect(state.isSiteUnlocked('udayagiri_caves', sites), isFalse);

      // Next available site is now Site 2
      expect(state.getNextAvailableSite(sites)?.id, equals('dhauli_shanti_stupa'));
    });

    test('accumulates XP across multiple site completions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(journeyProgressProvider.notifier);

      notifier.completeSite('lingaraj_temple', 150);
      notifier.completeSite('dhauli_shanti_stupa', 200);

      final state = container.read(journeyProgressProvider);

      expect(state.totalXp, equals(350));
      expect(state.completedSiteIds, containsAll(['lingaraj_temple', 'dhauli_shanti_stupa']));
      expect(state.isSiteUnlocked('udayagiri_caves', sites), isTrue);
    });

    test('completing an already completed site is idempotent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(journeyProgressProvider.notifier);

      notifier.completeSite('lingaraj_temple', 150);
      notifier.completeSite('lingaraj_temple', 150); // repeat

      final state = container.read(journeyProgressProvider);

      expect(state.totalXp, equals(150)); // no double XP
      expect(state.completedSiteIds.length, equals(1));
    });

    test('reset clears all completions and resets XP', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(journeyProgressProvider.notifier);

      notifier.completeSite('lingaraj_temple', 150);
      expect(container.read(journeyProgressProvider).totalXp, equals(150));

      notifier.reset();
      final resetState = container.read(journeyProgressProvider);

      expect(resetState.completedSiteIds, isEmpty);
      expect(resetState.totalXp, equals(0));
      expect(resetState.isSiteUnlocked('lingaraj_temple', sites), isTrue);
      expect(resetState.isSiteUnlocked('dhauli_shanti_stupa', sites), isFalse);
    });
  });

  group('Site → Workout Challenge Passing Integration', () {
    test('app router properly configures /live-squat-test route', () {
      final route = appRouter.configuration.routes
          .whereType<GoRoute>()
          .firstWhere((r) => r.path == '/live-squat-test');

      expect(route, isNotNull);
      expect(route.path, equals('/live-squat-test'));
      expect(route.builder, isNotNull);

      // Verify LiveSquatTestScreen accepts and preserves challenge context
      final lingaraj = repository.getSiteById('lingaraj_temple')!;
      final challenge = HeritageChallenge.fromSite(lingaraj);
      final screen = LiveSquatTestScreen(challenge: challenge);

      expect(screen.challenge?.siteId, equals('lingaraj_temple'));
      expect(screen.challenge?.exerciseType, equals('squat'));
      expect(screen.challenge?.rewardXp, equals(75));
      expect(screen.challenge?.targetReps, equals(10));
    });
  });
}
