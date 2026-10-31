import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/bootstrap/app_bootstrap.dart';
import 'core/config/debug_mode_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize SERP Debug Overlay logging and error capture
  initDebugOverlay();

  runApp(
    const ProviderScope(
      child: SuperApp(),
    ),
  );
}
