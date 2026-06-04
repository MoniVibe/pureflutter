import 'package:bullethole_shared/bullethole_shared_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('game session logger is best-effort during session lifecycle', () {
    final logger = GameSessionLogger(
      applicationId: 'test-app',
      gameId: 'test-game',
      mode: 'local',
    );

    expect(
      () => logger.beginSession(
        sessionLabel: 'smoke',
        context: const <String, Object?>{'source': 'test'},
      ),
      returnsNormally,
    );
    expect(
      () => logger.logEvent(
        'controller_initialized',
        data: const <String, Object?>{'ok': true},
      ),
      returnsNormally,
    );
    expect(() => logger.closeSession(reason: 'test_complete'), returnsNormally);
  });

  test('game session logger exports current session as jsonl', () {
    final logger = GameSessionLogger(
      applicationId: 'test-app',
      gameId: 'test-game',
      mode: 'local',
    );

    logger.beginSession(
      sessionLabel: 'export',
      context: const <String, Object?>{'source': 'test'},
    );
    logger.logEvent(
      'move_applied',
      data: const <String, Object?>{'from': 'a1', 'to': 'a2'},
    );

    final exported = logger.exportLatestSessionJsonl();
    expect(exported.trim(), isNotEmpty);
    expect(exported, contains('"eventType"'));
    expect(exported, contains('move_applied'));
    expect(exported.endsWith('\n'), isTrue);
  });
}
