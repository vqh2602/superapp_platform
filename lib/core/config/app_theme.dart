// Cấu hình chủ đề giao diện (Theme) toàn hệ thống SuperApp.
//
// Định nghĩa bảng màu thiết kế theo chuẩn Material 3, typography, kiểu dáng nút bấm,
// thẻ card và thanh điều hướng phù hợp với cả Native Shell và Mini Apps.
import 'package:flutter/material.dart';

/// Định nghĩa bảng màu và theme tổng thể cho SuperApp
class AppTheme {
  /// Màu chủ đạo: Royal Blue hiện đại
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  /// Màu chủ đạo đậm hơn dùng cho trạng thái active/hover
  static const Color primaryDark = Color(0xFF1D4ED8);
  /// Màu phụ: Slate Dark dùng cho text chính và icon tối
  static const Color secondary = Color(0xFF0F172A); // Slate Dark
  /// Màu nền bề mặt ứng dụng (Scaffold background)
  static const Color surface = Color(0xFFF8FAFC);
  /// Màu nền thẻ Card
  static const Color cardBg = Colors.white;
  /// Màu điểm nhấn: Emerald Green biểu thị thành công hoặc tính năng nổi bật
  static const Color accent = Color(0xFF10B981); // Emerald
  /// Màu báo lỗi / cảnh báo nguy hiểm
  static const Color danger = Color(0xFFEF4444);
  /// Màu cảnh báo thận trọng
  static const Color warning = Color(0xFFF59E0B);

  /// Cấu hình ThemeData Material 3 chế độ sáng (Light Theme) của ứng dụng
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: danger,
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
