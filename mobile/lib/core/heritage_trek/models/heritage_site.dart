/// Heritage Site data model.
///
/// Represents a physical heritage site that can serve as a trek destination.
/// Data-driven: all sites come from the repository, not hardcoded in UI.
///
/// This is the Dart equivalent of the TypeScript [HeritageCheckpoint] in
/// `packages/shared-types/src/heritage.ts`, extended with real GPS
/// coordinates for on-device geofencing.
class HeritageSite {
  /// Unique identifier (matches backend checkpoint ID).
  final String id;

  /// Journey this site belongs to.
  final String journeyId;

  /// English display name.
  final String nameEn;

  /// Odia (ଓଡ଼ିଆ) display name.
  final String nameOr;

  /// English description.
  final String descEn;

  /// Odia description.
  final String descOr;

  /// GPS latitude (WGS-84).
  final double latitude;

  /// GPS longitude (WGS-84).
  final double longitude;

  /// Virtual distance from journey start in kilometers.
  /// Used for the "Odyssey Map" virtual trek progress, NOT for GPS distance.
  final double distanceFromStartKm;

  /// Sequential unlock order within the journey.
  final int unlockOrder;

  /// XP bonus awarded on arrival.
  final int bonusXp;

  /// Optional local asset path or remote URL for the site image.
  final String? imageAsset;

  const HeritageSite({
    required this.id,
    required this.journeyId,
    required this.nameEn,
    required this.nameOr,
    required this.descEn,
    required this.descOr,
    required this.latitude,
    required this.longitude,
    required this.distanceFromStartKm,
    required this.unlockOrder,
    this.bonusXp = 75,
    this.imageAsset,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeritageSite &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'HeritageSite($id: $nameEn)';
}
