import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/authentication/data/biometric_service.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/native_actions/handlers/biometric_action_handler.dart';

class FakeLocalAuth extends LocalAuthentication {
  bool supported = true;
  List<BiometricType> enrolled = [BiometricType.fingerprint];
  bool result = true;
  LocalAuthExceptionCode? failure;
  int prompts = 0;
  bool? biometricOnlyUsed;
  void Function()? onCheck;

  @override
  Future<bool> get canCheckBiometrics async => supported;
  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    onCheck?.call();
    return enrolled;
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    prompts++;
    biometricOnlyUsed = biometricOnly;
    if (failure != null) throw LocalAuthException(code: failure!);
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeLocalAuth auth;
  late BiometricService service;
  const context = ActionContext(appId: 'test');

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    auth = FakeLocalAuth();
    service = BiometricService(auth: auth);
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('distinguishes unsupported hardware from missing enrollment', () async {
    auth.supported = false;
    expect((await service.checkAvailability()).toJson(), {
      'supported': false,
      'enrolled': false,
      'canAuthenticate': false,
      'availableBiometrics': <String>[],
    });
    await expectLater(
      service.authenticate('Verify'),
      throwsA(isA<BridgeError>()),
    );
    auth.supported = true;
    auth.enrolled = [];
    final status = await service.checkAvailability();
    expect(status.supported, isTrue);
    expect(status.canAuthenticate, isFalse);
    await expectLater(
      service.authenticate('Verify'),
      throwsA(isA<BridgeError>()),
    );
    expect(auth.prompts, 0);
  });

  test('unsupported platforms never use native plugin', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect((await service.checkAvailability()).canAuthenticate, isFalse);
    await expectLater(
      service.authenticate('Verify'),
      throwsA(isA<BridgeError>()),
    );
    expect(auth.prompts, 0);
  });

  test('handler verifies availability and requires biometric only', () async {
    final handler = AuthAuthenticateBiometricHandler(service: service);
    expect(handler.requiresAuth, isTrue);
    expect(await handler.handle({'reason': ' Verify '}, context), {
      'authenticated': true,
    });
    expect(auth.biometricOnlyUsed, isTrue);
    auth.result = false;
    expect(await handler.handle({}, context), {'authenticated': false});
  });

  test('availability is checked again after enrollment changes', () async {
    expect((await service.checkAvailability()).canAuthenticate, isTrue);
    auth.enrolled = [];
    await expectLater(
      AuthAuthenticateBiometricHandler(service: service).handle({}, context),
      throwsA(
        isA<BridgeError>().having(
          (e) => e.code,
          'code',
          BridgeErrorCode.unsupported,
        ),
      ),
    );
    expect(auth.prompts, 0);
  });

  test('invalid reason never prompts', () async {
    for (final reason in ['', '   ', 123, 'x' * 201]) {
      await expectLater(
        AuthAuthenticateBiometricHandler(
          service: service,
        ).handle({'reason': reason}, context),
        throwsA(
          isA<BridgeError>().having(
            (e) => e.code,
            'code',
            BridgeErrorCode.invalidParams,
          ),
        ),
      );
    }
    expect(auth.prompts, 0);
  });

  test('cancelled runtime during availability check never prompts', () async {
    var active = true;
    auth.onCheck = () => active = false;
    await expectLater(
      AuthAuthenticateBiometricHandler(
        service: service,
      ).handle({}, ActionContext(appId: 'test', isSessionActive: () => active)),
      throwsA(
        isA<BridgeError>().having(
          (e) => e.code,
          'code',
          BridgeErrorCode.cancelled,
        ),
      ),
    );
    expect(auth.prompts, 0);
  });

  for (final entry in {
    LocalAuthExceptionCode.userCanceled: BridgeErrorCode.cancelled,
    LocalAuthExceptionCode.systemCanceled: BridgeErrorCode.cancelled,
    LocalAuthExceptionCode.temporaryLockout: BridgeErrorCode.rateLimitExceeded,
    LocalAuthExceptionCode.biometricLockout: BridgeErrorCode.rateLimitExceeded,
    LocalAuthExceptionCode.noBiometricsEnrolled: BridgeErrorCode.unsupported,
    LocalAuthExceptionCode.timeout: BridgeErrorCode.timeout,
  }.entries) {
    test('maps ${entry.key.name} to ${entry.value.code}', () async {
      auth.failure = entry.key;
      await expectLater(
        service.authenticate('Verify'),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', entry.value)),
      );
    });
  }
}
