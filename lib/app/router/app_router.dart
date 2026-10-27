import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/authentication/presentation/screens/mock_login_screen.dart';
import '../../features/mini_app_catalog/presentation/mini_app_catalog_screen.dart';
import '../../features/mini_app_runtime/presentation/mini_app_runtime_screen.dart';
import '../../features/debug_center/presentation/native_debug_screen.dart';
import '../../features/debug_center/presentation/native_form_screen.dart';
import '../../features/user_profile/presentation/native_profile_screen.dart';
import '../../features/mini_app_catalog/presentation/screens/search_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const MockLoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const MiniAppCatalogScreen(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(showBackButton: true),
    ),
    GoRoute(
      path: '/miniapp/:appId',
      builder: (context, state) {
        final appId = state.pathParameters['appId'] ?? 'sdk_playground';
        return MiniAppRuntimeScreen(appId: appId);
      },
    ),
    GoRoute(
      path: '/debug',
      builder: (context, state) => const NativeDebugScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const NativeProfileScreen(),
    ),
    GoRoute(
      path: '/form',
      builder: (context, state) => const NativeFormScreen(),
    ),
  ],
);
