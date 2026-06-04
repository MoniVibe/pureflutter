import 'dart:convert';

import 'package:web/web.dart' as web;

const int _schemaVersion = 1;
const int _maxSessions = 40;
const int _maxLinesPerSession = 2000;

void startPersistentGameLogSession({
  required String applicationId,
  required String gameId,
  required String mode,
  required String sessionId,
  required String sessionLabel,
  required String runId,
  required String createdAtIso,
  required Map<String, Object?> context,
}) {
  if (sessionId.trim().isEmpty) {
    return;
  }

  final key = _storeKey(
    applicationId: applicationId,
    gameId: gameId,
    mode: mode,
  );
  final store = _readStore(key);
  final sessions = _readSessions(store)
    ..removeWhere((session) => session['sessionId'] == sessionId);
  sessions.add(<String, Object?>{
    'sessionId': sessionId,
    'sessionLabel': sessionLabel,
    'runId': runId,
    'createdAt': createdAtIso,
    'updatedAt': createdAtIso,
    'context': context,
    'eventCount': 0,
    'lines': <String>[],
  });

  store
    ..['latestSessionId'] = sessionId
    ..['sessions'] = _trimSessions(sessions);
  _writeStore(key, store);
}

void appendPersistentGameLogLine({
  required String applicationId,
  required String gameId,
  required String mode,
  required String sessionId,
  required String updatedAtIso,
  required String jsonLine,
}) {
  if (sessionId.trim().isEmpty || jsonLine.trim().isEmpty) {
    return;
  }

  final key = _storeKey(
    applicationId: applicationId,
    gameId: gameId,
    mode: mode,
  );
  final store = _readStore(key);
  final sessions = _readSessions(store);
  var session = sessions.cast<Map<String, dynamic>?>().firstWhere(
    (candidate) => candidate?['sessionId'] == sessionId,
    orElse: () => null,
  );

  if (session == null) {
    session = <String, dynamic>{
      'sessionId': sessionId,
      'sessionLabel': 'restored',
      'runId': 'unknown',
      'createdAt': updatedAtIso,
      'updatedAt': updatedAtIso,
      'context': <String, Object?>{},
      'eventCount': 0,
      'lines': <String>[],
    };
    sessions.add(session);
  }

  final lines = _readLines(session);
  lines.add(jsonLine);
  if (lines.length > _maxLinesPerSession) {
    lines.removeRange(0, lines.length - _maxLinesPerSession);
  }
  session
    ..['updatedAt'] = updatedAtIso
    ..['eventCount'] = lines.length
    ..['lines'] = lines;

  store
    ..['latestSessionId'] = sessionId
    ..['sessions'] = _trimSessions(sessions);
  _writeStore(key, store);
}

String? readLatestPersistentGameLogJsonl({
  required String applicationId,
  required String gameId,
  required String mode,
}) {
  final key = _storeKey(
    applicationId: applicationId,
    gameId: gameId,
    mode: mode,
  );
  final store = _readStore(key);
  final sessions = _readSessions(store);
  if (sessions.isEmpty) {
    return null;
  }

  final latestSessionId = store['latestSessionId']?.toString();
  final latest =
      sessions.cast<Map<String, dynamic>?>().firstWhere(
        (session) => session?['sessionId'] == latestSessionId,
        orElse: () => null,
      ) ??
      sessions.last;
  final lines = _readLines(latest);
  if (lines.isEmpty) {
    return null;
  }
  return '${lines.join('\n')}\n';
}

String _storeKey({
  required String applicationId,
  required String gameId,
  required String mode,
}) {
  return 'bullethole.session_logs.v$_schemaVersion.'
      '${_sanitize(applicationId)}.${_sanitize(gameId)}.${_sanitize(mode)}';
}

Map<String, dynamic> _readStore(String key) {
  try {
    final raw = web.window.localStorage.getItem(key);
    if (raw == null || raw.trim().isEmpty) {
      return _emptyStore();
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    // Corrupt browser storage should not affect gameplay.
  }
  return _emptyStore();
}

Map<String, dynamic> _emptyStore() {
  return <String, dynamic>{
    'schemaVersion': _schemaVersion,
    'latestSessionId': null,
    'sessions': <Map<String, dynamic>>[],
  };
}

List<Map<String, dynamic>> _readSessions(Map<String, dynamic> store) {
  final raw = store['sessions'];
  if (raw is! List) {
    return <Map<String, dynamic>>[];
  }
  return raw
      .whereType<Map>()
      .map((session) => Map<String, dynamic>.from(session))
      .toList(growable: true);
}

List<String> _readLines(Map<String, dynamic> session) {
  final raw = session['lines'];
  if (raw is! List) {
    return <String>[];
  }
  return raw
      .map((line) => line?.toString() ?? '')
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: true);
}

List<Map<String, dynamic>> _trimSessions(List<Map<String, dynamic>> sessions) {
  sessions.sort(
    (a, b) => (a['createdAt']?.toString() ?? '').compareTo(
      b['createdAt']?.toString() ?? '',
    ),
  );
  if (sessions.length <= _maxSessions) {
    return sessions;
  }
  return sessions.sublist(sessions.length - _maxSessions);
}

void _writeStore(String key, Map<String, dynamic> store) {
  var candidate = store;
  for (var attempt = 0; attempt < 3; attempt += 1) {
    try {
      web.window.localStorage.setItem(key, jsonEncode(candidate));
      return;
    } catch (_) {
      candidate = _compactForRetry(candidate);
    }
  }
}

Map<String, dynamic> _compactForRetry(Map<String, dynamic> store) {
  final sessions = _readSessions(store);
  final keep = sessions.length <= 4
      ? sessions
      : sessions.sublist(sessions.length - (sessions.length ~/ 2));
  for (final session in keep) {
    final lines = _readLines(session);
    if (lines.length > 500) {
      session['lines'] = lines.sublist(lines.length - 500);
      session['eventCount'] = 500;
    }
  }
  return <String, dynamic>{...store, 'sessions': keep};
}

String _sanitize(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'unknown';
  }
  return normalized.replaceAll(RegExp(r'[^a-z0-9._-]+'), '_');
}
