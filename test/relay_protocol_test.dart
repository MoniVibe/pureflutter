import 'package:bullethole_shared/bullethole_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('relay envelope round-trip from state and message', () {
    const envelope = RelayEnvelope(
      event: RelayEventName.action,
      payload: <String, Object?>{'kind': 'checker_move', 'from': 12, 'to': 8},
      stateHash: 'abc123',
      result: null,
    );

    final socketPayload = envelope.toSocketPayload();
    final fromMessage = RelayEnvelope.fromRelayMessage(
      Map<String, dynamic>.from(socketPayload),
    );
    expect(fromMessage, isNotNull);
    expect(fromMessage!.event, RelayEventName.action);
    expect(fromMessage.payload['kind'], 'checker_move');
    expect(fromMessage.stateHash, 'abc123');

    final state = <String, dynamic>{'relayState': envelope.toStateRelayState()};
    final fromState = RelayEnvelope.fromState(state);
    expect(fromState, isNotNull);
    expect(fromState!.event, RelayEventName.action);
    expect(fromState.payload['from'], 12);
  });

  test('relay ack parsing requires valid sequence and event', () {
    final ack = RelayAck.fromMessage(<String, dynamic>{
      'type': 'relay_ack',
      'sequence': 17,
      'event': RelayEventName.ready,
      'fromColor': 'w',
      'stateHash': 'state-hash',
    });

    expect(ack, isNotNull);
    expect(ack!.sequence, 17);
    expect(ack.event, RelayEventName.ready);
    expect(ack.fromColor, 'w');
    expect(ack.stateHash, 'state-hash');

    final invalid = RelayAck.fromMessage(<String, dynamic>{
      'type': 'relay_ack',
      'sequence': 'bad',
      'event': 'invalid event with spaces',
    });
    expect(invalid, isNull);
  });

  test('relay session meta parsing is stable', () {
    final meta = RelaySessionMeta.fromState(<String, dynamic>{
      'relayMeta': <String, dynamic>{
        'readyW': true,
        'readyB': '1',
        'actionCount': '4',
      },
    });

    expect(meta.whiteReady, isTrue);
    expect(meta.blackReady, isTrue);
    expect(meta.actionCount, 4);
    expect(meta.allReady, isTrue);
  });
}
