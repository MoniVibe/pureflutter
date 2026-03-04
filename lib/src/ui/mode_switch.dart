import 'package:flutter/material.dart';

/// Compact local/online toggle used by both clients.
class CompactModeSwitch extends StatelessWidget {
  const CompactModeSwitch({
    required this.onlineSelected,
    required this.onChanged,
    super.key,
  });

  final bool onlineSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
      segments: const <ButtonSegment<bool>>[
        ButtonSegment<bool>(
          value: false,
          label: Text('Local'),
          icon: Icon(Icons.smart_toy_outlined, size: 16),
        ),
        ButtonSegment<bool>(
          value: true,
          label: Text('Online'),
          icon: Icon(Icons.wifi, size: 16),
        ),
      ],
      selected: <bool>{onlineSelected},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
