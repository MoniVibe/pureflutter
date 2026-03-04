import 'package:flutter/material.dart';

import 'cooldown_meter.dart';

/// Shared switch to keep time-bar orientation controls consistent across games.
class TimeBarOrientationSwitch extends StatelessWidget {
  const TimeBarOrientationSwitch({
    required this.orientation,
    required this.onChanged,
    this.enabled = true,
    this.title = 'Vertical Time Bars',
    this.verticalHint = 'Bars appear on left/right of the board',
    this.horizontalHint = 'Bars appear above/below the board',
    super.key,
  });

  final TimeBarOrientation orientation;
  final ValueChanged<TimeBarOrientation> onChanged;
  final bool enabled;
  final String title;
  final String verticalHint;
  final String horizontalHint;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title),
      subtitle: Text(
        orientation == TimeBarOrientation.vertical
            ? verticalHint
            : horizontalHint,
      ),
      value: orientation == TimeBarOrientation.vertical,
      onChanged: enabled
          ? (selected) {
              onChanged(
                selected
                    ? TimeBarOrientation.vertical
                    : TimeBarOrientation.horizontal,
              );
            }
          : null,
    );
  }
}
