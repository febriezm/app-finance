import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_providers.dart';
import 'scaffold_with_nav_bar.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/transactions/presentation/screens/transactions_screen.dart';
import '../features/wallets/presentation/screens/wallets_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/budgets/presentation/screens/budgets_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/receipt_scanner/presentation/screens/receipt_scanner_screen.dart';
import '../features/auth/presentation/screens/landing_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final GlobalKey<NavigatorState> _transactionsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'transactions');
final GlobalKey<NavigatorState> _walletsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'wallets');
final GlobalKey<NavigatorState> _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

/// Notifier untuk memberi sinyal re-evaluasi rute saat status autentikasi berubah
class AuthRouterNotifier extends ChangeNotifier {
  AuthRouterNotifier(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) {
      notifyListeners();
    });
  }
}

/// Provider GoRouter reaktif dengan proteksi Cloud Authentication Mandatory
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = AuthRouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRouter.home,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authUser = ref.read(authCurrentUserProvider);
      final isLoggedIn = authUser != null;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == AppRouter.landing ||
          loc == AppRouter.login ||
          loc == AppRouter.register ||
          loc == AppRouter.forgotPassword ||
          loc == AppRouter.resetPassword;

      // 1. Jika belum login dan mencoba mengakses rute aplikasi -> arahkan ke Landing Page
      if (!isLoggedIn && !isAuthRoute) {
        return AppRouter.landing;
      }

      // 2. Jika sudah login dan mencoba ke halaman auth/landing -> arahkan ke dashboard
      if (isLoggedIn && (loc == AppRouter.landing || loc == AppRouter.login || loc == AppRouter.register)) {
        return AppRouter.home;
      }

      return null;
    },
    routes: AppRouter.routes,
  );
});

class AppRouter {
  AppRouter._();

  static const String home = '/';
  static const String transactions = '/transactions';
  static const String wallets = '/wallets';
  static const String reports = '/reports';
  static const String budgets = '/budgets';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String receiptScanner = '/receipt-scanner';
  static const String landing = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  static List<RouteBase> get routes => [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return ScaffoldWithNavBar(navigationShell: navigationShell);
          },
          branches: [
            // Branch 0: Dashboard
            StatefulShellBranch(
              navigatorKey: _homeNavigatorKey,
              routes: [
                GoRoute(
                  path: home,
                  builder: (context, state) => const DashboardScreen(),
                ),
              ],
            ),

            // Branch 1: Transactions
            StatefulShellBranch(
              navigatorKey: _transactionsNavigatorKey,
              routes: [
                GoRoute(
                  path: transactions,
                  builder: (context, state) {
                    DateTime? initialMonth;
                    if (state.extra is Map && (state.extra as Map).containsKey('initialMonth')) {
                      final val = (state.extra as Map)['initialMonth'];
                      if (val is DateTime) initialMonth = val;
                    } else if (state.extra is DateTime) {
                      initialMonth = state.extra as DateTime;
                    }
                    return TransactionsScreen(initialMonth: initialMonth);
                  },
                ),
              ],
            ),

            // Branch 2: Wallets
            StatefulShellBranch(
              navigatorKey: _walletsNavigatorKey,
              routes: [
                GoRoute(
                  path: wallets,
                  builder: (context, state) => const WalletsScreen(),
                ),
              ],
            ),

            // Branch 3: Profile (Tukar tempat menggantikan Laporan pada Tab Bar)
            StatefulShellBranch(
              navigatorKey: _profileNavigatorKey,
              routes: [
                GoRoute(
                  path: profile,
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),

        // Standalone Routes
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: reports,
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: budgets,
          builder: (context, state) => const BudgetsScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: receiptScanner,
          builder: (context, state) => const ReceiptScannerScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: landing,
          builder: (context, state) => const LandingScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: register,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: forgotPassword,
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: resetPassword,
          builder: (context, state) => const ResetPasswordScreen(),
        ),
      ];

  /// Fallback static router instance
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: home,
    routes: routes,
  );
}
