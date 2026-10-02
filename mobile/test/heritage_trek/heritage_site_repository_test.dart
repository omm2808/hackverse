import 'package:flutter_test/flutter_test.dart';
import 'package:fit_odyssey/core/heritage_trek/repositories/heritage_site_repository.dart';

void main() {
  late HeritageSiteRepository repo;

  setUp(() {
    repo = HeritageSiteRepository();
  });

  group('HeritageSiteRepository', () {
    test('getSitesForJourney returns 5 Odisha sites', () {
      final sites = repo.getSitesForJourney('odisha_golden_triangle');
      expect(sites.length, 5);
    });

    test('sites are sorted by unlockOrder', () {
      final sites = repo.getSitesForJourney('odisha_golden_triangle');
      for (var i = 1; i < sites.length; i++) {
        expect(sites[i].unlockOrder,
            greaterThan(sites[i - 1].unlockOrder));
      }
    });

    test('all sites have valid GPS coordinates', () {
      final sites = repo.getSitesForJourney('odisha_golden_triangle');
      for (final site in sites) {
        expect(site.latitude, inInclusiveRange(-90.0, 90.0));
        expect(site.longitude, inInclusiveRange(-180.0, 180.0));
        // Odisha is roughly 17–22°N, 81–87°E
        expect(site.latitude, inInclusiveRange(19.0, 21.0));
        expect(site.longitude, inInclusiveRange(85.0, 87.0));
      }
    });

    test('getSiteById returns correct site', () {
      final site = repo.getSiteById('konark_sun_temple');
      expect(site, isNotNull);
      expect(site!.nameEn, 'Konark Sun Temple');
      expect(site.unlockOrder, 5);
    });

    test('getSiteById returns null for unknown ID', () {
      final site = repo.getSiteById('nonexistent_site');
      expect(site, isNull);
    });

    test('getNextDestination returns first site when none completed', () {
      final site =
          repo.getNextDestination('odisha_golden_triangle', 0);
      expect(site, isNotNull);
      expect(site!.id, 'lingaraj_temple');
      expect(site.unlockOrder, 1);
    });

    test('getNextDestination returns second site when 1 completed', () {
      final site =
          repo.getNextDestination('odisha_golden_triangle', 1);
      expect(site, isNotNull);
      expect(site!.id, 'dhauli_shanti_stupa');
    });

    test('getNextDestination returns null when all completed', () {
      final site =
          repo.getNextDestination('odisha_golden_triangle', 5);
      expect(site, isNull);
    });

    test('getNextDestination returns null for unknown journey', () {
      final site = repo.getNextDestination('unknown_journey', 0);
      expect(site, isNull);
    });

    test('getAvailableJourneyIds returns at least one journey', () {
      final ids = repo.getAvailableJourneyIds();
      expect(ids, contains('odisha_golden_triangle'));
    });

    test('all sites have bilingual names', () {
      final sites = repo.getSitesForJourney('odisha_golden_triangle');
      for (final site in sites) {
        expect(site.nameEn, isNotEmpty);
        expect(site.nameOr, isNotEmpty);
        expect(site.descEn, isNotEmpty);
        expect(site.descOr, isNotEmpty);
      }
    });

    test('all sites have positive or zero bonusXp', () {
      final sites = repo.getSitesForJourney('odisha_golden_triangle');
      for (final site in sites) {
        expect(site.bonusXp, greaterThanOrEqualTo(0));
      }
    });

    test('first site is at 0 km', () {
      final sites = repo.getSitesForJourney('odisha_golden_triangle');
      expect(sites.first.distanceFromStartKm, 0.0);
    });

    test('distances are monotonically increasing', () {
      final sites = repo.getSitesForJourney('odisha_golden_triangle');
      for (var i = 1; i < sites.length; i++) {
        expect(sites[i].distanceFromStartKm,
            greaterThan(sites[i - 1].distanceFromStartKm));
      }
    });
  });
}
