import 'package:flutter/material.dart';

/// Delegate for a pinned table header in a [SliverPersistentHeader].
class _FixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FixedHeaderDelegate({
    required this.headerBuilder,
    required this.height,
  });

  final Widget Function(BuildContext context) headerBuilder;
  final double height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      child: headerBuilder(context),
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      oldDelegate is _FixedHeaderDelegate && oldDelegate.height != height;
}

/// A table with a fixed header row and scrollable body. Header stays visible when
/// scrolling vertically; header and body scroll together horizontally.
class FixedHeaderTable extends StatelessWidget {
  const FixedHeaderTable({
    super.key,
    required this.horizontalScrollController,
    required this.totalWidth,
    required this.headerHeight,
    required this.headerBuilder,
    required this.rowCount,
    required this.rowBuilder,
    this.verticalScrollController,
  });

  final ScrollController horizontalScrollController;
  final ScrollController? verticalScrollController;
  final double totalWidth;
  final double headerHeight;
  final Widget Function(BuildContext context) headerBuilder;
  final int rowCount;
  final Widget Function(BuildContext context, int index) rowBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        return Scrollbar(
          thumbVisibility: true,
          interactive: true,
          controller: horizontalScrollController,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: horizontalScrollController,
            child: SizedBox(
              width: totalWidth,
              height: maxHeight,
              child: Scrollbar(
                thumbVisibility: true,
                interactive: true,
                controller: verticalScrollController,
                child: CustomScrollView(
                  controller: verticalScrollController,
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _FixedHeaderDelegate(
                        headerBuilder: headerBuilder,
                        height: headerHeight,
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => rowBuilder(context, index),
                        childCount: rowCount,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
