import 'heritage_site.dart';

/// Runtime state tracking completed heritage sites, unlocked checkpoints,
/// and accumulated XP across the Odyssey journey.
class JourneyProgressState {
  /// Set of completed heritage site IDs.
  final Set<String> completedSiteIds;

  /// Total XP accumulated from completed challenges & treks.
  final int totalXp;

  const JourneyProgressState({
    this.completedSiteIds = const {},
    this.totalXp = 0,
  });

  /// Check whether a specific site is completed.
  bool isSiteCompleted(String siteId) => completedSiteIds.contains(siteId);

  /// Check whether a specific site is unlocked.
  ///
  /// Sequential unlock rule:
  /// - Site with unlockOrder == 1 is always unlocked.
  /// - Subsequent sites are unlocked if the preceding site (unlockOrder - 1)
  ///   has been completed.
  bool isSiteUnlocked(dynamic siteOrId, List<HeritageSite> allSites) {
    final HeritageSite site;
    if (siteOrId is HeritageSite) {
      site = siteOrId;
    } else if (siteOrId is String) {
      final found = allSites.where((s) => s.id == siteOrId).firstOrNull;
      if (found == null) return false;
      site = found;
    } else {
      return false;
    }

    if (site.unlockOrder <= 1) return true;

    // Find preceding site in sequence
    final sorted = List<HeritageSite>.from(allSites)
      ..sort((a, b) => a.unlockOrder.compareTo(b.unlockOrder));

    final currentIndex = sorted.indexWhere((s) => s.id == site.id);
    if (currentIndex <= 0) return true;

    final prevSite = sorted[currentIndex - 1];
    return completedSiteIds.contains(prevSite.id);
  }

  /// Returns the next available (unlocked but not yet completed) site.
  HeritageSite? getNextAvailableSite(List<HeritageSite> allSites) {
    final sorted = List<HeritageSite>.from(allSites)
      ..sort((a, b) => a.unlockOrder.compareTo(b.unlockOrder));

    for (final site in sorted) {
      if (!isSiteCompleted(site.id) && isSiteUnlocked(site, allSites)) {
        return site;
      }
    }
    return null;
  }

  JourneyProgressState copyWith({
    Set<String>? completedSiteIds,
    int? totalXp,
  }) {
    return JourneyProgressState(
      completedSiteIds: completedSiteIds ?? this.completedSiteIds,
      totalXp: totalXp ?? this.totalXp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JourneyProgressState &&
          runtimeType == other.runtimeType &&
          totalXp == other.totalXp &&
          completedSiteIds.length == other.completedSiteIds.length &&
          completedSiteIds.containsAll(other.completedSiteIds);

  @override
  int get hashCode => completedSiteIds.hashCode ^ totalXp.hashCode;

  @override
  String toString() =>
      'JourneyProgressState(completed: ${completedSiteIds.length}, totalXp: $totalXp)';
}
