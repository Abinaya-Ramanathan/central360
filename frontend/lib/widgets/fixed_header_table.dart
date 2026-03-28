import 'package:flutter/material.dart';

/// Delegate for a pinned header in the scrollable (right) section when not using [leadingWidth].
class _FixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FixedHeaderDelegate({
    required this.headerBuilder,
    required this.height,
    required this.headerColor,
  });

  final Widget Function(BuildContext context) headerBuilder;
  final double height;
  final Color headerColor;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: Material(
        color: headerColor,
        elevation: 0,
        child: headerBuilder(context),
      ),
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      oldDelegate is _FixedHeaderDelegate &&
      (oldDelegate.height != height || oldDelegate.headerColor != headerColor);
}

/// Table with a pinned top header and vertical body scroll.
///
/// **Horizontal scroll:** By default the whole table scrolls horizontally.
/// If [leadingWidth], [leadingHeaderBuilder], and [leadingRowBuilder] are set,
/// the first column stays fixed and only the remaining columns scroll horizontally
/// (two vertical lists are kept in sync).
class FixedHeaderTable extends StatefulWidget {
  const FixedHeaderTable({
    super.key,
    required this.horizontalScrollController,
    required this.totalWidth,
    required this.headerHeight,
    required this.headerBuilder,
    required this.rowCount,
    required this.rowBuilder,
    this.verticalScrollController,
    this.leadingWidth,
    this.leadingHeaderBuilder,
    this.leadingRowBuilder,
    this.rowExtent,
    this.leadingMaxLines = 3,
  });

  final ScrollController horizontalScrollController;
  final ScrollController? verticalScrollController;

  /// Width of the horizontally scrollable section (columns after the fixed leading column).
  /// When no leading column, this is the full content width.
  final double totalWidth;
  final double headerHeight;
  final Widget Function(BuildContext context) headerBuilder;
  final int rowCount;
  final Widget Function(BuildContext context, int index) rowBuilder;

  /// Optional fixed first column. All three must be non-null to enable split layout.
  final double? leadingWidth;
  final Widget Function(BuildContext context)? leadingHeaderBuilder;
  final Widget Function(BuildContext context, int index)? leadingRowBuilder;

  /// Row height when using a fixed leading column (both sides must match). Default 96 when omitted.
  final double? rowExtent;

  /// Max lines for text in the fixed leading column (wrap + ellipsis). Default 3.
  final int leadingMaxLines;

  @override
  State<FixedHeaderTable> createState() => _FixedHeaderTableState();
}

class _FixedHeaderTableState extends State<FixedHeaderTable> {
  late final ScrollController _leftVertical;
  late final ScrollController _rightVertical;
  bool _syncing = false;

  bool get _useLeading =>
      widget.leadingWidth != null &&
      widget.leadingWidth! > 0 &&
      widget.leadingHeaderBuilder != null &&
      widget.leadingRowBuilder != null;

  @override
  void initState() {
    super.initState();
    _leftVertical = ScrollController();
    _rightVertical = ScrollController();
    if (_useLeading) {
      _leftVertical.addListener(() => _syncFrom(_leftVertical, _rightVertical));
      _rightVertical.addListener(() => _syncFrom(_rightVertical, _leftVertical));
    }
  }

  void _syncFrom(ScrollController source, ScrollController target) {
    if (_syncing || !source.hasClients || !target.hasClients) return;
    if ((source.offset - target.offset).abs() < 0.5) return;
    _syncing = true;
    target.jumpTo(source.offset);
    _syncing = false;
  }

  @override
  void dispose() {
    _leftVertical.dispose();
    _rightVertical.dispose();
    super.dispose();
  }

  /// Avoid [BoxConstraints] with infinite height (breaks [Column]/[Expanded] inside [Row]).
  static double _boundedTableHeight(BuildContext context, BoxConstraints constraints) {
    final screenH = MediaQuery.sizeOf(context).height;
    if (constraints.hasBoundedHeight && constraints.maxHeight.isFinite && constraints.maxHeight > 0) {
      return constraints.maxHeight.clamp(120.0, screenH);
    }
    // Some parents only set a minimum height.
    if (constraints.minHeight.isFinite && constraints.minHeight > 0) {
      return constraints.minHeight.clamp(120.0, screenH);
    }
    // Unbounded max (e.g. shrink-wrap column) — use a safe fraction of viewport.
    return (screenH * 0.5).clamp(240.0, screenH);
  }

  static Color _headerColor(ColorScheme scheme) =>
      Color.alphaBlend(scheme.primary.withValues(alpha: 0.08), scheme.surfaceContainerHighest);

  static Color _leadingColumnTint(ColorScheme scheme) =>
      Color.alphaBlend(scheme.primary.withValues(alpha: 0.04), scheme.surface);

  static Color _rowBackground(ColorScheme scheme, int index, {required bool isLeading}) {
    final base = isLeading ? _leadingColumnTint(scheme) : scheme.surface;
    if (index.isEven) return base;
    return Color.alphaBlend(scheme.primary.withValues(alpha: 0.03), base);
  }

  static Widget _wrapLeadingCell(BuildContext context, Widget child, {int maxLines = 2}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.25,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ) ??
            const TextStyle(height: 1.25, fontWeight: FontWeight.w600),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        child: child,
      ),
    );
  }

  static Widget _wrapScrollRow(BuildContext context, int index, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: _rowBackground(scheme, index, isLeading: false),
      child: child,
    );
  }

  Widget _wrapLeadingRow(BuildContext context, int index, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: _rowBackground(scheme, index, isLeading: true),
      child: _wrapLeadingCell(context, child, maxLines: widget.leadingMaxLines),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useLeading) {
      return _buildWithLeadingColumn(context);
    }
    return _buildClassic(context);
  }

  Widget _buildWithLeadingColumn(BuildContext context) {
    final rowH = widget.rowExtent ?? 96.0;
    final scheme = Theme.of(context).colorScheme;
    final headerBg = _headerColor(scheme);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableHeight = _boundedTableHeight(context, constraints);

        return SizedBox(
          height: tableHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: widget.leadingWidth!,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: widget.headerHeight,
                          child: Material(
                            color: headerBg,
                            elevation: 0,
                            child: _wrapLeadingCell(
                              context,
                              DefaultTextStyle.merge(
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                    ),
                                child: widget.leadingHeaderBuilder!(context),
                              ),
                              maxLines: 2,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Scrollbar(
                            controller: _leftVertical,
                            thumbVisibility: true,
                            interactive: true,
                            child: ListView.builder(
                              controller: _leftVertical,
                              physics: const ClampingScrollPhysics(),
                              itemCount: widget.rowCount,
                              itemExtent: rowH,
                              itemBuilder: (context, index) => _wrapLeadingRow(
                                context,
                                index,
                                widget.leadingRowBuilder!(context, index),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: scheme.outlineVariant.withValues(alpha: 0.7)),
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      interactive: true,
                      controller: widget.horizontalScrollController,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: widget.horizontalScrollController,
                        child: SizedBox(
                          width: widget.totalWidth,
                          height: tableHeight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: widget.headerHeight,
                                child: Material(
                                  color: headerBg,
                                  elevation: 0,
                                  child: DefaultTextStyle.merge(
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: scheme.onSurface,
                                        ),
                                    child: widget.headerBuilder(context),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Scrollbar(
                                  controller: _rightVertical,
                                  thumbVisibility: true,
                                  interactive: true,
                                  child: ListView.builder(
                                    controller: _rightVertical,
                                    physics: const ClampingScrollPhysics(),
                                    itemCount: widget.rowCount,
                                    itemExtent: rowH,
                                    itemBuilder: (context, index) => _wrapScrollRow(
                                      context,
                                      index,
                                      widget.rowBuilder(context, index),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClassic(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headerBg = _headerColor(scheme);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableHeight = _boundedTableHeight(context, constraints);

        return SizedBox(
          height: tableHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Scrollbar(
                thumbVisibility: true,
                interactive: true,
                controller: widget.horizontalScrollController,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: widget.horizontalScrollController,
                  child: SizedBox(
                    width: widget.totalWidth,
                    height: tableHeight,
                    child: Scrollbar(
                      thumbVisibility: true,
                      interactive: true,
                      controller: widget.verticalScrollController,
                      child: CustomScrollView(
                        physics: const ClampingScrollPhysics(),
                        controller: widget.verticalScrollController,
                        slivers: [
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _FixedHeaderDelegate(
                              headerBuilder: widget.headerBuilder,
                              height: widget.headerHeight,
                              headerColor: headerBg,
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _wrapScrollRow(
                                context,
                                index,
                                widget.rowBuilder(context, index),
                              ),
                              childCount: widget.rowCount,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
