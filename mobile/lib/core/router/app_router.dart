import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../home/ui/home_dashboard_screen.dart';
import '../pose_engine/ui/camera_ml_validation_screen.dart';
import '../pose_engine/ui/live_squat_test_screen.dart';
import '../pose_engine/ui/live_workout_screen.dart';
import '../heritage_trek/ui/odyssey_map_screen.dart';
import '../heritage_trek/models/heritage_challenge.dart';
import '../heritage_trek/ui/challenge_details_screen.dart';
import '../heritage_trek/ui/heritage_trek_screen.dart';

// Shell layout providing bottom navigation bar across primary tabs
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Journey',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard_outlined),
            activeIcon: Icon(Icons.leaderboard),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Router configuration
final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const _PlaceholderScreen(title: 'Fit Odyssey Splash'),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const _PlaceholderScreen(title: 'Login'),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const _PlaceholderScreen(title: 'Register'),
    ),
    GoRoute(
      path: '/consent',
      builder: (context, state) => const _PlaceholderScreen(title: 'Privacy Consent'),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const _PlaceholderScreen(title: 'Onboarding'),
    ),
    // Bottom navigation tabs stateful shell
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeDashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/workout',
              builder: (context, state) => const _PlaceholderScreen(title: 'Exercise Selection'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/journey',
              builder: (context, state) => const OdysseyMapScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/leaderboard',
              builder: (context, state) => const _PlaceholderScreen(title: 'Campus Leaderboards'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const _PlaceholderScreen(title: 'Athlete Profile'),
            ),
          ],
        ),
      ],
    ),
    // ── Heritage Trek Flow ─────────────────────────────────────────────────
    // OdysseyMap → ChallengeDetails → HeritageTrek → Exercise → Workout
    GoRoute(
      path: '/challenge/:siteId',
      builder: (context, state) {
        final siteId = state.pathParameters['siteId'] ?? '';
        return ChallengeDetailsScreen(siteId: siteId);
      },
    ),
    GoRoute(
      path: '/heritage-trek/:siteId',
      builder: (context, state) {
        final siteId = state.pathParameters['siteId'] ?? '';
        return HeritageTrekScreen(siteId: siteId);
      },
    ),
    // ── Workout Flow ──────────────────────────────────────────────────────
    GoRoute(
      path: '/calibration/:exercise',
      builder: (context, state) {
        final exercise = state.pathParameters['exercise'] ?? 'squat';
        return _PlaceholderScreen(title: 'Calibration ($exercise)');
      },
    ),
    GoRoute(
      path: '/live-workout/:exercise',
      builder: (context, state) {
        final exercise = state.pathParameters['exercise'] ?? 'squat';
        return LiveWorkoutScreen(initialExercise: exercise);
      },
    ),
    GoRoute(
      path: '/workout-result',
      builder: (context, state) => const _PlaceholderScreen(title: 'Workout Summary'),
    ),
    GoRoute(
      path: '/progress',
      builder: (context, state) => const _PlaceholderScreen(title: 'Monthly Progress'),
    ),
    GoRoute(
      path: '/privacy-settings',
      builder: (context, state) => const _PlaceholderScreen(title: 'Privacy Settings'),
    ),
    GoRoute(
      path: '/ml-validation',
      builder: (context, state) => const CameraMLValidationScreen(),
    ),
    GoRoute(
      path: '/live-squat-test',
      builder: (context, state) {
        final challenge = state.extra as HeritageChallenge?;
        return LiveSquatTestScreen(challenge: challenge);
      },
    ),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    final isSplash = title == 'Fit Odyssey Splash';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fitness_center, size: 64, color: Color(0xFFFFB300)),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Phase 2 Scaffold Screen',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60),
              ),
              if (isSplash) ..._splashButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _splashButtons(BuildContext context) {
    return [
      const SizedBox(height: 32),
      // PRIMARY: Live Squat Test (Stage 2 validation)
      ElevatedButton.icon(
        icon: const Icon(Icons.self_improvement),
        label: const Text('🏋️  Live Squat Test',
            style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFB300),
          foregroundColor: Colors.black,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(double.infinity, 50),
        ),
        onPressed: () => context.push('/live-squat-test'),
      ),
      const SizedBox(height: 10),
      // Heritage Trek Journey
      ElevatedButton.icon(
        icon: const Icon(Icons.map_outlined),
        label: const Text('🗺️  Heritage Trek Journey',
            style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00E5FF),
          foregroundColor: Colors.black,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(double.infinity, 50),
        ),
        onPressed: () => context.go('/journey'),
      ),
      const SizedBox(height: 10),
      // DIAGNOSTIC: Camera ML Validation (Stage 1)
      OutlinedButton.icon(
        icon: const Icon(Icons.camera_alt),
        label: const Text('Camera ML Validation (Diagnostic)'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
        ),
        onPressed: () => context.push('/ml-validation'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        icon: const Icon(Icons.fitness_center),
        label: const Text('Live Workout (Simulation)'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
        ),
        onPressed: () => context.push('/live-workout/squat'),
      ),
    ];
  }
}
