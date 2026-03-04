import 'package:bullethole_shared/bullethole_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MultiplayerClientUtils', () {
    test('parseApiBaseUri parses full URL and trims whitespace', () {
      final uri = MultiplayerClientUtils.parseApiBaseUri(
        ' https://example.com:8443/base ',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'example.com');
      expect(uri.port, 8443);
      expect(uri.path, '/base');
    });

    test('parseApiBaseUri rejects non-absolute values', () {
      expect(
        () => MultiplayerClientUtils.parseApiBaseUri('localhost:8080'),
        throwsException,
      );
      expect(
        () => MultiplayerClientUtils.parseApiBaseUri('/relative/path'),
        throwsException,
      );
    });

    test('websocketUriFromBase upgrades scheme and normalizes path', () {
      final httpBase = MultiplayerClientUtils.parseApiBaseUri(
        'http://localhost:8080',
      );
      final httpsBase = MultiplayerClientUtils.parseApiBaseUri(
        'https://example.com',
      );

      final ws = MultiplayerClientUtils.websocketUriFromBase(
        baseUri: httpBase,
        wsPath: 'ws',
        queryParameters: const <String, String>{'matchId': 'm1'},
      );
      final wss = MultiplayerClientUtils.websocketUriFromBase(
        baseUri: httpsBase,
        wsPath: '/socket',
      );

      expect(ws.toString(), 'ws://localhost:8080/ws?matchId=m1');
      expect(wss.toString(), 'wss://example.com/socket');
    });

    test('decodeJsonMap returns map for object payloads only', () {
      final valid = MultiplayerClientUtils.decodeJsonMap(
        '{"ok":true,"cooldownSeconds":3}',
      );
      final listPayload = MultiplayerClientUtils.decodeJsonMap('[1,2,3]');
      final invalid = MultiplayerClientUtils.decodeJsonMap('{');
      final empty = MultiplayerClientUtils.decodeJsonMap('   ');

      expect(valid['ok'], true);
      expect(valid['cooldownSeconds'], 3);
      expect(listPayload, isEmpty);
      expect(invalid, isEmpty);
      expect(empty, isEmpty);
    });

    test('readInt handles int, num, and string values', () {
      expect(MultiplayerClientUtils.readInt(7), 7);
      expect(MultiplayerClientUtils.readInt(7.9), 7);
      expect(MultiplayerClientUtils.readInt('42'), 42);
      expect(MultiplayerClientUtils.readInt('nope'), isNull);
      expect(MultiplayerClientUtils.readInt(null), isNull);
    });

    test('sanitizeIdentifier enforces expected safe format', () {
      expect(
        MultiplayerClientUtils.sanitizeIdentifier(' chess_classic '),
        'chess_classic',
      );
      expect(MultiplayerClientUtils.sanitizeIdentifier('skin-1'), 'skin-1');
      expect(MultiplayerClientUtils.sanitizeIdentifier('SkinUpper'), isNull);
      expect(
        MultiplayerClientUtils.sanitizeIdentifier('skin with space'),
        isNull,
      );
      expect(MultiplayerClientUtils.sanitizeIdentifier('x' * 41), isNull);
    });
  });
}
