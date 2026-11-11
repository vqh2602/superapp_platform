/// Điểm khởi đầu chính (Entry Point) của ứng dụng SuperApp Platform.
///
/// Quản lý khởi tạo binding Flutter, thiết lập hệ thống logging debug overlay
/// và bao bọc toàn bộ ứng dụng trong [ProviderScope] của Riverpod.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/bootstrap/app_bootstrap.dart';
import 'core/config/debug_mode_provider.dart';

/// Hàm main khởi chạy ứng dụng Flutter.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initDebugOverlay();
  runApp(
    const ProviderScope(
      child: SuperApp(),
    ),
  );
}
