// Fit Odyssey — Application Constants

class AppConstants {
  static const String appName = 'Fit Odyssey';
  static const String appVersion = '1.0.0';

  // Gamification Constants
  static const int baseWorkoutXp = 50;
  static const int xpPerRep = 2;
  static const int plankSecondsPerRep = 5;
  static const int streakBonus7Xp = 150;
  static const int streakBonus30Xp = 500;
  static const int checkpointUnlockXp = 75;

  // Heritage Distance Formula Rates
  static const double kmPerRep = 0.05;
  static const double kmPerActiveMinute = 0.10;
  static const double kmPerCompletedWorkout = 0.50;

  // Anti-Cheat Sanity Bounds
  static const int maxRepsPerMinute = 60;
  static const int minWorkoutDurationSec = 5;
  static const int maxDailyWorkouts = 20;

  // Heritage Route Keys
  static const String defaultJourneyId = 'odisha_golden_triangle';
  static const double totalJourneyKm = 65.0;

  // DPDP Consent Version
  static const String currentConsentVersion = '1.0';
}
