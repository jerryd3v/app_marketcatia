import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_provider.dart';
import '../screens/account_screen.dart';
import '../screens/campaign_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/order_view_screen.dart';
import '../screens/qr_screen.dart';
import '../screens/recovery_password_screen.dart';
import '../screens/temp_order_screen.dart';
import '../widgets/app_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter(AppProvider provider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: provider,
    redirect: (context, state) {
      final path = state.uri.path;
      final loggedIn = provider.user != null;
      if (path == '/account' && !loggedIn) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/temp-order/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => AppScaffold(
          location: '/temp-order',
          child: TempOrderScreen(orderId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/order-view-v2/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => AppScaffold(
          location: '/order-view-v2',
          child: OrderViewScreen(orderId: state.pathParameters['id']!),
        ),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppScaffold(
            location: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/login',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const LoginScreen(),
            ),
          ),
          GoRoute(
            path: '/recovery-password',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const RecoveryPasswordScreen(),
            ),
          ),
          GoRoute(
            path: '/account',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AccountScreen(),
            ),
          ),
          GoRoute(
            path: '/cart',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const CartScreen(),
            ),
          ),
          GoRoute(
            path: '/qr',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const QrScreen(),
            ),
          ),
          GoRoute(
            path: '/campana/banner/:id',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: CampaignScreen(
                bannerId: state.pathParameters['id'],
              ),
            ),
          ),
          GoRoute(
            path: '/campana/ofertas',
            pageBuilder: (_, state) => NoTransitionPage(
              key: state.pageKey,
              child: const CampaignScreen(isDailyOffers: true),
            ),
          ),
        ],
      ),
    ],
  );
}
