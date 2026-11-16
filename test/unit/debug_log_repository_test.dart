import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/features/debug_center/data/debug_log_repository.dart';
import 'package:superapp_platform/features/debug_center/domain/bridge_log_entry.dart';

void main() {
  group('DebugLogRepository - Ring Buffer Tests', () {
    test('Maintains capacity limit and overwrites oldest entries in O(1)', () {
      final repo = DebugLogRepository(capacity: 3, isRelease: false);
      addTearDown(repo.dispose);

      expect(repo.logs, isEmpty);
      expect(repo.length, 0);

      // Add Entry 1
      repo.addLog(BridgeLogEntry(
        id: 'req_1',
        action: 'action_1',
        params: {'p': 1},
        success: true,
        executionTimeMs: 10,
        timestamp: DateTime.now(),
        appId: 'test_app',
      ));
      expect(repo.length, 1);
      expect(repo.logs.first.id, 'req_1');
      expect(repo.logs.map((l) => l.id).toList(), ['req_1']);

      // Add Entry 2
      repo.addLog(BridgeLogEntry(
        id: 'req_2',
        action: 'action_2',
        params: {'p': 2},
        success: true,
        executionTimeMs: 15,
        timestamp: DateTime.now(),
        appId: 'test_app',
      ));
      expect(repo.length, 2);
      expect(repo.logs.first.id, 'req_2');
      expect(repo.logs.map((l) => l.id).toList(), ['req_2', 'req_1']);

      // Add Entry 3 (at capacity)
      repo.addLog(BridgeLogEntry(
        id: 'req_3',
        action: 'action_3',
        params: {'p': 3},
        success: true,
        executionTimeMs: 20,
        timestamp: DateTime.now(),
        appId: 'test_app',
      ));
      expect(repo.length, 3);
      expect(repo.logs.first.id, 'req_3');
      expect(repo.logs.map((l) => l.id).toList(), ['req_3', 'req_2', 'req_1']);

      // Add Entry 4 (exceeds capacity -> req_1 is overwritten)
      repo.addLog(BridgeLogEntry(
        id: 'req_4',
        action: 'action_4',
        params: {'p': 4},
        success: true,
        executionTimeMs: 25,
        timestamp: DateTime.now(),
        appId: 'test_app',
      ));
      expect(repo.length, 3);
      expect(repo.logs.first.id, 'req_4');
      expect(repo.logs.map((l) => l.id).toList(), ['req_4', 'req_3', 'req_2']);

      // Add Entry 5 (req_2 is overwritten)
      repo.addLog(BridgeLogEntry(
        id: 'req_5',
        action: 'action_5',
        params: {'p': 5},
        success: true,
        executionTimeMs: 30,
        timestamp: DateTime.now(),
        appId: 'test_app',
      ));
      expect(repo.length, 3);
      expect(repo.logs.first.id, 'req_5');
      expect(repo.logs.map((l) => l.id).toList(), ['req_5', 'req_4', 'req_3']);
    });

    test('clear() resets ring buffer completely', () {
      final repo = DebugLogRepository(capacity: 5, isRelease: false);
      addTearDown(repo.dispose);

      for (var i = 0; i < 5; i++) {
        repo.addLog(BridgeLogEntry(
          id: 'req_$i',
          action: 'action',
          params: {},
          success: true,
          executionTimeMs: 5,
          timestamp: DateTime.now(),
          appId: 'app',
        ));
      }
      expect(repo.length, 5);
      expect(repo.logs.isNotEmpty, isTrue);

      repo.clear();
      expect(repo.length, 0);
      expect(repo.logs, isEmpty);
    });
  });

  group('DebugLogRepository - Batched Streaming Tests', () {
    test('Does NOT emit stream events when Debug Center is closed and no listeners', () async {
      final repo = DebugLogRepository(
        batchWindow: const Duration(milliseconds: 100),
        isRelease: false,
      );
      addTearDown(repo.dispose);

      expect(repo.shouldEmit, isFalse);

      for (var i = 0; i < 10; i++) {
        repo.addLog(BridgeLogEntry(
          id: 'req_$i',
          action: 'action',
          params: {},
          success: true,
          executionTimeMs: 1,
          timestamp: DateTime.now(),
          appId: 'app',
        ));
      }

      // Memory stores the logs, but no stream controller event was produced
      expect(repo.length, 10);
    });

    test('Batches rapid additions into a single stream emission within batchWindow', () async {
      final repo = DebugLogRepository(
        batchWindow: const Duration(milliseconds: 120),
        isRelease: false,
      );
      addTearDown(repo.dispose);

      final emissions = <List<BridgeLogEntry>>[];
      final sub = repo.stream.listen((batch) {
        emissions.add(batch);
      });
      addTearDown(sub.cancel);

      expect(repo.shouldEmit, isTrue);

      // Rapidly fire 20 RPC logs
      for (var i = 0; i < 20; i++) {
        repo.addLog(BridgeLogEntry(
          id: 'rpc_$i',
          action: 'testAction',
          params: {'index': i},
          success: true,
          executionTimeMs: 2,
          timestamp: DateTime.now(),
          appId: 'perf_app',
        ));
      }

      // Immediately after adding, timer is pending, no emission yet
      expect(emissions, isEmpty);

      // Wait for batch window (120ms + margin)
      await Future<void>.delayed(const Duration(milliseconds: 160));

      // Must have emitted exactly ONCE with all 20 logs
      expect(emissions.length, 1);
      expect(emissions.first.length, 20);
      expect(emissions.first.first.id, 'rpc_19'); // Newest first

      // Add another log after batch window completes
      repo.addLog(BridgeLogEntry(
        id: 'rpc_20',
        action: 'testAction',
        params: {},
        success: true,
        executionTimeMs: 1,
        timestamp: DateTime.now(),
        appId: 'perf_app',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 160));
      expect(emissions.length, 2);
      expect(emissions.last.length, 21);
      expect(emissions.last.first.id, 'rpc_20');
    });

    test('flush() immediately emits pending batch without waiting for timer', () async {
      final repo = DebugLogRepository(
        batchWindow: const Duration(milliseconds: 500),
        isRelease: false,
      );
      addTearDown(repo.dispose);

      final emissions = <List<BridgeLogEntry>>[];
      final sub = repo.stream.listen((batch) {
        emissions.add(batch);
      });
      addTearDown(sub.cancel);

      repo.addLog(BridgeLogEntry(
        id: 'req_fast',
        action: 'fast',
        params: {},
        success: true,
        executionTimeMs: 1,
        timestamp: DateTime.now(),
        appId: 'app',
      ));

      expect(emissions, isEmpty);

      // Manually flush
      repo.flush();
      await Future<void>.delayed(Duration.zero);
      expect(emissions.length, 1);
      expect(emissions.first.first.id, 'req_fast');
    });

    test('clear() immediately emits empty list to listeners', () async {
      final repo = DebugLogRepository(isRelease: false);
      addTearDown(repo.dispose);

      final emissions = <List<BridgeLogEntry>>[];
      final sub = repo.stream.listen((batch) {
        emissions.add(batch);
      });
      addTearDown(sub.cancel);

      repo.addLog(BridgeLogEntry(
        id: 'req_init',
        action: 'init',
        params: {},
        success: true,
        executionTimeMs: 1,
        timestamp: DateTime.now(),
        appId: 'app',
      ));

      repo.clear();
      await Future<void>.delayed(Duration.zero);
      expect(emissions.length, 1);
      expect(emissions.first, isEmpty);
    });
  });

  group('DebugLogRepository - Release Mode Payload Protection', () {
    test('Release mode strips responseData and stores only parameter keys', () {
      final releaseRepo = DebugLogRepository(isRelease: true);
      addTearDown(releaseRepo.dispose);

      final largeResponseData = {
        'heavyHtml': '<html><body>' * 500,
        'massiveArray': List.generate(1000, (i) => 'item_$i'),
        'binaryBuffer': 'A' * 50000,
      };

      releaseRepo.addLog(BridgeLogEntry(
        id: 'rpc_release',
        action: 'data.fetchHeavyPayload',
        params: {'filter': 'all', 'deepNested': {'key': 'val'}, 'token': 'secret_123'},
        success: true,
        responseData: largeResponseData,
        executionTimeMs: 45,
        timestamp: DateTime.now(),
        appId: 'heavy_app',
      ));

      final logged = releaseRepo.logs.first;
      expect(logged.id, 'rpc_release');
      expect(logged.action, 'data.fetchHeavyPayload');
      expect(logged.success, isTrue);

      // responseData must be null in release mode
      expect(logged.responseData, isNull);

      // params values must not be stored, only keys preserved
      expect(logged.params['_keys'], containsAll(['filter', 'deepNested', 'token']));
      expect(logged.params.containsKey('binaryBuffer'), isFalse);
    });

    test('Debug mode preserves responseData but truncates excessively large strings', () {
      final debugRepo = DebugLogRepository(isRelease: false);
      addTearDown(debugRepo.dispose);

      final giantString = 'B' * 10000;
      debugRepo.addLog(BridgeLogEntry(
        id: 'rpc_debug',
        action: 'data.debugPayload',
        params: {'query': 'normal'},
        success: true,
        responseData: {'output': giantString},
        executionTimeMs: 12,
        timestamp: DateTime.now(),
        appId: 'debug_app',
      ));

      final logged = debugRepo.logs.first;
      expect(logged.responseData, isNotNull);
      final output = (logged.responseData as Map<String, dynamic>)['output'] as String;
      expect(output.length, lessThan(giantString.length));
      expect(output, contains('[truncated 10000 chars]'));
    });
  });
}
