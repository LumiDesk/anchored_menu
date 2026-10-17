import 'dart:async';

import 'package:flutter/material.dart';

import 'anchored_menu_entry.dart';
import 'anchored_menu_route.dart';

/// Attaches an anchored menu to a caller-provided trigger widget.
///
/// The menu follows the trigger, avoids screen edges, closes on an outside tap,
/// and renders each submenu as another card above the previous one.
class AnchoredMenuAnchor extends StatefulWidget {
  const AnchoredMenuAnchor({
    super.key,
    required this.entries,
    required this.builder,
    required this.semanticLabel,
    this.width,
    this.submenuWidth,
    this.keyPrefix = 'anchored',
  });

  /// Root menu entries.
  final List<AnchoredMenuEntry> entries;

  /// Builds the caller-owned trigger.
  final AnchoredMenuAnchorBuilder builder;

  /// Accessibility label for the menu surface.
  final String semanticLabel;

  /// Optional fixed root-menu width.
  final double? width;

  /// Optional default width for submenus without their own override.
  final double? submenuWidth;

  /// Prefix used by stable widget keys.
  final String keyPrefix;

  @override
  State<AnchoredMenuAnchor> createState() => _AnchoredMenuAnchorState();
}

class _AnchoredMenuAnchorState extends State<AnchoredMenuAnchor> {
  bool _menuOpen = false;

  Future<void> _openMenu() async {
    if (_menuOpen || widget.entries.isEmpty) {
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final origin = renderObject.localToGlobal(Offset.zero);
    final anchor = origin & renderObject.size;
    final textDirection = Directionality.of(context);
    setState(() => _menuOpen = true);

    final selected = await showGeneralDialog<AnchoredMenuItem>(
      context: context,
      barrierDismissible: false,
      barrierLabel: widget.semanticLabel,
      barrierColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.28)
          : Colors.black.withValues(alpha: 0.08),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) =>
          AnchoredMenuRoute(
            anchor: anchor,
            entries: widget.entries,
            width: widget.width,
            submenuWidth: widget.submenuWidth,
            semanticLabel: widget.semanticLabel,
            keyPrefix: widget.keyPrefix,
            textDirection: textDirection,
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = animation.drive(
          CurveTween(curve: Curves.easeInOutCubic),
        );
        final scaled = ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          alignment: textDirection == TextDirection.rtl
              ? Alignment.topLeft
              : Alignment.topRight,
          child: child,
        );
        return FadeTransition(opacity: curved, child: scaled);
      },
    );

    if (!mounted) {
      return;
    }
    setState(() => _menuOpen = false);
    selected?.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _openMenu, _menuOpen);
}

/// Header-friendly icon trigger for [AnchoredMenuAnchor].
class AnchoredMenuButton extends StatelessWidget {
  const AnchoredMenuButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.entries,
    this.width,
    this.submenuWidth,
    this.keyPrefix = 'anchored',
  });

  /// Trigger icon.
  final IconData icon;

  /// Tooltip and menu accessibility label.
  final String tooltip;

  /// Root menu entries.
  final List<AnchoredMenuEntry> entries;

  /// Optional fixed root-menu width.
  final double? width;

  /// Optional default width for submenus without their own override.
  final double? submenuWidth;

  /// Prefix used by stable widget keys.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return AnchoredMenuAnchor(
      entries: entries,
      semanticLabel: tooltip,
      width: width,
      submenuWidth: submenuWidth,
      keyPrefix: keyPrefix,
      builder: (context, openMenu, menuOpen) => IconButton(
        tooltip: tooltip,
        onPressed: openMenu,
        isSelected: menuOpen,
        icon: Icon(icon),
      ),
    );
  }
}

/// A controlled single-choice menu built on top of [AnchoredMenuAnchor].
///
/// This adapter is intentionally limited to short, static option lists.
/// Dynamic, searchable, or grouped choices should use dedicated pickers.
class AnchoredMenuChoice<T> extends StatelessWidget {
  const AnchoredMenuChoice({
    super.key,
    required this.values,
    required this.selected,
    required this.idOf,
    required this.labelOf,
    required this.onSelected,
    required this.builder,
    required this.semanticLabel,
    this.iconOf,
    this.subtitleOf,
    this.enabledOf,
    this.width,
    this.keyPrefix = 'anchored',
  });

  /// Static candidate values.
  final List<T> values;

  /// Current selected value.
  final T selected;

  /// Stable identifier for each value.
  final String Function(T value) idOf;

  /// Localized primary label for each value.
  final String Function(T value) labelOf;

  /// Called after the menu closes.
  final ValueChanged<T> onSelected;

  /// Builds the caller-owned trigger.
  final AnchoredMenuAnchorBuilder builder;

  /// Accessibility label for the menu surface.
  final String semanticLabel;

  /// Optional icon for each value.
  final IconData? Function(T value)? iconOf;

  /// Optional supporting text for each value.
  final String? Function(T value)? subtitleOf;

  /// Optional enabled-state callback.
  final bool Function(T value)? enabledOf;

  /// Optional fixed menu width.
  final double? width;

  /// Prefix used by stable widget keys.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return AnchoredMenuAnchor(
      entries: <AnchoredMenuEntry>[
        for (final value in values)
          AnchoredMenuItem(
            id: idOf(value),
            icon: iconOf?.call(value),
            title: labelOf(value),
            subtitle: subtitleOf?.call(value),
            selected: value == selected,
            enabled: enabledOf?.call(value) ?? true,
            onPressed: () => onSelected(value),
          ),
      ],
      semanticLabel: semanticLabel,
      width: width,
      keyPrefix: keyPrefix,
      builder: builder,
    );
  }
}
