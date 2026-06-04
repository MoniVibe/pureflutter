import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugLogExportButton extends StatelessWidget {
  const DebugLogExportButton({
    required this.logTextProvider,
    this.label = 'Copy Debug Log',
    this.emptyMessage = 'No game log is available yet.',
    this.copiedMessage = 'Debug log copied.',
    super.key,
  });

  final String Function() logTextProvider;
  final String label;
  final String emptyMessage;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        final logText = logTextProvider().trimRight();
        if (logText.isEmpty) {
          messenger?.showSnackBar(SnackBar(content: Text(emptyMessage)));
          return;
        }

        await Clipboard.setData(ClipboardData(text: '$logText\n'));
        messenger?.showSnackBar(SnackBar(content: Text(copiedMessage)));
      },
      icon: const Icon(Icons.copy_all_rounded, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}
