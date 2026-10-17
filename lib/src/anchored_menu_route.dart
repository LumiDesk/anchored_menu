import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'anchored_menu_entry.dart';
import 'anchored_menu_theme.dart';

const double _menuPanelPadding = 6;
const double _menuDividerExtent = 9;

/// Internal route that renders the menu overlay.
///
/// This type lives in `src` and is intentionally not exported by the package
/// barrel.
class AnchoredMenuRoute extends StatefulWidget {
  const AnchoredMenuRoute({
    super.key,
    required this.anchor,
    required this.entries,
    required this.width,
    required this.submenuWidth,
    required this.semanticLabel,
    required this.keyPrefix,
    required this.textDirection,
  });

  final Rect anchor;
  final List<AnchoredMenuEntry> entries;
  final double? width;
  final double? submenuWidth;
  final String semanticLabel;
  final String keyPrefix;
  final TextDirection textDirection;

  @override
  State<AnchoredMenuRoute> createState() => _AnchoredMenuRouteState();
}

class _AnchoredMenuRouteState extends State<AnchoredMenuRoute>
    with SingleTickerProviderStateMixin {
  final List<AnchoredMenuItem> _path = <AnchoredMenuItem>[];
  final FocusNode _focusNode = FocusNode(debugLabel: 'Anchored menu');
  late final AnimationController _submenuController;
  int _highlightedIndex = 0;

  List<AnchoredMenuEntry> get _entries =>
      _path.isEmpty ? widget.entries : _path.last.children;

  List<AnchoredMenuItem> get _navigableEntries => _entries
      .whereType<AnchoredMenuItem>()
      .where((entry) => entry.enabled)
      .toList(growable: false);

  AnchoredMenuItem? get _highlightedEntry {
    final entries = _navigableEntries;
    if (entries.isEmpty) {
      return null;
    }
    final index = _highlightedIndex.clamp(0, entries.length - 1);
    return entries[index];
  }

  int _initialHighlight(List<AnchoredMenuEntry> entries) {
    final items = entries
        .whereType<AnchoredMenuItem>()
        .where((entry) => entry.enabled)
        .toList(growable: false);
    if (items.isEmpty) {
      return 0;
    }
    final selectedIndex = items.indexWhere((entry) => entry.selected);
    return selectedIndex >= 0 ? selectedIndex : 0;
  }

  double _panelOriginForPathIndex(
    int targetIndex, {
    required List<double> panelWidths,
  }) {
    var origin = 0.0;
    var entries = widget.entries;
    AnchoredMenuItem? parent;
    for (var index = 0; index <= targetIndex; index++) {
      final item = _path[index];
      origin += _menuEntryOffset(
        context,
        entries,
        item,
        parent: parent,
        textScaler: MediaQuery.textScalerOf(context),
        width: panelWidths[index],
      );
      parent = item;
      entries = item.children;
    }
    return origin;
  }

  @override
  void initState() {
    super.initState();
    _highlightedIndex = _initialHighlight(widget.entries);
    _submenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 260),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _submenuController.dispose();
    super.dispose();
  }

  void _select(AnchoredMenuItem item) {
    if (!item.enabled || _submenuController.isAnimating) {
      return;
    }
    if (item.hasSubmenu) {
      setState(() {
        _path.add(item);
        _highlightedIndex = _initialHighlight(item.children);
      });
      _submenuController.forward(from: 0);
      return;
    }
    Navigator.of(context).pop(item);
  }

  Future<void> _goBack() async {
    if (_path.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    if (_submenuController.isAnimating) {
      return;
    }
    await _submenuController.reverse(from: 1);
    if (!mounted) {
      return;
    }
    final previousEntries = _path.length > 1
        ? _path[_path.length - 2].children
        : widget.entries;
    setState(() {
      _path.removeLast();
      _highlightedIndex = _initialHighlight(previousEntries);
    });
    _submenuController.value = _path.isEmpty ? 0 : 1;
  }

  void _moveHighlight(int delta) {
    final entries = _navigableEntries;
    if (entries.isEmpty) {
      return;
    }
    setState(() {
      _highlightedIndex = (_highlightedIndex + delta) % entries.length;
      if (_highlightedIndex < 0) {
        _highlightedIndex += entries.length;
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      unawaited(_goBack());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }

    final isRtl = widget.textDirection == TextDirection.rtl;
    final forwardKey = isRtl
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowRight;
    final backKey = isRtl
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;
    if (key == forwardKey) {
      final highlighted = _highlightedEntry;
      if (highlighted != null && highlighted.hasSubmenu) {
        _select(highlighted);
      }
      return KeyEventResult.handled;
    }
    if (key == backKey) {
      if (_path.isNotEmpty) {
        unawaited(_goBack());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      final highlighted = _highlightedEntry;
      if (highlighted != null) {
        _select(highlighted);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.textDirection,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mediaSize = MediaQuery.sizeOf(context);
          final viewport = Size(
            constraints.hasBoundedWidth
                ? constraints.maxWidth
                : mediaSize.width,
            constraints.hasBoundedHeight
                ? constraints.maxHeight
                : mediaSize.height,
          );
          return _buildMenu(context, viewport);
        },
      ),
    );
  }

  Widget _buildMenu(BuildContext context, Size viewport) {
    const edgePadding = 12.0;
    const anchorGap = 6.0;
    final menuTheme = ResolvedAnchoredMenuTheme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final availableWidth = viewport.width - edgePadding * 2;

    double resolveWidth(
      double? requested,
      List<AnchoredMenuEntry> entries, {
      AnchoredMenuItem? parent,
    }) {
      final minimum = math.min(menuTheme.minWidth, availableWidth);
      final contentWidth = _menuContentWidth(context, entries, parent: parent);
      final desiredWidth = requested ?? contentWidth;
      return desiredWidth.clamp(minimum, availableWidth).toDouble();
    }

    final rootWidth = resolveWidth(widget.width, widget.entries);
    final spaceBelow = viewport.height - widget.anchor.bottom - edgePadding;
    final spaceAbove = widget.anchor.top - edgePadding;
    final openBelow = spaceBelow >= 180 || spaceBelow >= spaceAbove;
    final maxHeight = (openBelow ? spaceBelow : spaceAbove) - anchorGap;
    final activeParent = _path.isEmpty ? null : _path.last;
    final foregroundWidth = activeParent == null
        ? rootWidth
        : resolveWidth(
            activeParent.submenuWidth ?? widget.submenuWidth,
            _entries,
            parent: activeParent,
          );
    final widestWidth = math.max(rootWidth, foregroundWidth);
    final right = (viewport.width - widget.anchor.right).clamp(
      edgePadding,
      viewport.width - edgePadding - widestWidth,
    );
    final left = widget.anchor.left.clamp(
      edgePadding,
      viewport.width - edgePadding - widestWidth,
    );

    Widget buildRootMenu() {
      return _AnchoredMenuPanel(
        entries: widget.entries,
        width: rootWidth,
        maxHeight: maxHeight,
        onSelect: _select,
        onBack: () => unawaited(_goBack()),
        keyPrefix: widget.keyPrefix,
        highlightedId: _highlightedEntry?.id,
      );
    }

    Widget buildSubmenuTransition() {
      final parent = activeParent!;
      final panelWidths = <double>[rootWidth];
      for (var index = 0; index < _path.length - 1; index++) {
        final pathParent = _path[index];
        panelWidths.add(
          resolveWidth(
            pathParent.submenuWidth ?? widget.submenuWidth,
            pathParent.children,
            parent: pathParent,
          ),
        );
      }
      final ancestorLayers =
          <
            ({
              List<AnchoredMenuEntry> entries,
              AnchoredMenuItem? parent,
              double width,
              double origin,
              double maxHeight,
              double height,
            })
          >[];

      void addAncestorLayer({
        required List<AnchoredMenuEntry> entries,
        required AnchoredMenuItem? parent,
        required double width,
        required double origin,
      }) {
        final availableHeight = maxHeight - origin;
        final layerMaxHeight = availableHeight < 96 ? 96.0 : availableHeight;
        ancestorLayers.add((
          entries: entries,
          parent: parent,
          width: width,
          origin: origin,
          maxHeight: layerMaxHeight,
          height: _menuPanelExtent(
            context,
            entries,
            parent: parent,
            textScaler: MediaQuery.textScalerOf(context),
            width: width,
          ).clamp(0.0, layerMaxHeight),
        ));
      }

      addAncestorLayer(
        entries: widget.entries,
        parent: null,
        width: rootWidth,
        origin: 0,
      );
      for (var index = 0; index < _path.length - 1; index++) {
        final layerParent = _path[index];
        addAncestorLayer(
          entries: layerParent.children,
          parent: layerParent,
          width: panelWidths[index + 1],
          origin: _panelOriginForPathIndex(index, panelWidths: panelWidths),
        );
      }

      final backgroundWidth = ancestorLayers.last.width;
      final originY = _panelOriginForPathIndex(
        _path.length - 1,
        panelWidths: panelWidths,
      );
      final availableForegroundHeight = maxHeight - originY;
      final foregroundMaxHeight = availableForegroundHeight < 96
          ? 96.0
          : availableForegroundHeight;
      final fullForegroundHeight = _menuPanelExtent(
        context,
        _entries,
        parent: parent,
        textScaler: MediaQuery.textScalerOf(context),
        width: foregroundWidth,
      ).clamp(0.0, foregroundMaxHeight);
      final collapsedHeight =
          (_menuPanelPadding +
                  _menuEntryExtent(
                    context,
                    parent,
                    MediaQuery.textScalerOf(context),
                    width: foregroundWidth,
                    parent: parent,
                  ))
              .clamp(0.0, fullForegroundHeight);

      return AnimatedBuilder(
        animation: _submenuController,
        builder: (context, child) {
          final progress = Curves.easeInOutCubic.transform(
            _submenuController.value,
          );
          final reveal = const Interval(
            0.18,
            1,
            curve: Curves.easeOutCubic,
          ).transform(_submenuController.value);
          final animatedWidth =
              backgroundWidth + (foregroundWidth - backgroundWidth) * progress;
          final animatedHeight =
              collapsedHeight +
              (fullForegroundHeight - collapsedHeight) * progress;
          var stackWidth = animatedWidth;
          var stackHeight = originY + animatedHeight;
          for (final layer in ancestorLayers) {
            if (layer.width > stackWidth) {
              stackWidth = layer.width;
            }
            final layerBottom = layer.origin + layer.height;
            if (layerBottom > stackHeight) {
              stackHeight = layerBottom;
            }
          }
          final animatedRadius = BorderRadiusGeometry.lerp(
            menuTheme.itemBorderRadius,
            menuTheme.panelBorderRadius,
            progress,
          )!.resolve(Directionality.of(context));

          double scaleForDistance(int distance) =>
              (1 - 0.03 * distance).clamp(0.88, 1.0);
          double dimForDistance(int distance) {
            if (distance <= 0) {
              return 0;
            }
            return (0.62 + 0.18 * (distance - 1)).clamp(0.0, 1.0);
          }

          final panelAlignment = isRtl ? Alignment.topLeft : Alignment.topRight;

          return SizedBox(
            width: stackWidth,
            height: stackHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                for (var index = 0; index < ancestorLayers.length; index++)
                  Positioned(
                    top: ancestorLayers[index].origin,
                    left: isRtl ? 0 : null,
                    right: isRtl ? null : 0,
                    child: IgnorePointer(
                      child: Transform.scale(
                        key: ValueKey<String>(
                          '${widget.keyPrefix}_menu_layer_$index',
                        ),
                        scale:
                            scaleForDistance(
                              ancestorLayers.length - index - 1,
                            ) +
                            (scaleForDistance(ancestorLayers.length - index) -
                                    scaleForDistance(
                                      ancestorLayers.length - index - 1,
                                    )) *
                                progress,
                        alignment: panelAlignment,
                        child: _AnchoredMenuPanel(
                          entries: ancestorLayers[index].entries,
                          parent: ancestorLayers[index].parent,
                          width: ancestorLayers[index].width,
                          maxHeight: ancestorLayers[index].maxHeight,
                          onSelect: (_) {},
                          onBack: () {},
                          keyPrefix: widget.keyPrefix,
                          backgroundProgress:
                              dimForDistance(
                                ancestorLayers.length - index - 1,
                              ) +
                              (dimForDistance(ancestorLayers.length - index) -
                                      dimForDistance(
                                        ancestorLayers.length - index - 1,
                                      )) *
                                  progress,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: originY,
                  left: isRtl ? 0 : null,
                  right: isRtl ? null : 0,
                  child: ClipRRect(
                    borderRadius: animatedRadius,
                    child: SizedBox(
                      width: animatedWidth,
                      height: animatedHeight,
                      child: _AnchoredMenuPanel(
                        entries: _entries,
                        parent: parent,
                        width: animatedWidth,
                        maxHeight: foregroundMaxHeight,
                        onSelect: _select,
                        onBack: () => unawaited(_goBack()),
                        keyPrefix: widget.keyPrefix,
                        highlightedId: _highlightedEntry?.id,
                        revealProgress: reveal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    final menu = Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: activeParent == null ? buildRootMenu() : buildSubmenuTransition(),
    );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: PopScope(
        canPop: _path.isEmpty,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _path.isNotEmpty) {
            unawaited(_goBack());
          }
        },
        child: Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: isRtl ? left : null,
                  right: isRtl ? null : right,
                  top: openBelow ? widget.anchor.bottom + anchorGap : null,
                  bottom: openBelow
                      ? null
                      : viewport.height - widget.anchor.top + anchorGap,
                  child: GestureDetector(onTap: () {}, child: menu),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Text width remaining after the item's outer padding, icon column, and
/// trailing state indicator.
double _menuItemTextExtent(
  double width,
  AnchoredMenuItem item, {
  bool header = false,
}) {
  final leadingWidth = item.icon == null ? 0.0 : 28.0 + 10.0;
  final trailingWidth = header || item.hasSubmenu || item.selected ? 21.0 : 0.0;
  return math.max(0, width - 16 - 24 - leadingWidth - 8 - trailingWidth);
}

double _menuTextHeight(
  BuildContext context,
  String text,
  TextStyle style,
  double width,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: width);
  return painter.height;
}

/// Height occupied by a menu row, including wrapped text and row padding.
double _menuEntryExtent(
  BuildContext context,
  AnchoredMenuEntry entry,
  TextScaler textScaler, {
  required double width,
  AnchoredMenuItem? parent,
}) {
  if (entry is AnchoredMenuDivider) {
    return _menuDividerExtent;
  }
  final item = entry as AnchoredMenuItem;
  final theme = ResolvedAnchoredMenuTheme.of(context);
  final textWidth = _menuItemTextExtent(width, item, header: parent != null);
  final titleHeight = _menuTextHeight(
    context,
    item.title,
    theme.titleStyle,
    textWidth,
  );
  final subtitleHeight = item.subtitle == null
      ? 0.0
      : 2 +
            _menuTextHeight(
              context,
              item.subtitle!,
              theme.subtitleStyle,
              textWidth,
            );
  final contentHeight = titleHeight + subtitleHeight + 12;
  final minHeight = item.subtitle == null ? 44.0 : 52.0;
  return math.max(minHeight, contentHeight) + 6;
}

double _menuPanelExtent(
  BuildContext context,
  List<AnchoredMenuEntry> entries, {
  AnchoredMenuItem? parent,
  required TextScaler textScaler,
  required double width,
}) {
  var extent = _menuPanelPadding * 2;
  if (parent != null) {
    extent +=
        _menuEntryExtent(
          context,
          parent,
          textScaler,
          width: width,
          parent: parent,
        ) +
        _menuDividerExtent;
  }
  for (final entry in entries) {
    extent += _menuEntryExtent(
      context,
      entry,
      textScaler,
      width: width,
      parent: parent,
    );
  }
  return extent;
}

double _menuEntryOffset(
  BuildContext context,
  List<AnchoredMenuEntry> entries,
  AnchoredMenuItem target, {
  AnchoredMenuItem? parent,
  required TextScaler textScaler,
  required double width,
}) {
  var offset = parent == null
      ? 0.0
      : _menuEntryExtent(
              context,
              parent,
              textScaler,
              width: width,
              parent: parent,
            ) +
            _menuDividerExtent;
  for (final entry in entries) {
    if (entry is AnchoredMenuItem && entry.id == target.id) {
      return offset;
    }
    offset += _menuEntryExtent(
      context,
      entry,
      textScaler,
      width: width,
      parent: parent,
    );
  }
  return offset;
}

double _menuTextWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width;
}

double _menuItemWidth(
  BuildContext context,
  AnchoredMenuItem item, {
  bool header = false,
}) {
  final theme = ResolvedAnchoredMenuTheme.of(context);
  final textWidth = math.max(
    _menuTextWidth(context, item.title, theme.titleStyle),
    item.subtitle == null
        ? 0
        : _menuTextWidth(context, item.subtitle!, theme.subtitleStyle),
  );
  final leadingWidth = item.icon == null ? 0.0 : 28.0 + 10.0;
  final trailingWidth = header || item.hasSubmenu || item.selected ? 21.0 : 0.0;
  return 16 + 24 + leadingWidth + textWidth + 8 + trailingWidth;
}

double _menuContentWidth(
  BuildContext context,
  List<AnchoredMenuEntry> entries, {
  AnchoredMenuItem? parent,
}) {
  var width = parent == null
      ? 0.0
      : _menuItemWidth(context, parent, header: true);
  for (final entry in entries) {
    if (entry is AnchoredMenuItem) {
      width = math.max(width, _menuItemWidth(context, entry));
    }
  }
  return width;
}

class _AnchoredMenuVisibility extends InheritedWidget {
  const _AnchoredMenuVisibility({required this.progress, required super.child});

  final double progress;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_AnchoredMenuVisibility>()
          ?.progress ??
      1;

  @override
  bool updateShouldNotify(_AnchoredMenuVisibility oldWidget) =>
      oldWidget.progress != progress;
}

class _AnchoredMenuPanel extends StatelessWidget {
  const _AnchoredMenuPanel({
    required this.entries,
    this.parent,
    required this.width,
    required this.maxHeight,
    required this.onSelect,
    required this.onBack,
    required this.keyPrefix,
    this.highlightedId,
    this.backgroundProgress = 0,
    this.revealProgress = 1,
  });

  final List<AnchoredMenuEntry> entries;
  final AnchoredMenuItem? parent;
  final double width;
  final double maxHeight;
  final ValueChanged<AnchoredMenuItem> onSelect;
  final VoidCallback onBack;
  final String keyPrefix;
  final String? highlightedId;
  final double backgroundProgress;
  final double revealProgress;

  @override
  Widget build(BuildContext context) {
    final visibility = _AnchoredMenuVisibility.of(context);
    final menuTheme = ResolvedAnchoredMenuTheme.of(context);
    final surface = Color.lerp(
      menuTheme.surfaceColor,
      Colors.black,
      0.28 * backgroundProgress,
    )!;
    final optionEntries = <Widget>[
      for (final entry in entries)
        switch (entry) {
          AnchoredMenuItem() => _AnchoredMenuItemRow(
            key: ValueKey<String>('${keyPrefix}_menu_item_${entry.id}'),
            item: entry,
            reserveLeading: entry.icon != null,
            onTap: () => onSelect(entry),
            mutedProgress: backgroundProgress,
            highlighted: entry.id == highlightedId,
          ),
          AnchoredMenuDivider() => const _AnchoredMenuDividerRow(),
        },
    ];
    final panelEntries = <Widget>[
      if (parent != null) ...<Widget>[
        _AnchoredMenuItemRow(
          item: parent!,
          reserveLeading: parent!.icon != null,
          submenuHeader: true,
          onTap: onBack,
          mutedProgress: backgroundProgress,
        ),
        FadeTransition(
          opacity: AlwaysStoppedAnimation<double>(revealProgress),
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - revealProgress)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _AnchoredMenuDividerRow(),
                ...optionEntries,
              ],
            ),
          ),
        ),
      ] else
        ...optionEntries,
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: maxHeight.clamp(120.0, double.infinity),
      ),
      child: FadeTransition(
        opacity: AlwaysStoppedAnimation(visibility),
        child: Material(
          color: surface,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: menuTheme.panelBorderRadius,
            side: BorderSide(color: menuTheme.borderColor),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: _menuPanelPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: panelEntries,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnchoredMenuItemRow extends StatelessWidget {
  const _AnchoredMenuItemRow({
    super.key,
    required this.item,
    required this.reserveLeading,
    required this.onTap,
    this.submenuHeader = false,
    this.mutedProgress = 0,
    this.highlighted = false,
  });

  final AnchoredMenuItem item;
  final bool reserveLeading;
  final VoidCallback onTap;
  final bool submenuHeader;
  final double mutedProgress;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final material = Theme.of(context);
    final menuTheme = ResolvedAnchoredMenuTheme.of(context);
    final direction = Directionality.of(context);
    final borderRadius = menuTheme.itemBorderRadius.resolve(direction);
    final baseColor = item.foregroundColor ?? menuTheme.foregroundColor;
    final selectedColor = item.selected ? menuTheme.selectedColor : baseColor;
    final layerStrength = 1 - 0.58 * mutedProgress;
    final contentColor = selectedColor.withValues(
      alpha: (item.enabled ? 0.92 : 0.34) * layerStrength,
    );
    final subtitleColor = item.selected
        ? menuTheme.selectedColor.withValues(
            alpha: (item.enabled ? 0.78 : 0.30) * layerStrength,
          )
        : baseColor.withValues(
            alpha: (item.enabled ? 0.50 : 0.26) * layerStrength,
          );
    final highlightColor = menuTheme.selectedColor.withValues(
      alpha: material.brightness == Brightness.dark ? 0.16 : 0.09,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Semantics(
        button: true,
        enabled: item.enabled,
        selected: item.selected,
        child: Material(
          color: highlighted ? highlightColor : Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            hoverColor: menuTheme.foregroundColor.withValues(
              alpha: material.brightness == Brightness.dark ? 0.09 : 0.06,
            ),
            onTap: item.enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: item.subtitle == null ? 44 : 52,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: <Widget>[
                    if (reserveLeading) ...<Widget>[
                      SizedBox(
                        width: 28,
                        child: item.icon == null
                            ? null
                            : Icon(item.icon, size: 22, color: contentColor),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            softWrap: true,
                            overflow: TextOverflow.clip,
                            style: menuTheme.titleStyle.copyWith(
                              color: contentColor,
                            ),
                          ),
                          if (item.subtitle != null) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle!,
                              softWrap: true,
                              overflow: TextOverflow.clip,
                              style: menuTheme.subtitleStyle.copyWith(
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (submenuHeader)
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 21,
                        color: baseColor.withValues(
                          alpha: 0.50 * layerStrength,
                        ),
                      )
                    else if (item.hasSubmenu)
                      Icon(
                        direction == TextDirection.rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        size: 21,
                        color: baseColor.withValues(
                          alpha: (item.enabled ? 0.42 : 0.22) * layerStrength,
                        ),
                      )
                    else if (item.selected)
                      Icon(
                        Icons.check_rounded,
                        size: 21,
                        color: menuTheme.selectedColor.withValues(
                          alpha: layerStrength,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnchoredMenuDividerRow extends StatelessWidget {
  const _AnchoredMenuDividerRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Divider(height: 1),
    );
  }
}
