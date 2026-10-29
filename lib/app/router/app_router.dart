import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/animations/app_motion.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/authentication/presentation/screens/mock_login_screen.dart';
import '../../features/authentication/presentation/screens/register_screen.dart';
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
      pageBuilder: (context, state) => buildSlideUpTransitionPage(
        context: context,
        state: state,
        child: const MockLoginScreen(),
      ),
    ),
    GoRoute(
      path: '/register',
      pageBuilder: (context, state) => buildSlideRightTransitionPage(
        context: context,
        state: state,
        child: const RegisterScreen(),
      ),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => buildSlideUpTransitionPage(
        context: context,
        state: state,
        child: const MiniAppCatalogScreen(),
      ),
    ),
    GoRoute(
      path: '/search',
      pageBuilder: (context, state) => buildSlideUpTransitionPage(
        context: context,
        state: state,
        child: const SearchScreen(showBackButton: true),
      ),
    ),
    GoRoute(
      path: '/miniapp/:appId',
      pageBuilder: (context, state) {
        final appId = state.pathParameters['appId'] ?? 'sdk_playground';
        return buildSlideUpTransitionPage(
          context: context,
          state: state,
          child: MiniAppRuntimeScreen(appId: appId),
        );
      },
    ),
    GoRoute(
      path: '/debug',
      pageBuilder: (context, state) => buildSlideRightTransitionPage(
        context: context,
        state: state,
        child: const NativeDebugScreen(),
      ),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => buildSlideRightTransitionPage(
        context: context,
        state: state,
        child: const NativeProfileScreen(),
      ),
    ),
    GoRoute(
      path: '/form',
      pageBuilder: (context, state) => buildSlideRightTransitionPage(
        context: context,
        state: state,
        child: const NativeFormScreen(),
      ),
    ),
  ],
);
