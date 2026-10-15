import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_connect_app/models/super_school_model.dart';
import 'package:school_connect_app/screens/admin/executive_reports.dart';
import 'package:school_connect_app/services/google_sheets_service.dart'
    show AdminDashboardData;

void main() {
  testWidgets('super admin reports render network sections from school data',
      (tester) async {
    const schools = [
      SuperSchoolModel(
        name: 'alpha',
        schoolName: 'Alpha High',
        site: 'alpha.local',
        port: 8000,
        status: 'Active',
        adminEmail: 'admin@alpha.test',
        hasPassword: true,
        motto: 'Learn',
        contactEmail: 'hello@alpha.test',
        contactNumber: '123',
        address: '1 Main St',
        logoUrl: 'https://alpha.test/logo.png',
      ),
      SuperSchoolModel(
        name: 'beta',
        schoolName: 'Beta Academy',
        site: 'beta.local',
        port: 8001,
        status: 'Inactive',
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SuperExecutiveReports(schools: schools),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('School status'), findsOneWidget);
    expect(find.text('Setup checklist'), findsOneWidget);
    expect(find.text('Most complete schools'), findsOneWidget);
    expect(find.text('Key insights'), findsOneWidget);
    expect(find.text('Alpha High'), findsWidgets);
    expect(
      find.text('1 school without an admin account.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('super admin reports explain an empty registry', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SuperExecutiveReports(schools: []),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('No schools registered yet. Register one to start reporting.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('school reports show an empty state before data loads',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SchoolExecutiveReports(
          data: null,
          loading: false,
          error: null,
          onRefresh: () async {},
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('No reports yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('school reports render every section for an empty school',
      (tester) async {
    // The report list is lazy, so give it a viewport tall enough to build
    // every section before asserting on them.
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SchoolExecutiveReports(
          data: AdminDashboardData(),
          loading: false,
          error: null,
          onRefresh: () async {},
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Students by gender'), findsOneWidget);
    expect(find.text('Biggest classes'), findsOneWidget);
    expect(find.text('Class size spread'), findsOneWidget);
    expect(find.text('Students by program'), findsOneWidget);
    expect(find.text('Setup health'), findsOneWidget);
    expect(find.text('Key insights'), findsOneWidget);
    expect(find.text('No data to chart yet.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
