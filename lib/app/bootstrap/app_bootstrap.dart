import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_theme.dart';
import '../router/app_router.dart';

class SuperApp extends StatelessWidget {
  const SuperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
