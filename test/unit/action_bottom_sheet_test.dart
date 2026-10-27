import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/features/mini_app_catalog/domain/mini_app_manifest.dart';
import 'package:superapp_platform/features/mini_app_runtime/presentation/widgets/mini_app_action_bottom_sheet.dart';

void main() {
  testWidgets('MiniAppActionBottomSheet renders all sections and handles actions', (tester) async {
    const manifest = MiniAppManifest(
      id: 'messenger',
      name: 'Messenger',
      description: 'Text, audio and video calls',
      version: '1.0.0',
      icon: 'social',
      entryUrl: 'assets/mini_apps/schema_runtime/index.html',
      category: 'Social Network',
      capabilities: ['user.getBasicInfo', 'navigation.close'],
    );

    bool reloaded = false;
    bool minimized = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    MiniAppActionBottomSheet.show(
                      context,
                      manifest: manifest,
                      appId: 'messenger',
                      onReload: () => reloaded = true,
                      onMinimize: () => minimized = true,
                    );
                  },
                  child: const Text('Open Sheet'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Tap to open bottom sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('Messenger'), findsOneWidget);
    expect(find.text('Social Network Official'), findsOneWidget);

    // Verify "Gửi tới" Section
    expect(find.text('Gửi tới'), findsOneWidget);
    expect(find.text('Sầu Riêng'), findsOneWidget);
    expect(find.text('XU É 12'), findsOneWidget);
    expect(find.text('4TLS-BK H...'), findsOneWidget);
    expect(find.text('Xem thêm'), findsOneWidget);

    // Verify Share Link
    expect(find.text('https://superapp.vn/s/messenger'), findsOneWidget);

    // Verify 6 Action Tiles
    expect(find.text('Mã QR'), findsOneWidget);
    expect(find.text('Tạo phím tắt'), findsOneWidget);
    expect(find.text('Yêu thích'), findsOneWidget);
    expect(find.text('Thu nhỏ'), findsOneWidget);
    expect(find.text('Quản lý quyền'), findsOneWidget);
    expect(find.text('Tải lại'), findsOneWidget);

    // Tap "Tải lại"
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(reloaded, isTrue);
  });
}
