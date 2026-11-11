// Giao diện ủy quyền điều khiển giao diện khung chứa Mini App (Mini App UI Delegate).
//
// Cho phép các Native Action Handler thay đổi động giao diện Shell:
// đổi tiêu đề, màu header, màu status bar, ẩn/hiện thanh công cụ và giữ sáng màn hình.
import 'package:flutter/material.dart';

/// Hợp đồng Delegate cho phép điều khiển giao diện vỏ bọc của Mini App
abstract class MiniAppUiDelegate {
  /// Cập nhật tiêu đề trên thanh điều hướng đầu trang (Navigation Bar Title)
  void setTitle(String title, {String? align});

  /// Cấu hình màu nền navigation bar, màu chữ ('white' | 'black') và màu status bar
  void setNavigationBarColor({
    required Color color,
    String? textColor,
    Color? statusBarColor,
  });

  /// Cấu hình toàn diện khung nhìn ứng dụng: layout, màu sắc, ẩn thanh điều hướng, v.v.
  void configAppView({
    Color? headerColor,
    String? headerTitle,
    String? textColor,
    String? statusBar,
    Color? statusBarColor,
    bool? actionBarHidden,
    bool? hideAndroidBottomNavigationBar,
    bool? hasPadding,
    bool? hasPaddingTop,
    bool? hasPaddingBottom,
    Color? bottomNavColor,
    String? titleAlign,
  });

  /// Bật/tắt giữ sáng màn hình thiết bị (Wakelock)
  void keepScreen({required bool keepScreenOn});

  /// Thu nhỏ Mini App hiện tại xuống dạng cửa sổ nổi hoặc đóng app
  void minimizeApp();
}
