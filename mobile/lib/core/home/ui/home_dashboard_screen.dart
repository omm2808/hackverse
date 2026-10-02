import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../providers/home_providers.dart';

/// Premium Home Dashboard for Fit Odyssey.
///
/// Sections:
/// 1. Greeting header with avatar, level, streak
/// 2. XP progress bar
/// 3. Today's Workout cards
/// 4. Daily Missions checklist
/// 5. Active Odyssey Quest card
/// 6. Quick action buttons
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  static const String routeName = 'home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Greeting Header ─────────────────────────────────
            SliverToBoxAdapter(child: _HeaderSection()),

            // ── XP Progress ─────────────────────────────────────
            SliverToBoxAdapter(child: _XpProgressSection()),

            // ── Quick Actions ───────────────────────────────────
            SliverToBoxAdapter(child: _QuickActionsSection()),

            // ── Today's Workout ─────────────────────────────────
            const SliverToBoxAdapter(
              child: _SectionTitle(
                title: "Today's Workout",
                icon: Icons.fitness_center,
                accentColor: AppTheme.primaryGold,
              ),
            ),
            SliverToBoxAdapter(child: _WorkoutCardsSection()),

            // ── Daily Missions ──────────────────────────────────
            const SliverToBoxAdapter(
              child: _SectionTitle(
                title: 'Daily Missions',
                icon: Icons.flag_rounded,
                accentColor: AppTheme.accentGreen,
              ),
            ),
            SliverToBoxAdapter(child: _DailyMissionsSection()),

            // ── Active Odyssey Quest ────────────────────────────
            const SliverToBoxAdapter(
              child: _SectionTitle(
                title: 'Active Odyssey Quest',
                icon: Icons.explore_rounded,
                accentColor: AppTheme.secondaryCyan,
              ),
            ),
            SliverToBoxAdapter(child: _OdysseyQuestSection()),

            // Bottom padding for nav bar
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _HeaderSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(dashboardProfileProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryGold, Color(0xFFFF6D00)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGold.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                profile.displayName.isNotEmpty
                    ? profile.displayName[0].toUpperCase()
                    : 'A',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Greeting + Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          // Streak Badge
          _StreakBadge(days: profile.streakDays),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int days;
  const _StreakBadge({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: days > 0
              ? [const Color(0xFFFF6D00), AppTheme.primaryGold]
              : [AppTheme.surfaceElevated, AppTheme.surfaceDark],
        ),
        boxShadow: days > 0
            ? [
                BoxShadow(
                  color: AppTheme.primaryGold.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 18,
            color: days > 0 ? Colors.black : Colors.white54,
          ),
          const SizedBox(width: 4),
          Text(
            '$days',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: days > 0 ? Colors.black : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// XP PROGRESS SECTION
// ═══════════════════════════════════════════════════════════════════════════════

class _XpProgressSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(dashboardProfileProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.surfaceDark,
        border: Border.all(
          color: AppTheme.primaryGold.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Level badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryGold, Color(0xFFFF6D00)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGold.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${profile.level}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level ${profile.level}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${profile.currentXp} / ${profile.xpToNextLevel} XP',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Total XP
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.primaryGold.withValues(alpha: 0.12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        size: 16, color: AppTheme.primaryGold),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.currentXp} XP',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // XP Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  // Background track
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Progress fill
                  FractionallySizedBox(
                    widthFactor: profile.levelProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryGold, Color(0xFFFF6D00)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppTheme.primaryGold.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUICK ACTIONS
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _QuickActionButton(
            icon: Icons.self_improvement_rounded,
            label: 'Squat Test',
            gradient: const [AppTheme.primaryGold, Color(0xFFFF6D00)],
            onTap: () => context.push('/live-squat-test'),
          ),
          const SizedBox(width: 10),
          _QuickActionButton(
            icon: Icons.map_rounded,
            label: 'Heritage Trek',
            gradient: const [AppTheme.secondaryCyan, Color(0xFF0091EA)],
            onTap: () => context.go('/journey'),
          ),
          const SizedBox(width: 10),
          _QuickActionButton(
            icon: Icons.camera_alt_rounded,
            label: 'ML Validate',
            gradient: const [Color(0xFF7C4DFF), Color(0xFFB388FF)],
            onTap: () => context.push('/ml-validation'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.gradient[0].withValues(alpha: 0.15),
                  widget.gradient[1].withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: widget.gradient[0].withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(widget.icon, size: 28, color: widget.gradient[0]),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.gradient[0],
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION TITLE
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;

  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WORKOUT CARDS (HORIZONTAL SCROLL)
// ═══════════════════════════════════════════════════════════════════════════════

class _WorkoutCardsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(suggestedWorkoutsProvider);

    return SizedBox(
      height: 175,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: workouts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _WorkoutCard(workout: workouts[index]);
        },
      ),
    );
  }
}

class _WorkoutCard extends StatefulWidget {
  final SuggestedWorkout workout;
  const _WorkoutCard({required this.workout});

  @override
  State<_WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<_WorkoutCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _elevationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.workout.difficulty) {
      case 'Beginner':
        return AppTheme.accentGreen;
      case 'Moderate':
        return AppTheme.primaryGold;
      case 'Challenging':
        return const Color(0xFFFF6D00);
      default:
        return AppTheme.primaryGold;
    }
  }

  IconData get _exerciseIcon {
    switch (widget.workout.exerciseType) {
      case 'push_up':
        return Icons.sports_gymnastics_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _hoverController.forward(),
      onTapUp: (_) {
        _hoverController.reverse();
        context.push('/live-workout/${widget.workout.exerciseType}');
      },
      onTapCancel: () => _hoverController.reverse(),
      child: AnimatedBuilder(
        animation: _elevationAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -2 * _elevationAnimation.value),
            child: child,
          );
        },
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceDark,
                _accentColor.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(
              color: _accentColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + Difficulty badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _accentColor.withValues(alpha: 0.15),
                    ),
                    child: Icon(_exerciseIcon, size: 22, color: _accentColor),
                  ),
                  Flexible(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _accentColor.withValues(alpha: 0.12),
                      ),
                      child: Text(
                        widget.workout.difficulty,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _accentColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Title
              Text(
                widget.workout.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                widget.workout.subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Bottom stats
              Row(
                children: [
                  Icon(Icons.timer_outlined,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      '${widget.workout.durationMinutes} min',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.bolt_rounded,
                      size: 13, color: AppTheme.primaryGold.withValues(alpha: 0.7)),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      '${widget.workout.estimatedXp} XP',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryGold.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAILY MISSIONS
// ═══════════════════════════════════════════════════════════════════════════════

class _DailyMissionsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = ref.watch(dailyMissionsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: missions.map((m) => _MissionTile(mission: m)).toList(),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  final DailyMission mission;
  const _MissionTile({required this.mission});

  IconData _getIcon() {
    switch (mission.iconName) {
      case 'directions_walk':
        return Icons.directions_walk_rounded;
      case 'star':
        return Icons.star_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = mission.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isComplete
            ? AppTheme.accentGreen.withValues(alpha: 0.08)
            : AppTheme.surfaceDark,
        border: Border.all(
          color: isComplete
              ? AppTheme.accentGreen.withValues(alpha: 0.25)
              : AppTheme.surfaceElevated,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isComplete
                  ? AppTheme.accentGreen.withValues(alpha: 0.15)
                  : AppTheme.surfaceElevated,
            ),
            child: Icon(
              isComplete ? Icons.check_rounded : _getIcon(),
              size: 20,
              color: isComplete ? AppTheme.accentGreen : Colors.white54,
            ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        isComplete ? Colors.white60 : Colors.white,
                    decoration:
                        isComplete ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mission.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // XP reward
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: AppTheme.primaryGold.withValues(alpha: 0.1),
                ),
                child: Text(
                  '+${mission.rewardXp} XP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isComplete
                        ? Colors.white38
                        : AppTheme.primaryGold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Mini progress bar
              SizedBox(
                width: 50,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: mission.progress,
                    backgroundColor: AppTheme.surfaceElevated,
                    valueColor: AlwaysStoppedAnimation(
                      isComplete ? AppTheme.accentGreen : AppTheme.primaryGold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVE ODYSSEY QUEST
// ═══════════════════════════════════════════════════════════════════════════════

class _OdysseyQuestSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref.watch(activeQuestProvider);
    final completedSites = quest['completedSites'] as int;
    final totalSites = quest['totalSites'] as int;
    final totalXp = quest['totalXp'] as int;
    final nextSiteName = quest['nextSiteName'] as String;
    final nextSiteId = quest['nextSiteId'] as String?;
    final isComplete = quest['isComplete'] as bool;
    final progress = totalSites > 0 ? completedSites / totalSites : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceDark,
            AppTheme.secondaryCyan.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: AppTheme.secondaryCyan.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryCyan.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quest header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.secondaryCyan.withValues(alpha: 0.2),
                      AppTheme.secondaryCyan.withValues(alpha: 0.08),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.temple_hindu_rounded,
                  size: 24,
                  color: AppTheme.secondaryCyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest['journeyName'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isComplete
                          ? 'Journey Complete! 🎉'
                          : 'Next: $nextSiteName',
                      style: TextStyle(
                        fontSize: 12,
                        color: isComplete
                            ? AppTheme.accentGreen
                            : Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.secondaryCyan,
                            Color(0xFF0091EA),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondaryCyan.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _QuestStat(
                icon: Icons.place_rounded,
                label: '$completedSites / $totalSites sites',
                color: AppTheme.secondaryCyan,
              ),
              _QuestStat(
                icon: Icons.bolt_rounded,
                label: '$totalXp XP earned',
                color: AppTheme.primaryGold,
              ),
            ],
          ),
          if (!isComplete && nextSiteId != null) ...[
            const SizedBox(height: 14),
            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.directions_walk_rounded, size: 18),
                label: const Text(
                  'Continue Trek',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () =>
                    context.push('/heritage-trek/$nextSiteId'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _QuestStat({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
