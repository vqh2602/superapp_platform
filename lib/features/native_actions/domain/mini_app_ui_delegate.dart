import 'package:flutter/material.dart';

/// Delegate allowing Native Action Handlers to dynamically modify the
/// SuperApp Mini App container UI (Title, Header Color, Status Bar, Fullscreen, Minimize, etc.)
abstract class MiniAppUiDelegate {
  /// Update the current navigation bar title in the top bar.
  void setTitle(String title);

  /// Set navigation bar background color, text color ('white' | 'black'), and optional status bar color.
  void setNavigationBarColor({
    required Color color,
    String? textColor,
    Color? statusBarColor,
  });

  /// Configure overall app view layout, visibility, and color styling across
  /// status bar, action bar, and bottom navigation / safe area inset.
  void configAppView({
    Color? headerColor,
    String? headerTitle,
    String? textColor,
    String? statusBar,
    bool? actionBarHidden,
    bool? hideAndroidBottomNavigationBar,
    bool? hasPadding,
    Color? bottomNavColor,
  });

  /// Keep the screen on / awake (or allow it to sleep).
  void keepScreen({required bool keepScreenOn});

  /// Minimize the current Mini App into a floating state / background dock.
  void minimizeApp();
}
