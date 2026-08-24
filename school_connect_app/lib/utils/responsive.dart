import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Screen-size categories used across the app so every screen adapts to
/// phones, tablets and desktop windows.
enum ScreenSize { mobile, tablet, desktop }

extension ResponsiveX on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1000;
  bool get isDesktop => screenWidth >= 1000;
  bool get isWide => screenWidth >= 600;

  ScreenSize get screenSizeCategory {
    if (isDesktop) return ScreenSize.desktop;
    if (isTablet) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  /// Comfortable reading/forms width for large screens.
  double get contentMaxWidth => isDesktop ? 1200 : 720;

  /// Horizontal padding that scales with the screen.
  EdgeInsets get screenPadding => EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : isTablet ? 24 : 20,
      );
}

/// Centers [child] inside a max-width container so content does not stretch
/// across the whole window on desktop. Optionally shows a subtle vertical
/// divider rail on very wide screens.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry padding;
  final Alignment alignment;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final width = maxWidth ?? context.contentMaxWidth;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A [GridView] delegate that switches the number of columns based on width.
class AdaptiveGridDelegate extends SliverGridDelegateWithFixedCrossAxisCount {
  AdaptiveGridDelegate({
    required double minItemWidth,
    double mainAxisSpacing = 16,
    double crossAxisSpacing = 16,
    double childAspectRatio = 1.0,
  })  : _minItemWidth = minItemWidth,
        super(
          crossAxisCount: 1,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          childAspectRatio: childAspectRatio,
        );

  final double _minItemWidth;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final usable = constraints.crossAxisExtent;
    final columns = (usable / _minItemWidth).floor().clamp(1, 6);
    return SliverGridRegularTileLayout(
      crossAxisCount: columns,
      mainAxisStride: _mainAxisStride(constraints, columns),
      crossAxisStride: _crossAxisStride(usable, columns),
      childCrossAxisExtent: _crossAxisExtent(usable, columns),
      childMainAxisExtent: _mainAxisExtent(constraints, columns),
      reverseCrossAxis: false,
    );
  }

  double _crossAxisExtent(double usable, int columns) {
    return (usable - (crossAxisSpacing * (columns - 1))) / columns;
  }

  double _crossAxisStride(double usable, int columns) {
    return _crossAxisExtent(usable, columns) + crossAxisSpacing;
  }

  double _mainAxisExtent(SliverConstraints constraints, int columns) {
    final cross = _crossAxisExtent(constraints.crossAxisExtent, columns);
    return cross / childAspectRatio;
  }

  double _mainAxisStride(SliverConstraints constraints, int columns) {
    return _mainAxisExtent(constraints, columns) + mainAxisSpacing;
  }
}
