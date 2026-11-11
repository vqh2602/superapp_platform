// Cấu hình điều hướng tập trung của SuperApp bằng [GoRouter].
//
// Định nghĩa các tuyến đường chính (Splash, Đăng nhập, Đăng ký, Trang chủ, Tìm kiếm,
// Môi trường Mini App Runtime, Trung tâm gỡ lỗi và Hồ sơ người dùng).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/animations/app_motion.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/register_screen.dart';
import '../../features/mini_app_catalog/presentation/mini_app_catalog_screen.dart';
import '../../features/mini_app_runtime/presentation/mini_app_runtime_screen.dart';
import '../../features/debug_center/presentation/native_debug_screen.dart';
import '../../features/debug_center/presentation/native_form_screen.dart';
import '../../features/user_profile/presentation/native_profile_screen.dart';
import '../../features/mini_app_catalog/presentation/screens/search_screen.dart';

/// Khóa điều hướng toàn cục cấp cao nhất (Root Navigator Key)
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Bộ định tuyến chính của ứng dụng cấu hình qua GoRouter.
final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Tuyến đường màn hình khởi động (Splash Screen)
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    // Tuyến đường màn hình đăng nhập tài khoản
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => buildSlideUpTransitionPage(
        context: context,
        state: state,
        child: const LoginScreen(),
      ),
    ),
    // Tuyến đường màn hình đăng ký tài khoản mới
    GoRoute(
      path: '/register',
      pageBuilder: (context, state) => buildSlideRightTransitionPage(
        context: context,
        state: state,
        child: const RegisterScreen(),
      ),
    ),
    // Tuyến đường màn hình chính / Danh mục Mini App (Catalog Screen)
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => buildSlideUpTransitionPage(
        context: context,
        state: state,
        child: const MiniAppCatalogScreen(),
      ),
    ),
    // Tuyến đường màn hình tìm kiếm Mini App
    GoRoute(
      path: '/search',
      pageBuilder: (context, state) => buildSlideUpTransitionPage(
        context: context,
        state: state,
        child: const SearchScreen(showBackButton: true),
      ),
    ),
    // Tuyến đường khởi chạy phiên thực thi Mini App theo appId
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
    // Tuyến đường màn hình Native Debug Center
    GoRoute(
      path: '/debug',
      pageBuilder: (context, state) => buildSlideRightTransitionPage(
        context: context,
        state: state,
        child: const NativeDebugScreen(),
      ),
    ),
    // Tuyến đường màn hình hồ sơ cá nhân người dùng
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => buildSlideRightTransitionPage(
        context: context,
        state: state,
        child: const NativeProfileScreen(),
      ),
    ),
    // Tuyến đường màn hình Native Form Demo
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
