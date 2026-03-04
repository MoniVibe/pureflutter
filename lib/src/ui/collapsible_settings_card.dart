import 'package:flutter/material.dart';

/// Generic collapsible card shell for game setup and matchmaking sections.
class CollapsibleSettingsCard extends StatelessWidget {
  const CollapsibleSettingsCard({
    required this.title,
    required this.isOpen,
    required this.onToggle,
    required this.child,
    this.leading,
    this.trailing,
    this.contentPadding = const EdgeInsets.fromLTRB(12, 0, 12, 12),
    super.key,
  });

  final String title;
  final bool isOpen;
  final VoidCallback onToggle;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Row(
              children: [
                ...(leading == null
                    ? const <Widget>[]
                    : <Widget>[leading!, const SizedBox(width: 8)]),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...(trailing == null ? const <Widget>[] : <Widget>[trailing!]),
                const SizedBox(width: 6),
                Icon(
                  isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                ),
              ],
            ),
            onTap: onToggle,
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(padding: contentPadding, child: child),
            crossFadeState: isOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}
