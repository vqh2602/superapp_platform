import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_platform/app/bootstrap/app_bootstrap.dart';

void main() {
  testWidgets('Super App boots, displays Splash Screen, and navigates to Login', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SuperApp(),
      ),
    );

    // Initial frame shows splash screen
    expect(find.text('SUPERAPP'), findsOneWidget);

    // Wait for the bootstrap timer to complete (600ms)
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Should navigate to Login Screen with Endpoint, Email, Password & Register fields
    expect(find.text('SuperApp Platform'), findsOneWidget);
    expect(find.text('Backend Endpoint URL'), findsOneWidget);
    expect(find.text('Email / Tài khoản'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Đăng nhập SuperApp'), findsOneWidget);
    expect(find.text('Đăng ký tài khoản mới'), findsOneWidget);
  });
}
