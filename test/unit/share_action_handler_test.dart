import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/native_actions/handlers/share_action_handler.dart';

void main() {
  test('sharing rejects missing content and invalid links', () async {
    final handler = ShareActionHandler();
    const context = ActionContext(appId: 'test');

    for (final payload in <Map<String, dynamic>>[
      {},
      {'text': '  '},
      {'text': 123},
      {'url': '/relative'},
      {'url': 'file:///private/data'},
    ]) {
      await expectLater(
        handler.handle(payload, context),
        throwsA(
          isA<BridgeError>().having(
            (error) => error.code,
            'code',
            BridgeErrorCode.invalidParams,
          ),
        ),
      );
    }
  });

  testWidgets('sharing passes content and origin and reports dismissal', (
    tester,
  ) async {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final messenger = tester.binding.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return '';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(
      const Center(child: SizedBox(width: 100, height: 50)),
    );
    final context = ActionContext(
      appId: 'test',
      buildContext: tester.element(find.byType(SizedBox)),
    );
    final handler = ShareActionHandler();

    final result = await handler.handle({
      'text': 'Tài liệu Flutter',
      'url': 'https://flutter.dev',
      'subject': 'Flutter',
    }, context);
    expect(result, {'status': 'dismissed'});
    expect(calls.single.method, 'share');
    expect(
      calls.single.arguments,
      containsPair('text', 'Tài liệu Flutter\nhttps://flutter.dev'),
    );
    expect(calls.single.arguments, containsPair('subject', 'Flutter'));
    expect(calls.single.arguments, containsPair('originWidth', 100.0));

    await handler.handle({'url': 'https://flutter.dev'}, context);
    expect(calls.last.arguments, containsPair('uri', 'https://flutter.dev'));
  });
}
