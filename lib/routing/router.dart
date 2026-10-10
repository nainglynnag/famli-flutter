import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/family/family_privileges_screen.dart';
import '../features/family/family_screen.dart';
import '../features/family/nudge_edit_screen.dart';
import '../features/family/nudges_screen.dart';
import '../features/family/parents_screen.dart';
import '../features/family/rewards_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/points/points_history_screen.dart';
import '../features/points/points_screen.dart';
import '../features/privileges/privileges_history_screen.dart';
import '../features/privileges/privileges_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/tasks/routine_detail_screen.dart';
import '../features/tasks/task_detail_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../widgets/frosted_nav_bar.dart';

/// Monitors auth state and triggers router redirects when session changes.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authProvider, (previous, next) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final loggedIn = authState.value?.isAuthenticated ?? false;
      final isLoading = authState.isLoading;
      final onAuthScreens =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final onSplash = state.matchedLocation == '/';

      if (isLoading) {
        return onSplash ? null : '/';
      }
      if (!loggedIn) {
        return onAuthScreens ? null : '/login';
      }
      if (loggedIn && (onAuthScreens || onSplash)) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TasksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/family',
                builder: (context, state) => const _FamilyOrRewardsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/tasks/:taskId',
        builder: (context, state) =>
            TaskDetailScreen(taskId: state.pathParameters['taskId']!),
      ),
      GoRoute(
        path: '/tasks/routines/:templateId',
        builder: (context, state) => RoutineDetailScreen(
          templateId: state.pathParameters['templateId']!,
        ),
      ),
      GoRoute(
        path: '/points',
        builder: (context, state) => const PointsScreen(),
      ),
      GoRoute(
        path: '/points/history',
        builder: (context, state) => const PointsHistoryScreen(),
      ),
      GoRoute(
        path: '/privileges',
        builder: (context, state) => const PrivilegesScreen(showBackButton: true),
      ),
      GoRoute(
        path: '/privileges/history',
        builder: (context, state) => const PrivilegesHistoryScreen(),
      ),
      GoRoute(
        path: '/family/manage/parents',
        builder: (context, state) => const ParentsManageScreen(),
      ),
      GoRoute(
        path: '/family/privileges',
        builder: (context, state) => const FamilyPrivilegesScreen(),
      ),
      GoRoute(
        path: '/family/rewards',
        builder: (context, state) => const RewardsScreen(),
      ),
      GoRoute(
        path: '/family/nudges',
        builder: (context, state) => const NudgesScreen(),
      ),
      GoRoute(
        path: '/family/nudges/:childId',
        builder: (context, state) =>
            NudgeEditScreen(childId: state.pathParameters['childId']!),
      ),
    ],
  );
});

/// Shared application scaffold featuring the iOS 27 liquid frosted glass nav bar.
class _AppShell extends ConsumerWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).value?.profile;
    final isParent = profile?.role == UserRole.parent;

    final items = [
      const FrostedNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      const FrostedNavItem(
        icon: Icons.checklist_outlined,
        activeIcon: Icons.checklist_rounded,
        label: 'Tasks',
      ),
      FrostedNavItem(
        icon: isParent ? Icons.group_outlined : Icons.card_giftcard_outlined,
        activeIcon: isParent ? Icons.group_rounded : Icons.card_giftcard_rounded,
        label: isParent ? 'Family' : 'Rewards',
      ),
      const FrostedNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile',
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: FrostedNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        items: items,
      ),
    );
  }
}

class _FamilyOrRewardsScreen extends ConsumerWidget {
  const _FamilyOrRewardsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).value?.profile;
    if (profile?.role == UserRole.parent) {
      return const FamilyScreen();
    }
    return const PrivilegesScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF5C6AC4)),
            SizedBox(height: 12),
            Text(
              'Preparing Famli...',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
