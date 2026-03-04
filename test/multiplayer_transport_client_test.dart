import 'dart:convert';

import 'package:bullethole_shared/bullethole_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('MultiplayerTransportClient', () {
    test('joinMatch returns parsed session metadata', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://example.com/api/matches/join');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['name'], 'PlayerA');
        expect(payload['pieceSkinId'], 'chess_classic');
        expect(payload['cooldownSeconds'], 5);
        return http.Response(
          jsonEncode(<String, dynamic>{
            'matchId': 'm1',
            'playerId': 'p1',
            'wsPath': '/ws',
            'cooldownSeconds': 5,
          }),
          200,
        );
      });

      final transport = MultiplayerTransportClient(httpClient: client);
      final joined = await transport.joinMatch(
        apiBaseUrl: 'https://example.com',
        displayName: 'PlayerA',
        pieceSkinId: 'chess_classic',
        cooldownSeconds: 5,
      );

      expect(joined.matchId, 'm1');
      expect(joined.playerId, 'p1');
      expect(joined.wsPath, '/ws');
      expect(joined.cooldownSeconds, 5);
      transport.dispose();
    });

    test('joinMatch throws MultiplayerHttpException on non-2xx', () async {
      final transport = MultiplayerTransportClient(
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode(<String, dynamic>{'error': 'no capacity'}),
            503,
          );
        }),
      );
      addTearDown(transport.dispose);

      expect(
        () => transport.joinMatch(
          apiBaseUrl: 'https://example.com',
          displayName: 'PlayerA',
        ),
        throwsA(
          isA<MultiplayerHttpException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having((error) => error.message, 'message', 'no capacity'),
        ),
      );
    });

    test('fetchServerDebugLogs requests expected query parameters', () async {
      final transport = MultiplayerTransportClient(
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://example.com/debug/logs?limit=9&matchId=abc',
          );
          return http.Response(
            jsonEncode(<String, dynamic>{
              'items': <Map<String, dynamic>>[
                <String, dynamic>{'id': 1, 'event': 'state_sent'},
                <String, dynamic>{'id': 2, 'event': 'move_accepted'},
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(transport.dispose);

      final logs = await transport.fetchServerDebugLogs(
        apiBaseUrl: 'https://example.com',
        limit: 9,
        matchId: 'abc',
      );

      expect(logs, hasLength(2));
      expect(logs.first['event'], 'state_sent');
      expect(logs.last['event'], 'move_accepted');
    });
  });
}
