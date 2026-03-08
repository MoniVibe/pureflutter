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
    final colorScheme = Theme.of(context).colorScheme;
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: WidgetStatePropertyAll(
          BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.7)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.2);
          }
          return colorScheme.surface.withValues(alpha: 0.66);
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onSurface;
          }
          return colorScheme.onSurfaceVariant;
        }),
        padding: const WidgetStatePropertyAll(
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
