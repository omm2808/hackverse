// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fit Odyssey';

  @override
  String get navHome => 'Home';

  @override
  String get navWorkout => 'Workout';

  @override
  String get navJourney => 'Journey';

  @override
  String get navLeaderboard => 'Leaderboard';

  @override
  String get navProfile => 'Profile';

  @override
  String get exerciseSquat => 'Squats';

  @override
  String get exercisePushup => 'Push-ups';

  @override
  String get exercisePlank => 'Plank';

  @override
  String get calibrationTitle => 'Camera Calibration';

  @override
  String get calibrationStepBody =>
      'Step back until your entire body is visible in the frame.';

  @override
  String get calibrationGood => 'Position calibrated. Get ready!';

  @override
  String get calibrationLowConfidence =>
      'Low confidence. Adjust lighting or camera angle.';

  @override
  String get cueGoodDepth => 'Good depth!';

  @override
  String get cueGoLower => 'Go slightly lower';

  @override
  String get cueChestUp => 'Keep chest upright';

  @override
  String get cueKneesOut => 'Push knees outward';

  @override
  String get cueRaiseHips => 'Raise your hips';

  @override
  String get cueLowerHips => 'Lower your hips';

  @override
  String get workoutComplete => 'Workout Complete!';

  @override
  String get repsCompleted => 'Reps Completed';

  @override
  String get holdDuration => 'Hold Duration';

  @override
  String get formAccuracy => 'Form Accuracy';

  @override
  String get xpEarned => 'XP Earned';

  @override
  String get kmGained => 'Heritage KM Gained';

  @override
  String get syncPending => 'Saved offline, will sync when connected';

  @override
  String get syncSuccess => 'Synced with server';

  @override
  String get heritageTitle => 'Odisha Golden Triangle Trek';

  @override
  String get heritageSubtitle => 'Lingaraj Temple to Konark Sun Temple (65 km)';

  @override
  String get checkpointUnlocked => 'Checkpoint Unlocked!';

  @override
  String get leaderboardTitle => 'Campus Leaderboard';

  @override
  String get scopeGlobal => 'Global';

  @override
  String get scopeCollege => 'College';

  @override
  String get scopeHostel => 'Hostel';

  @override
  String get periodWeekly => 'Weekly';

  @override
  String get periodMonthly => 'Monthly';

  @override
  String get privacyConsentTitle => 'Privacy by Design';

  @override
  String get privacyConsentBody =>
      'Fit Odyssey processes your camera feed entirely on your phone. No videos, photos, or raw landmark coordinates are ever saved or uploaded to the cloud.';

  @override
  String get privacyAgree => 'I Agree & Continue';

  @override
  String get under18Affirmation =>
      'I affirm that I am 18 years of age or older.';
}
