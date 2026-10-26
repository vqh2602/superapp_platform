import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/core/bridge_protocol/bridge_envelope.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';

void main() {
  group('Bridge Protocol Serialization Tests', () {
    test('BridgeRequest serializes and deserializes', () {
      final req = BridgeRequest(
        id: 'req_123',
        action: 'user.getProfile',
        payload: {'limit': 10},
        appId: 'sdk_playground',
        origin: 'miniapp://sdk_playground',
        timestamp: 1729930000000,
      );

      final json = req.toJson();
      expect(json['id'], equals('req_123'));
      expect(json['action'], equals('user.getProfile'));

      final parsed = BridgeRequest.fromJson(json);
      expect(parsed.id, equals('req_123'));
      expect(parsed.action, equals('user.getProfile'));
      expect(parsed.payload['limit'], equals(10));
      expect(parsed.appId, equals('sdk_playground'));
    });

    test('BridgeResponse.ok serializes correctly', () {
      final res = BridgeResponse.ok('req_123', {'name': 'Test User'}, 42);
      final json = res.toJson();

      expect(json['id'], equals('req_123'));
      expect(json['success'], isTrue);
      expect(json['data']['name'], equals('Test User'));
      expect(json['executionTimeMs'], equals(42));
      expect(json['error'], isNull);
    });

    test('BridgeResponse.failure serializes BridgeError', () {
      final err = BridgeError.permissionDenied('device.scanQRCode');
      final res = BridgeResponse.failure('req_123', err, 15);
      final json = res.toJson();

      expect(json['id'], equals('req_123'));
      expect(json['success'], isFalse);
      expect(json['error']['code'], equals('PERMISSION_DENIED'));
      expect(json['error']['details']['capability'], equals('device.scanQRCode'));
      expect(json['executionTimeMs'], equals(15));
    });

    test('BridgeEvent serializes correctly', () {
      final evt = BridgeEvent.create('auth.sessionChanged', {'state': 'logged_out'});
      final json = evt.toJson();

      expect(json['event'], equals('auth.sessionChanged'));
      expect(json['payload']['state'], equals('logged_out'));
      expect(json['timestamp'], isA<int>());
    });
  });
}
