import 'package:flutter/widgets.dart';

/// An entry displayed by [AnchoredMenuAnchor].
sealed class AnchoredMenuEntry {
  const AnchoredMenuEntry();
}

/// A selectable action or a parent that opens another menu card.
class AnchoredMenuItem extends AnchoredMenuEntry {
  const AnchoredMenuItem({
    required this.id,
    required this.title,
    this.icon,
    this.subtitle,
    this.selected = false,
    this.enabled = true,
    this.foregroundColor,
    this.onPressed,
    this.children = const <AnchoredMenuEntry>[],
    this.submenuWidth,
  }) : assert(id.length > 0, 'Menu item ids must not be empty.');

  /// Stable identifier used for animation state, keys, and tests.
  final String id;

  /// Primary, caller-localized label.
  final String title;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional supporting text, such as the current value.
  final String? subtitle;

  /// Whether this item is the selected value in a controlled choice menu.
  final bool selected;

  /// Whether the item can be activated.
  final bool enabled;

  /// Optional semantic color override for the item content.
  final Color? foregroundColor;

  /// Action invoked after the menu closes.
  final VoidCallback? onPressed;

  /// Entries displayed when this item opens a submenu.
  final List<AnchoredMenuEntry> children;

  /// Optional width override for this item's submenu.
  final double? submenuWidth;

  /// Whether activating this item opens a submenu.
  bool get hasSubmenu => children.isNotEmpty;
}

/// A visual separator between related menu actions.
class AnchoredMenuDivider extends AnchoredMenuEntry {
  const AnchoredMenuDivider();
}

/// Builds the caller-owned trigger for an anchored menu.
typedef AnchoredMenuAnchorBuilder = Widget Function(
  BuildContext context,
  VoidCallback openMenu,
  bool menuOpen,
);
