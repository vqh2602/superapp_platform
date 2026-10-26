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
    expect(find.text('SUPER APP PLATFORM'), findsOneWidget);

    // Wait for the bootstrap timer to complete (600ms)
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Should navigate to Mock Login Screen
    expect(find.text('Super App Mock Login'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Trần Thị B'), findsOneWidget);
  });
}
