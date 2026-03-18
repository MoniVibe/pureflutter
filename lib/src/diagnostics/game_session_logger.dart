import 'dart:convert';
import 'dart:io';

/// Writes structured per-session diagnostics for local and online game flows.
///
/// Output layout:
/// `debug/last_game/<game>/<mode>/sessions/<session-id>.jsonl`
/// `debug/last_game/<game>/<mode>/latest.jsonl`
/// `debug/last_game/<game>/<mode>/latest_summary.json`
class GameSessionLogger {
  GameSessionLogger({
    required this.applicationId,
    required this.gameId,
    required this.mode,
  });

  final String applicationId;
  final String gameId;
  final String mode;

  String? _sessionId;
  File? _sessionFile;
  File? _latestFile;
  File? _latestSummaryFile;

  void beginSession({
    required String sessionLabel,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final root = _resolveRootDirectory();
    final modeDir = Directory(
      _joinPath(root.path, <String>[
        'debug',
        'last_game',
        _sanitize(gameId),
        _sanitize(mode),
      ]),
    );
    final sessionsDir = Directory(
      _joinPath(modeDir.path, <String>['sessions']),
    );
    if (!sessionsDir.existsSync()) {
      sessionsDir.createSync(recursive: true);
    }

    final ts = DateTime.now().toUtc();
    final timestamp =
        '${ts.year.toString().padLeft(4, '0')}${ts.month.toString().padLeft(2, '0')}${ts.day.toString().padLeft(2, '0')}_'
        '${ts.hour.toString().padLeft(2, '0')}${ts.minute.toString().padLeft(2, '0')}${ts.second.toString().padLeft(2, '0')}';
    final pid = pidString;
    _sessionId = '$timestamp-$pid-${_sanitize(sessionLabel)}';
    _sessionFile = File(
      _joinPath(sessionsDir.path, <String>['$_sessionId.jsonl']),
    );
    _latestFile = File(_joinPath(modeDir.path, <String>['latest.jsonl']));
    _latestSummaryFile = File(
      _joinPath(modeDir.path, <String>['latest_summary.json']),
    );

    // Reset the rolling latest stream when a fresh session starts.
    if (_latestFile!.existsSync()) {
      _latestFile!.deleteSync();
    }
    _latestFile!.createSync(recursive: true);

    logEvent(
      'session_start',
      data: <String, Object?>{
        'sessionLabel': sessionLabel,
        'sessionId': _sessionId,
        ...context,
      },
    );
  }

  void logEvent(
    String event, {
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    final sessionFile = _sessionFile;
    final latestFile = _latestFile;
    if (sessionFile == null || latestFile == null || _sessionId == null) {
      return;
    }

    final payload = <String, Object?>{
      'ts': DateTime.now().toUtc().toIso8601String(),
      'app': applicationId,
      'game': gameId,
      'mode': mode,
      'sessionId': _sessionId,
      'event': event,
      'data': data,
    };
    final line = '${jsonEncode(payload)}\n';
    try {
      sessionFile.writeAsStringSync(line, mode: FileMode.append, flush: true);
      latestFile.writeAsStringSync(line, mode: FileMode.append, flush: true);
    } catch (_) {
      // Logging must never break gameplay; swallow IO failures.
    }
  }

  void closeSession({
    String reason = 'session_closed',
    Map<String, Object?> summary = const <String, Object?>{},
  }) {
    final latestSummaryFile = _latestSummaryFile;
    if (_sessionId == null || latestSummaryFile == null) {
      return;
    }
    logEvent(
      'session_end',
      data: <String, Object?>{'reason': reason, ...summary},
    );
    final summaryPayload = <String, Object?>{
      'ts': DateTime.now().toUtc().toIso8601String(),
      'app': applicationId,
      'game': gameId,
      'mode': mode,
      'sessionId': _sessionId,
      'reason': reason,
      'summary': summary,
    };
    try {
      latestSummaryFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(summaryPayload),
        flush: true,
      );
    } catch (_) {
      // Best-effort summary output.
    }
  }

  String get pidString {
    final raw = pid;
    return raw >= 0 ? raw.toString() : 'unknown';
  }

  Directory _resolveRootDirectory() {
    final override = Platform.environment['BULLETHOLE_LOG_ROOT'];
    if (override != null && override.trim().isNotEmpty) {
      return Directory(override.trim());
    }

    var candidate = Directory.current.absolute;
    for (var i = 0; i < 12; i++) {
      final pubspec = File(_joinPath(candidate.path, <String>['pubspec.yaml']));
      if (pubspec.existsSync()) {
        return candidate;
      }
      final parent = candidate.parent;
      if (parent.path == candidate.path) {
        break;
      }
      candidate = parent;
    }
    return Directory.current.absolute;
  }

  static String _sanitize(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'unknown';
    }
    return normalized.replaceAll(RegExp(r'[^a-z0-9._-]+'), '_');
  }

  static String _joinPath(String root, List<String> parts) {
    final separator = Platform.pathSeparator;
    final suffix = parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(separator);
    if (suffix.isEmpty) {
      return root;
    }
    if (root.endsWith(separator)) {
      return '$root$suffix';
    }
    return '$root$separator$suffix';
  }
}
