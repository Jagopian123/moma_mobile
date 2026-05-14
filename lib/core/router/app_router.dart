import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/pages/splash_page.dart';
import '../../features/auth/pages/onboarding_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/onboarding_provider.dart';
import '../../features/premium/pages/premium_page.dart';
import '../../features/settings/pages/profile_page.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../../features/asset/pages/asset_page.dart';
import '../../features/transaction/pages/ai_chat_page.dart';
import '../../features/transaction/pages/transaction_page.dart';
import '../../features/budget/pages/budget_page.dart';
import '../../features/financial_plan/pages/financial_plan_page.dart';
import '../../features/debt/pages/debt_page.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/insights/pages/insights_page.dart';

// ── Placeholder pages ────────────────────────────────────────────────────────
class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_rounded,
                  size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sedang dikerjakan',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Router Notifier ──────────────────────────────────────────────────────────
// Memberitahu GoRouter untuk re-run redirect ketika auth/onboarding berubah,
// tanpa perlu membuat ulang GoRouter instance.
class _GoRouterNotifier extends ChangeNotifier {
  _GoRouterNotifier(Ref ref) {
    ref.listen<dynamic>(authProvider, (_, __) => notifyListeners());
    ref.listen<dynamic>(onboardingProvider, (_, __) => notifyListeners());
    _ref = ref;
  }

  late final Ref _ref;

  String? redirect(GoRouterState state) {
    final authState = _ref.read(authProvider);
    final onboardingDone = _ref.read(onboardingProvider);
    final location = state.matchedLocation;
    final isAuth = authState.isAuthenticated;
    final isUnknown = authState.isUnknown;

    // Tunggu saat auth masih loading
    if (isUnknown) return null;

    // Belum onboarding → onboarding dulu (hanya untuk user yang belum login)
    // Jika sudah auth, skip — user pasti sudah pernah onboarding sebelumnya.
    if (!isAuth && !onboardingDone &&
        location != '/onboarding' &&
        location != '/splash') {
      return '/onboarding';
    }

    // Belum login → ke login
    if (!isAuth &&
        location != '/login' &&
        location != '/onboarding' &&
        location != '/splash') {
      return '/login';
    }

    // Sudah login, masih di auth page → ke home
    if (isAuth && (location == '/login' || location == '/onboarding')) {
      return '/home';
    }

    return null;
  }
}

// ── Router Provider ──────────────────────────────────────────────────────────
// GoRouter dibuat SEKALI dan tidak pernah di-recreate.
// Auth change hanya men-trigger re-run redirect, bukan recreate router.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _GoRouterNotifier(ref);

  final router = GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: (_, state) => notifier.redirect(state),
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (_, __) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginPage(),
      ),

      // ── Main Shell ───────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (_, __) => const HomePage(),
          ),
          GoRoute(
            path: '/transaction',
            name: 'transaction',
            builder: (_, __) => const TransactionPage(),
          ),
          GoRoute(
            path: '/asset',
            name: 'asset',
            builder: (_, __) => const AssetPage(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (_, __) => const SettingsPage(),
          ),
        ],
      ),

      // ── Full screen pages ─────────────────────────────────────
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (_, __) => const ProfilePage(),
      ),
      GoRoute(
        path: '/budget',
        name: 'budget',
        builder: (_, __) => const BudgetPage(),
      ),
      GoRoute(
        path: '/financial-plan',
        name: 'financialPlan',
        builder: (_, __) => const FinancialPlanPage(),
      ),
      GoRoute(
        path: '/debt',
        name: 'debt',
        builder: (_, __) => const DebtPage(),
      ),
      GoRoute(
        path: '/ai-chat',
        name: 'aiChat',
        builder: (_, __) => const AiChatPage(),
      ),
      GoRoute(
        path: '/insights',
        name: 'insights',
        builder: (_, __) => const InsightsPage(),
      ),
      GoRoute(
        path: '/premium',
        name: 'premium',
        builder: (_, __) => const PremiumPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            const Text(
              'Halaman tidak ditemukan',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Kembali ke Home'),
            ),
          ],
        ),
      ),
    ),
  );

  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });

  return router;
});
