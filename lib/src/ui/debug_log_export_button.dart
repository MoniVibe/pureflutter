import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugLogExportButton extends StatelessWidget {
  const DebugLogExportButton({
    required this.logTextProvider,
    this.label = 'Copy Debug Log',
    this.emptyMessage = 'No game log is available yet.',
    this.copiedMessage = 'Debug log copied.',
    this.iconOnly = false,
    super.key,
  });

  final String Function() logTextProvider;
  final String label;
  final String emptyMessage;
  final String copiedMessage;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return IconButton(
        tooltip: label,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: () => _copyLog(context),
        icon: const Icon(Icons.copy_all_rounded, size: 20),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _copyLog(context),
      icon: const Icon(Icons.copy_all_rounded, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }

  Future<void> _copyLog(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final logText = logTextProvider().trimRight();
    if (logText.isEmpty) {
      messenger?.showSnackBar(SnackBar(content: Text(emptyMessage)));
      return;
    }

    await Clipboard.setData(ClipboardData(text: '$logText\n'));
    messenger?.showSnackBar(SnackBar(content: Text(copiedMessage)));
  }
}
