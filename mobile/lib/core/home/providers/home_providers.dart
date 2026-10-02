import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../heritage_trek/providers/heritage_trek_providers.dart';

// ---------------------------------------------------------------------------
// Dashboard State Models
// ---------------------------------------------------------------------------

/// User profile summary for the dashboard header.
class DashboardProfile {
  final String displayName;
  final String avatarUrl;
  final int level;
  final int currentXp;
  final int xpToNextLevel;
  final int streakDays;

  const DashboardProfile({
    this.displayName = 'Odyssey Athlete',
    this.avatarUrl = '',
    this.level = 1,
    this.currentXp = 0,
    this.xpToNextLevel = 500,
    this.streakDays = 0,
  });

  double get levelProgress =>
      xpToNextLevel > 0 ? (currentXp / xpToNextLevel).clamp(0.0, 1.0) : 0.0;
}

/// Represents a daily mission item on the dashboard.
class DailyMission {
  final String id;
  final String title;
  final String subtitle;
  final String iconName;
  final int currentValue;
  final int targetValue;
  final int rewardXp;
  final bool isCompleted;

  const DailyMission({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.iconName = 'fitness_center',
    this.currentValue = 0,
    required this.targetValue,
    this.rewardXp = 50,
    this.isCompleted = false,
  });

  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;
}

/// Represents a suggested workout on the dashboard.
class SuggestedWorkout {
  final String id;
  final String title;
  final String subtitle;
  final String exerciseType;
  final int durationMinutes;
  final int estimatedXp;
  final String difficulty;

  const SuggestedWorkout({
    required this.id,
    required this.title,
    required this.subtitle,
    this.exerciseType = 'squat',
    this.durationMinutes = 15,
    this.estimatedXp = 100,
    this.difficulty = 'Moderate',
  });
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Dashboard profile derived from journey progress XP.
final dashboardProfileProvider = Provider<DashboardProfile>((ref) {
  final progress = ref.watch(journeyProgressProvider);
  final totalXp = progress.totalXp;

  // Level formula: each level requires (level * 500) XP
  int level = 1;
  int xpAccum = totalXp;
  while (xpAccum >= level * 500) {
    xpAccum -= level * 500;
    level++;
  }

  return DashboardProfile(
    displayName: 'Odyssey Athlete',
    level: level,
    currentXp: xpAccum,
    xpToNextLevel: level * 500,
    streakDays: 0, // Will be populated from backend in future phase
  );
});

/// Suggested workouts for today's session.
final suggestedWorkoutsProvider = Provider<List<SuggestedWorkout>>((ref) {
  return const [
    SuggestedWorkout(
      id: 'quick_squat',
      title: 'Power Squats',
      subtitle: 'Build leg strength with AI form tracking',
      exerciseType: 'squat',
      durationMinutes: 10,
      estimatedXp: 80,
      difficulty: 'Beginner',
    ),
    SuggestedWorkout(
      id: 'push_up_blast',
      title: 'Push-Up Blast',
      subtitle: 'Core & upper body conditioning',
      exerciseType: 'push_up',
      durationMinutes: 12,
      estimatedXp: 100,
      difficulty: 'Moderate',
    ),
    SuggestedWorkout(
      id: 'heritage_circuit',
      title: 'Heritage Circuit',
      subtitle: 'Mixed exercises along the Odyssey trail',
      exerciseType: 'squat',
      durationMinutes: 20,
      estimatedXp: 200,
      difficulty: 'Challenging',
    ),
  ];
});

/// Daily missions — will integrate with backend in future phase.
final dailyMissionsProvider = Provider<List<DailyMission>>((ref) {
  final progress = ref.watch(journeyProgressProvider);

  return [
    const DailyMission(
      id: 'daily_squats',
      title: 'Complete 20 Squats',
      subtitle: 'AI-verified form required',
      iconName: 'fitness_center',
      currentValue: 0,
      targetValue: 20,
      rewardXp: 60,
    ),
    DailyMission(
      id: 'trek_walk',
      title: 'Heritage Trek Walk',
      subtitle: 'Walk to your next heritage site',
      iconName: 'directions_walk',
      currentValue: progress.completedSiteIds.length,
      targetValue: 1,
      rewardXp: 100,
      isCompleted: progress.completedSiteIds.isNotEmpty,
    ),
    DailyMission(
      id: 'earn_xp',
      title: 'Earn 150 XP',
      subtitle: 'From workouts and treks',
      iconName: 'star',
      currentValue: progress.totalXp.clamp(0, 150),
      targetValue: 150,
      rewardXp: 50,
      isCompleted: progress.totalXp >= 150,
    ),
  ];
});

/// Active Odyssey Quest derived from journey progress.
final activeQuestProvider = Provider<Map<String, dynamic>>((ref) {
  final progress = ref.watch(journeyProgressProvider);
  final sites = ref.watch(odishaSitesProvider);
  final nextSite = progress.getNextAvailableSite(sites);

  return {
    'journeyName': 'Odisha Golden Triangle',
    'completedSites': progress.completedSiteIds.length,
    'totalSites': sites.length,
    'totalXp': progress.totalXp,
    'nextSiteName': nextSite?.nameEn ?? 'Journey Complete!',
    'nextSiteId': nextSite?.id,
    'isComplete': nextSite == null && progress.completedSiteIds.isNotEmpty,
  };
});
