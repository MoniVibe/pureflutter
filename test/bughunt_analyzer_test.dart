import 'package:bullethole_shared/bullethole_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SessionEvent event({
    required int logicalTick,
    required String eventType,
    Map<String, Object?> payload = const <String, Object?>{},
  }) {
    return SessionEvent(
      schemaVersion: bughuntSchemaVersion,
      runId: 'runA',
      sessionId: 's1',
      game: 'chess',
      mode: BughuntMode.online,
      role: BughuntRole.host,
      deviceInfo: const <String, Object?>{},
      logicalTick: logicalTick,
      wallClockTs: DateTime.utc(
        2026,
        3,
        18,
        12,
        0,
        logicalTick,
      ).toIso8601String(),
      turnIndex: 1,
      actionIndexOrPlyIndex: logicalTick,
      eventType: eventType,
      payload: payload,
      severity: BughuntSeverity.info,
    );
  }

  test('analyzer marks FAIL when queued action stays unresolved', () {
    final analyzer = BughuntAnalyzer(queueResolutionMaxTicks: 2);
    final result = analyzer.analyze(
      primary: <SessionEvent>[
        event(logicalTick: 1, eventType: 'session_created'),
        event(
          logicalTick: 2,
          eventType: 'action_queued',
          payload: const <String, Object?>{'queueToken': 5},
        ),
        event(logicalTick: 5, eventType: 'session_complete'),
      ],
    );

    expect(result.summary.verdict, BughuntGateVerdict.fail);
    expect(
      result.failures.any(
        (failure) => failure.failureCode == invariantQueueStuckTimeout,
      ),
      isTrue,
    );
  });

  test('analyzer marks PASS when no failures and session completes', () {
    final analyzer = BughuntAnalyzer();
    final result = analyzer.analyze(
      primary: <SessionEvent>[
        event(logicalTick: 1, eventType: 'session_created'),
        event(logicalTick: 2, eventType: 'action_queued'),
        event(logicalTick: 3, eventType: 'action_applied'),
        event(logicalTick: 4, eventType: 'session_complete'),
      ],
    );

    expect(result.summary.verdict, BughuntGateVerdict.pass);
    expect(result.failures, isEmpty);
  });
}
