// ignore_for_file: avoid_print

import 'dart:io';

import 'package:bullethole_shared/bullethole_shared_runtime.dart';

void main(List<String> args) {
  final config = _Config.parse(args);
  final analyzer = BughuntAnalyzer(
    queueResolutionMaxTicks: config.queueResolutionMaxTicks,
    gateConfig: BughuntGateConfig(
      minSessions: config.minSessions,
      minCompletionRate: config.minCompletionRate,
      requireZeroCrashes: true,
      requireZeroInvariantFailures: true,
      requireZeroDesyncs: true,
      blockedFailureCodes: config.blockedFailureCodes,
    ),
  );
  final primary = analyzer.readJsonl(config.primaryLogPath);
  final secondary = config.secondaryLogPath == null
      ? const <SessionEvent>[]
      : analyzer.readJsonl(config.secondaryLogPath!);

  final result = analyzer.analyze(
    primary: primary,
    secondary: secondary,
    notes: config.notes,
  );
  analyzer.writeOutputs(
    outputDirectory: config.outputDir,
    result: result,
    reproductionCommand: config.reproductionCommand,
  );

  print(
    'Bughunt analyzer verdict: ${result.summary.verdict.name.toUpperCase()}',
  );
  print('Summary: ${_joinPath(config.outputDir, 'summary.json')}');
  print('Report: ${_joinPath(config.outputDir, 'report.md')}');

  final verdict = result.summary.verdict;
  final blockedAllowed =
      verdict == BughuntGateVerdict.blocked && config.blockedExitZero;
  if (verdict != BughuntGateVerdict.pass && !blockedAllowed) {
    exitCode = 2;
  }
}

class _Config {
  const _Config({
    required this.primaryLogPath,
    required this.secondaryLogPath,
    required this.outputDir,
    required this.queueResolutionMaxTicks,
    required this.minSessions,
    required this.minCompletionRate,
    required this.blockedFailureCodes,
    required this.blockedExitZero,
    required this.notes,
    required this.reproductionCommand,
  });

  final String primaryLogPath;
  final String? secondaryLogPath;
  final String outputDir;
  final int queueResolutionMaxTicks;
  final int? minSessions;
  final double minCompletionRate;
  final List<String> blockedFailureCodes;
  final bool blockedExitZero;
  final String? notes;
  final String? reproductionCommand;

  static _Config parse(List<String> args) {
    String? primary;
    String? secondary;
    var outputDir = 'artifacts/bughunt/analysis';
    var queueResolutionMaxTicks = 30;
    int? minSessions;
    var minCompletionRate = 1.0;
    var blockedFailureCodes = const <String>[];
    var blockedExitZero = false;
    String? notes;
    String? reproductionCommand;

    for (final arg in args) {
      if (arg.startsWith('--primary=')) {
        primary = arg.substring('--primary='.length).trim();
        continue;
      }
      if (arg.startsWith('--secondary=')) {
        secondary = arg.substring('--secondary='.length).trim();
        continue;
      }
      if (arg.startsWith('--output=')) {
        outputDir = arg.substring('--output='.length).trim();
        continue;
      }
      if (arg.startsWith('--queue-resolution-max-ticks=')) {
        queueResolutionMaxTicks = int.parse(
          arg.substring('--queue-resolution-max-ticks='.length),
        );
        continue;
      }
      if (arg.startsWith('--min-sessions=')) {
        minSessions = int.parse(arg.substring('--min-sessions='.length));
        continue;
      }
      if (arg.startsWith('--min-completion-rate=')) {
        minCompletionRate = double.parse(
          arg.substring('--min-completion-rate='.length),
        );
        continue;
      }
      if (arg.startsWith('--blocked-failure-codes=')) {
        final raw = arg.substring('--blocked-failure-codes='.length).trim();
        blockedFailureCodes = raw
            .split(',')
            .map((code) => code.trim())
            .where((code) => code.isNotEmpty)
            .toList(growable: false);
        continue;
      }
      if (arg == '--blocked-exit-zero') {
        blockedExitZero = true;
        continue;
      }
      if (arg.startsWith('--notes=')) {
        notes = arg.substring('--notes='.length).trim();
        continue;
      }
      if (arg.startsWith('--repro=')) {
        reproductionCommand = arg.substring('--repro='.length).trim();
        continue;
      }
      if (arg == '--help' || arg == '-h') {
        _printUsageAndExit();
      }
      throw ArgumentError('Unknown argument: $arg');
    }

    if (primary == null || primary.isEmpty) {
      throw ArgumentError('--primary is required');
    }
    if (queueResolutionMaxTicks <= 0) {
      throw ArgumentError('--queue-resolution-max-ticks must be > 0');
    }
    if (minSessions != null && minSessions <= 0) {
      throw ArgumentError('--min-sessions must be > 0 when provided');
    }
    if (minCompletionRate < 0 || minCompletionRate > 1) {
      throw ArgumentError('--min-completion-rate must be between 0 and 1');
    }

    return _Config(
      primaryLogPath: primary,
      secondaryLogPath: secondary,
      outputDir: outputDir,
      queueResolutionMaxTicks: queueResolutionMaxTicks,
      minSessions: minSessions,
      minCompletionRate: minCompletionRate,
      blockedFailureCodes: blockedFailureCodes,
      blockedExitZero: blockedExitZero,
      notes: notes,
      reproductionCommand: reproductionCommand,
    );
  }
}

void _printUsageAndExit() {
  print(
    'Usage: dart run bullethole_shared:bughunt_analyzer '
    '--primary=path/to/host.jsonl '
    '[--secondary=path/to/client.jsonl] '
    '[--output=artifacts/bughunt/analysis] '
    '[--queue-resolution-max-ticks=30] '
    '[--min-sessions=10] '
    '[--min-completion-rate=1.0] '
    '[--blocked-failure-codes=CODE1,CODE2] '
    '[--blocked-exit-zero] '
    '[--notes=text] '
    '[--repro="command"]',
  );
  exit(0);
}

String _joinPath(String root, String child) {
  if (root.endsWith(Platform.pathSeparator)) {
    return '$root$child';
  }
  return '$root${Platform.pathSeparator}$child';
}
