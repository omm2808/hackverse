import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../models/heritage_challenge.dart';
import '../models/heritage_site.dart';
import '../providers/heritage_trek_providers.dart';

/// Challenge Details Screen — shows heritage site info before starting trek.
///
/// Displays the site name (bilingual), description, GPS coordinates,
/// distance info, XP reward, and a "Begin Trek" CTA. This is the
/// intermediate screen between OdysseyMap and the active HeritageTrek.
class ChallengeDetailsScreen extends ConsumerWidget {
  final String siteId;

  const ChallengeDetailsScreen({
    super.key,
    required this.siteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(heritageSiteRepositoryProvider);
    final site = repo.getSiteById(siteId);

    if (site == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(title: const Text('Challenge Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.alertRed, size: 48),
              const SizedBox(height: 16),
              Text(
                'Heritage site "$siteId" not found.',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          // Collapsing header with site name
          _buildSliverAppBar(context, site),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Odia name subtitle
                  Text(
                    site.nameOr,
                    style: TextStyle(
                      color: AppTheme.primaryGold.withValues(alpha: 0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description card
                  _buildDescriptionCard(site),
                  const SizedBox(height: 16),

                  // Metrics row
                  _buildMetricsRow(site),
                  const SizedBox(height: 16),

                  // GPS Info card
                  _buildGpsInfoCard(site),
                  const SizedBox(height: 16),

                  // XP Reward card
                  _buildRewardCard(site),
                  const SizedBox(height: 24),

                  // Begin Trek CTA
                  _buildBeginTrekButton(context, site),
                  const SizedBox(height: 12),

                  // Skip to exercise (for testing / demo)
                  _buildSkipToExerciseButton(context, site),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, HeritageSite site) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppTheme.surfaceDark,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          site.nameEn,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            shadows: [Shadow(blurRadius: 8, color: Colors.black)],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryGold.withValues(alpha: 0.3),
                AppTheme.backgroundDark,
              ],
            ),
          ),
          child: Center(
            child: Icon(
              _getSiteIcon(site.id),
              size: 80,
              color: AppTheme.primaryGold.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(HeritageSite site) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ABOUT THIS SITE',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            site.descEn,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            site.descOr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(HeritageSite site) {
    return Row(
      children: [
        _metricChip(
          icon: Icons.route,
          label: 'DISTANCE',
          value: '${site.distanceFromStartKm.toStringAsFixed(1)} km',
        ),
        const SizedBox(width: 10),
        _metricChip(
          icon: Icons.emoji_events,
          label: 'REWARD',
          value: '${site.bonusXp} XP',
        ),
        const SizedBox(width: 10),
        _metricChip(
          icon: Icons.format_list_numbered,
          label: 'ORDER',
          value: '#${site.unlockOrder}',
        ),
      ],
    );
  }

  Widget _metricChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsInfoCard(HeritageSite site) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppTheme.secondaryCyan, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GPS COORDINATES',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${site.latitude.toStringAsFixed(4)}°N, ${site.longitude.toStringAsFixed(4)}°E',
                style: const TextStyle(
                  color: AppTheme.secondaryCyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(HeritageSite site) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGold.withValues(alpha: 0.15),
            AppTheme.primaryGoldDark.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryGold.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryGold.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: AppTheme.primaryGold,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ARRIVAL REWARD',
                  style: TextStyle(
                    color: AppTheme.primaryGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Walk to this heritage site to earn XP and unlock a fitness challenge at the destination!',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeginTrekButton(BuildContext context, HeritageSite site) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.directions_walk, size: 22),
        label: Text(
          'Begin Trek to ${site.nameEn}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () {
          context.push('/heritage-trek/${site.id}');
        },
      ),
    );
  }

  Widget _buildSkipToExerciseButton(BuildContext context, HeritageSite site) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.fitness_center, size: 18),
        label: const Text('Skip to Exercise (Demo)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white54,
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () {
          final challenge = HeritageChallenge.fromSite(site);
          context.push('/live-squat-test', extra: challenge);
        },
      ),
    );
  }

  IconData _getSiteIcon(String siteId) {
    switch (siteId) {
      case 'lingaraj_temple':
      case 'konark_sun_temple':
        return Icons.temple_hindu;
      case 'dhauli_shanti_stupa':
        return Icons.account_balance;
      case 'udayagiri_caves':
        return Icons.landscape;
      case 'pipili_village':
        return Icons.palette;
      default:
        return Icons.place;
    }
  }
}
