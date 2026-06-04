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
}
