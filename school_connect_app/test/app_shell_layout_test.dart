import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_connect_app/widgets/kit/nav.dart';

const _items = [
  AppNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
  AppNavItem(icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: 'Classes'),
  AppNavItem(icon: Icons.auto_awesome_outlined, selectedIcon: Icons.auto_awesome_rounded, label: 'Ask AI'),
  AppNavItem(icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today_rounded, label: 'Calendar'),
  AppNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
];

const double _viewportW = 393;
const double _viewportH = 873;

/// Mounts the bar exactly the way the dashboards do: a `Scaffold` with
/// `extendBody` on a full-height phone viewport.
Future<Rect> _pumpBar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(_viewportW, _viewportH);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        extendBody: true,
        body: const SizedBox.expand(),
        bottomNavigationBar: AppBottomNav(
          index: 0,
          items: _items,
          aiIndex: 2,
          onChanged: (_) {},
        ),
      ),
    ),
  );

  return tester.getRect(find.byType(AppBottomNav));
}

void main() {
  // Regression: the AI slot used to be a bare `Center`, which expands to the
  // tallest constraint it is given. Inside the bar's Row that grew the whole
  // bar to the height of the screen, and because the Row centres its children
  // on the cross axis every tab was parked in the middle of the display —
  // the bar appeared to cover the entire screen.
  testWidgets('bottom bar keeps its natural height on a full-height page',
      (tester) async {
    final bar = await _pumpBar(tester);

    expect(bar.height, lessThan(150),
        reason: 'bar must not stretch to fill the page');
    expect(bar.height, greaterThan(60),
        reason: 'bar must still fit the orb and its label');
  });

  testWidgets('bottom bar is pinned to the bottom of the viewport',
      (tester) async {
    final bar = await _pumpBar(tester);

    expect(bar.bottom, closeTo(_viewportH, 1.0));
  });

  testWidgets('tabs sit inside the bar, not mid-screen', (tester) async {
    final bar = await _pumpBar(tester);

    // `find.text` rather than a semantics finder: semantics are off in widget
    // tests unless the test asks for them.
    final home = tester.getRect(find.text('Home'));

    expect(home.center.dy, closeTo(bar.center.dy, 12),
        reason: 'tabs should be vertically centred in the bar itself, so they '
            'land near the bottom of the screen rather than the middle');
    expect(home.top, greaterThan(_viewportH * 0.75),
        reason: 'the first tab should be in the bottom quarter of the screen');
  });

  testWidgets('bar height is unchanged by the busy/thinking state',
      (tester) async {
    tester.view.physicalSize = const Size(_viewportW, _viewportH);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final busy in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: AppBottomNav(
              index: 2,
              items: _items,
              aiIndex: 2,
              aiBusy: busy,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      final bar = tester.getRect(find.byType(AppBottomNav));
      expect(bar.height, lessThan(150), reason: 'busy=$busy');
      expect(bar.bottom, closeTo(_viewportH, 1.0), reason: 'busy=$busy');
    }
  });
}
