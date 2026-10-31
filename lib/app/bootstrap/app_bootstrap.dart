import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serp_debug_overlay/flutter_debug_overlay.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_theme.dart';
import '../../core/config/debug_mode_provider.dart';
import '../router/app_router.dart';

class SuperApp extends ConsumerWidget {
  const SuperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDebugActive = ref.watch(isDebugModeEnabledProvider);
    DebugOverlay.enabled = isDebugActive;

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        return DebugOverlay(
          logBucket: globalLogBucket,
          httpBucket: globalHttpBucket,
          isDevelop: isDebugActive,
          enableFloatingButton: isDebugActive,
          pointers: 2,
          // hiddenFields: const [
          //   'Authorization',
          //   'token',
          //   'api-key',
          //   'password',
          // ],
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
