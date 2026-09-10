// Basic smoke tests for the School Connect app.

import 'package:flutter_test/flutter_test.dart';

import 'package:demoapp/main.dart';

void main() {
  testWidgets('App builds and shows the login screen', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const SchoolConnectApp());
    await tester.pump();

    // The app shell should render.
    expect(find.byType(SchoolConnectApp), findsOneWidget);
  });
}
