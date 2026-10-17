import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Visual styling for [AnchoredMenuAnchor] and its submenus.
///
/// Install this as a [ThemeExtension] on [ThemeData.extensions]. Every field is
/// optional; omitted values are resolved from the surrounding Material theme.
@immutable
class AnchoredMenuThemeData extends ThemeExtension<AnchoredMenuThemeData> {
  const AnchoredMenuThemeData({
    this.surfaceColor,
    this.borderColor,
    this.foregroundColor,
    this.selectedColor,
    this.panelBorderRadius,
    this.itemBorderRadius,
    this.titleStyle,
    this.subtitleStyle,
    this.minWidth,
  });

  /// Opaque menu panel color.
  final Color? surfaceColor;

  /// Optional panel border color.
  final Color? borderColor;

  /// Default color for item labels and icons.
  final Color? foregroundColor;

  /// Accent color for selected items and the selected checkmark.
  final Color? selectedColor;

  /// Radius of the menu cards.
  final BorderRadiusGeometry? panelBorderRadius;

  /// Radius of the item hover and focus surface.
  final BorderRadiusGeometry? itemBorderRadius;

  /// Primary item typography.
  final TextStyle? titleStyle;

  /// Supporting-text typography.
  final TextStyle? subtitleStyle;

  /// Smallest width the menu is allowed to shrink to.
  final double? minWidth;

  /// Returns the installed menu theme, or an empty override set.
  static AnchoredMenuThemeData of(BuildContext context) =>
      Theme.of(context).extension<AnchoredMenuThemeData>() ??
      const AnchoredMenuThemeData();

  @override
  AnchoredMenuThemeData copyWith({
    Color? surfaceColor,
    Color? borderColor,
    Color? foregroundColor,
    Color? selectedColor,
    BorderRadiusGeometry? panelBorderRadius,
    BorderRadiusGeometry? itemBorderRadius,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    double? minWidth,
  }) {
    return AnchoredMenuThemeData(
      surfaceColor: surfaceColor ?? this.surfaceColor,
      borderColor: borderColor ?? this.borderColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      selectedColor: selectedColor ?? this.selectedColor,
      panelBorderRadius: panelBorderRadius ?? this.panelBorderRadius,
      itemBorderRadius: itemBorderRadius ?? this.itemBorderRadius,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      minWidth: minWidth ?? this.minWidth,
    );
  }

  @override
  AnchoredMenuThemeData lerp(
    covariant ThemeExtension<AnchoredMenuThemeData>? other,
    double t,
  ) {
    if (other is! AnchoredMenuThemeData) {
      return this;
    }
    return AnchoredMenuThemeData(
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      foregroundColor: Color.lerp(foregroundColor, other.foregroundColor, t),
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t),
      panelBorderRadius: BorderRadiusGeometry.lerp(
        panelBorderRadius,
        other.panelBorderRadius,
        t,
      ),
      itemBorderRadius: BorderRadiusGeometry.lerp(
        itemBorderRadius,
        other.itemBorderRadius,
        t,
      ),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
      minWidth: ui.lerpDouble(minWidth, other.minWidth, t),
    );
  }
}

/// Fully resolved values used by the internal menu renderer.
class ResolvedAnchoredMenuTheme {
  const ResolvedAnchoredMenuTheme({
    required this.surfaceColor,
    required this.borderColor,
    required this.foregroundColor,
    required this.selectedColor,
    required this.panelBorderRadius,
    required this.itemBorderRadius,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.minWidth,
  });

  factory ResolvedAnchoredMenuTheme.of(BuildContext context) {
    final material = Theme.of(context);
    final scheme = material.colorScheme;
    final extension = AnchoredMenuThemeData.of(context);
    final titleStyle =
        extension.titleStyle ??
        material.textTheme.titleSmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ) ??
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
    final subtitleStyle =
        extension.subtitleStyle ??
        material.textTheme.labelMedium?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

    return ResolvedAnchoredMenuTheme(
      surfaceColor: extension.surfaceColor ?? scheme.surfaceContainerHigh,
      borderColor: extension.borderColor ?? scheme.outlineVariant,
      foregroundColor: extension.foregroundColor ?? scheme.onSurface,
      selectedColor: extension.selectedColor ?? scheme.primary,
      panelBorderRadius:
          extension.panelBorderRadius ?? BorderRadius.circular(24),
      itemBorderRadius: extension.itemBorderRadius ?? BorderRadius.circular(12),
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
      minWidth: extension.minWidth ?? 168,
    );
  }

  final Color surfaceColor;
  final Color borderColor;
  final Color foregroundColor;
  final Color selectedColor;
  final BorderRadiusGeometry panelBorderRadius;
  final BorderRadiusGeometry itemBorderRadius;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final double minWidth;
}
