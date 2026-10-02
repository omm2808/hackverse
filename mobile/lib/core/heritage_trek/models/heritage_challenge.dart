import 'heritage_site.dart';

/// Challenge context passed from a Heritage Trek site to the workout screen.
///
/// Contains the originating site, exercise specification, target reps,
/// and XP bounty upon successful completion.
class HeritageChallenge {
  final String siteId;
  final String siteNameEn;
  final String siteNameOr;
  final String exerciseType; // 'squat' or 'push_up'
  final int targetReps;
  final int rewardXp;

  const HeritageChallenge({
    required this.siteId,
    required this.siteNameEn,
    this.siteNameOr = '',
    this.exerciseType = 'squat',
    this.targetReps = 10,
    required this.rewardXp,
  });

  /// Factory creating an appropriate challenge for a [HeritageSite].
  ///
  /// By default, alternates between Squats (odd unlock orders) and
  /// Push-ups (even unlock orders) with a default goal of 10 reps.
  factory HeritageChallenge.fromSite(
    HeritageSite site, {
    String? exerciseType,
    int? targetReps,
    int? rewardXp,
  }) {
    final exercise = exerciseType ??
        (site.unlockOrder % 2 == 0 ? 'push_up' : 'squat');
    final reps = targetReps ?? 10;
    final xp = rewardXp ?? site.bonusXp;

    return HeritageChallenge(
      siteId: site.id,
      siteNameEn: site.nameEn,
      siteNameOr: site.nameOr,
      exerciseType: exercise,
      targetReps: reps,
      rewardXp: xp,
    );
  }

  /// Calculates current progress as a fraction between 0.0 and 1.0.
  double getProgress(int completedReps) {
    if (targetReps <= 0) return 1.0;
    return (completedReps / targetReps).clamp(0.0, 1.0);
  }

  /// Evaluates whether the target rep goal has been reached.
  bool isGoalReached(int completedReps) {
    return completedReps >= targetReps;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeritageChallenge &&
          runtimeType == other.runtimeType &&
          siteId == other.siteId &&
          exerciseType == other.exerciseType &&
          targetReps == other.targetReps &&
          rewardXp == other.rewardXp;

  @override
  int get hashCode =>
      siteId.hashCode ^
      exerciseType.hashCode ^
      targetReps.hashCode ^
      rewardXp.hashCode;

  @override
  String toString() =>
      'HeritageChallenge(site: $siteId, exercise: $exerciseType, target: $targetReps, xp: $rewardXp)';
}
