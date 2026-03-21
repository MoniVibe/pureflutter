import 'package:bullethole_shared/bullethole_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SessionEvent round-trip keeps required fields', () {
    final event = SessionEvent(
      schemaVersion: bughuntSchemaVersion,
      runId: 'run_1',
      sessionId: 'session_1',
      game: 'chess',
      mode: BughuntMode.local,
      role: BughuntRole.localA,
      appVersionOrCommitSha: 'abc123',
      roomIdOrMatchId: 'm-1',
      seed: 42,
      maxTurns: 120,
      deviceInfo: const <String, Object?>{'os': 'windows'},
      logicalTick: 1,
      wallClockTs: DateTime.utc(2026, 3, 18).toIso8601String(),
      turnIndex: 1,
      actionIndexOrPlyIndex: 1,
      eventType: 'action_applied',
      payload: const <String, Object?>{'from': 'e2', 'to': 'e4'},
      severity: BughuntSeverity.info,
    );

    final parsed = SessionEvent.tryParse(event.toJson());
    expect(parsed, isNotNull);
    expect(parsed!.runId, 'run_1');
    expect(parsed.eventType, 'action_applied');
    expect(parsed.payload['from'], 'e2');
  });
}
