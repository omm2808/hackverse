import '../models/heritage_site.dart';

/// Data-driven repository for heritage sites.
///
/// Phase 1: provides an in-memory offline dataset of Odisha Golden Triangle
/// sites with real GPS coordinates. This is the INITIAL dataset only —
/// the architecture is designed so this can be replaced by a MongoDB/API
/// source in a future phase without changing consumers.
///
/// Consumers access sites through this repository interface, never hardcoded
/// site data directly.
class HeritageSiteRepository {
  /// The initial offline dataset.
  /// In a future phase, this will be populated from a remote API/MongoDB.
  static const String _odishaJourneyId = 'odisha_golden_triangle';

  final List<HeritageSite> _sites = const [
    HeritageSite(
      id: 'lingaraj_temple',
      journeyId: _odishaJourneyId,
      nameEn: 'Lingaraj Temple',
      nameOr: 'ଲିଙ୍ଗରାଜ ମନ୍ଦିର',
      descEn:
          'Ancient 11th-century temple representing the pinnacle of Kalinga architecture.',
      descOr:
          'ଏକାଦଶ ଶତାବ୍ଦୀର ପ୍ରାଚୀନ ମନ୍ଦିର, କଳିଙ୍ଗ ସ୍ଥାପତ୍ୟ କଳାର ଅନନ୍ୟ ନିଦର୍ଶନ।',
      latitude: 20.2388,
      longitude: 85.8340,
      distanceFromStartKm: 0.0,
      unlockOrder: 1,
      bonusXp: 75,
    ),
    HeritageSite(
      id: 'dhauli_shanti_stupa',
      journeyId: _odishaJourneyId,
      nameEn: 'Dhauli Shanti Stupa',
      nameOr: 'ଧଉଳି ଶାନ୍ତି ସ୍ତୂପ',
      descEn:
          'Historic peace pagoda marking Emperor Ashoka\'s transformation '
          'following the Kalinga War.',
      descOr:
          'କଳିଙ୍ଗ ଯୁଦ୍ଧ ପରେ ସମ୍ରାଟ ଅଶୋକଙ୍କ ହୃଦୟ ପରିବର୍ତ୍ତନର ପ୍ରତୀକ ଶାନ୍ତି ସ୍ତୂପ।',
      latitude: 20.1927,
      longitude: 85.8497,
      distanceFromStartKm: 8.0,
      unlockOrder: 2,
      bonusXp: 75,
    ),
    HeritageSite(
      id: 'udayagiri_caves',
      journeyId: _odishaJourneyId,
      nameEn: 'Udayagiri Caves',
      nameOr: 'ଉଦୟଗିରି ଗୁମ୍ଫା',
      descEn:
          'Ancient rock-cut sanctuaries and inscriptions of King Kharavela '
          'dating to 2nd century BCE.',
      descOr:
          'ଖାରବେଳଙ୍କ ସମୟର ପ୍ରାଚୀନ ଶିଳାଲେଖ ଓ ଐତିହାସିକ ଜୈନ ଗୁମ୍ଫା।',
      latitude: 20.2609,
      longitude: 85.7862,
      distanceFromStartKm: 14.0,
      unlockOrder: 3,
      bonusXp: 75,
    ),
    HeritageSite(
      id: 'pipili_village',
      journeyId: _odishaJourneyId,
      nameEn: 'Pipili Craft Village',
      nameOr: 'ପିପିଲି ଚାନ୍ଦୁଆ ଗ୍ରାମ',
      descEn:
          'World-renowned center of vibrant applique handicrafts and '
          'traditional Jagannath canopies.',
      descOr: 'ଚାନ୍ଦୁଆ ଶିଳ୍ପ ଓ ପାରମ୍ପରିକ ହସ୍ତକଳାର ବିଶ୍ୱପ୍ରସିଦ୍ଧ କେନ୍ଦ୍ର।',
      latitude: 20.1177,
      longitude: 85.8326,
      distanceFromStartKm: 28.0,
      unlockOrder: 4,
      bonusXp: 75,
    ),
    HeritageSite(
      id: 'konark_sun_temple',
      journeyId: _odishaJourneyId,
      nameEn: 'Konark Sun Temple',
      nameOr: 'କୋଣାର୍କ ସୂର୍ଯ୍ୟ ମନ୍ଦିର',
      descEn:
          'UNESCO World Heritage 13th-century chariot temple dedicated to '
          'Surya the Sun God.',
      descOr: 'ତ୍ରୟୋଦଶ ଶତାବ୍ଦୀର ବିଶ୍ୱ ଐତିହ୍ୟ ସୂର୍ଯ୍ୟ ରଥ ମନ୍ଦିର।',
      latitude: 19.8876,
      longitude: 86.0945,
      distanceFromStartKm: 65.0,
      unlockOrder: 5,
      bonusXp: 75,
    ),
  ];

  /// Returns all heritage sites for a given journey, sorted by unlock order.
  List<HeritageSite> getSitesForJourney(String journeyId) {
    return _sites
        .where((site) => site.journeyId == journeyId)
        .toList()
      ..sort((a, b) => a.unlockOrder.compareTo(b.unlockOrder));
  }

  /// Returns a specific site by its ID, or null if not found.
  HeritageSite? getSiteById(String siteId) {
    try {
      return _sites.firstWhere((site) => site.id == siteId);
    } on StateError {
      return null;
    }
  }

  /// Returns the next destination for a trek given how many checkpoints
  /// the user has already completed.
  ///
  /// Returns null if all sites in the journey are completed.
  HeritageSite? getNextDestination(String journeyId, int completedCount) {
    final sites = getSitesForJourney(journeyId);
    if (completedCount >= sites.length) return null;
    return sites[completedCount];
  }

  /// Returns all available journey IDs.
  List<String> getAvailableJourneyIds() {
    return _sites.map((s) => s.journeyId).toSet().toList();
  }
}
