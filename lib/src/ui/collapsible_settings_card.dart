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
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  colorScheme.primary.withValues(alpha: 0.18),
                  colorScheme.secondary.withValues(alpha: 0.14),
                ],
              ),
            ),
            child: ListTile(
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
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  ...(trailing == null
                      ? const <Widget>[]
                      : <Widget>[trailing!, const SizedBox(width: 8)]),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: const Icon(Icons.expand_more_rounded),
                  ),
                ],
              ),
              onTap: onToggle,
            ),
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
