import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_connect_app/models/assignment_model.dart';
import 'package:school_connect_app/models/instructor_model.dart';
import 'package:school_connect_app/models/student_group_model.dart';
import 'package:school_connect_app/models/student_model.dart';
import 'package:school_connect_app/models/super_school_model.dart';
import 'package:school_connect_app/screens/admin/executive_reports.dart';
import 'package:school_connect_app/services/google_sheets_service.dart'
    show AdminDashboardData;

const _superSchools = [
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

AdminDashboardData _sampleData() {
  return AdminDashboardData(
    teachers: [
      InstructorModel(id: 't1', name: 'Ada Teacher', isEnabled: true),
      InstructorModel(id: 't2', name: 'Ben Teacher', isEnabled: false),
    ],
    students: [
      StudentModel(
        id: 's1',
        name: 'Aarav Student',
        gender: 'Male',
        program: 'science',
        programName: 'Science',
        studentGroup: 'g1',
        studentGroupName: 'Grade 12 - A',
      ),
      StudentModel(
        id: 's2',
        name: 'Meera Student',
        gender: 'Female',
        program: 'science',
        programName: 'Science',
        studentGroup: 'g1',
        studentGroupName: 'Grade 12 - A',
      ),
      StudentModel(
        id: 's3',
        name: 'Rohan Student',
        gender: 'Male',
        program: 'commerce',
        programName: 'Commerce',
        studentGroup: 'g2',
        studentGroupName: 'Grade 12 - B',
      ),
    ],
    classes: [
      StudentGroupModel(
        id: 'g1',
        name: 'Grade 12 - A',
        program: 'science',
        programName: 'Science',
        groupSize: 2,
      ),
      StudentGroupModel(
        id: 'g2',
        name: 'Grade 12 - B',
        program: 'commerce',
        programName: 'Commerce',
        groupSize: 1,
      ),
    ],
  );
}

final _sampleAssignments = [
  AssignmentModel(
    id: 'a1',
    title: 'Physics lab report',
    studentGroup: 'g1',
    studentGroupName: 'Grade 12 - A',
    totalStudents: 2,
    submittedCount: 1,
    gradedCount: 0,
  ),
];

Future<void> _tallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 3600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('super admin reports render network sections from school data',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SuperExecutiveReports(schools: _superSchools),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('School status'), findsOneWidget);
    expect(find.text('Setup checklist'), findsOneWidget);
    expect(find.text('Most complete schools'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Key insights'), findsOneWidget);
    expect(find.text('Alpha High'), findsWidgets);
    expect(
      find.text('1 school without an admin account.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Share report as CSV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('super admin school ranking opens a detail sheet', (tester) async {
    await _tallSurface(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SuperExecutiveReports(schools: _superSchools),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Beta Academy').first);
    await tester.pumpAndSettle();

    expect(find.text('Record completeness'), findsOneWidget);
    expect(find.text('Admin password set'), findsWidgets);
    expect(find.text('No password'), findsWidgets);
    expect(find.text('Setup score'), findsWidgets);
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
    await _tallSurface(tester);
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
    expect(find.text('Assessment pipeline'), findsOneWidget);
    expect(find.text('Setup health'), findsOneWidget);
    expect(find.text('Key insights'), findsOneWidget);
    expect(find.text('No data to chart yet.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('school reports render assessment analytics and can drill into a class',
      (tester) async {
    await _tallSurface(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SchoolExecutiveReports(
          data: _sampleData(),
          loading: false,
          error: null,
          onRefresh: () async {},
          assignments: _sampleAssignments,
          schoolName: 'Demo School',
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Assessment pipeline'), findsOneWidget);
    expect(find.text('50%'), findsWidgets);
    expect(find.text('Physics lab report'), findsOneWidget);

    // Tap the biggest class bar to open its roster.
    await tester.tap(find.text('Grade 12 - A').first);
    await tester.pumpAndSettle();

    expect(find.text('Roster'), findsOneWidget);
    expect(find.text('Aarav Student'), findsOneWidget);
    expect(find.text('Meera Student'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('program chips filter the school report', (tester) async {
    await _tallSurface(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SchoolExecutiveReports(
          data: _sampleData(),
          loading: false,
          error: null,
          onRefresh: () async {},
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Commerce').first);
    await tester.pumpAndSettle();

    // Only the commerce student remains in scope.
    expect(find.text('1'), findsWidgets);
    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();
    expect(find.text('1 in Commerce'), findsOneWidget);
    expect(find.text('Rohan Student'), findsOneWidget);
    expect(find.text('Aarav Student'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('school CSV export carries metrics and assignment rows', () {
    final csv = SchoolExecutiveReports.buildCsv(
      data: _sampleData(),
      assignments: _sampleAssignments,
      schoolName: 'Demo School',
    );

    expect(csv, contains('School Connect executive report'));
    expect(csv, contains('Demo School'));
    expect(csv, contains('All programs'));
    expect(csv, contains('Teachers,2'));
    expect(csv, contains('Students,3'));
    expect(csv, contains('Classes,2'));
    expect(csv, contains('Physics lab report'));
    expect(csv, contains('Submission rate (%)'));
    // 1 of 2 submissions → 50%.
    expect(csv, contains('Submission rate (%),50'));
  });

  test('school CSV export respects the program filter', () {
    final csv = SchoolExecutiveReports.buildCsv(
      data: _sampleData(),
      schoolName: 'Demo School',
      programKey: 'commerce',
      programLabel: 'Commerce',
    );

    expect(csv, contains('Commerce'));
    expect(csv, contains('Students,1'));
    expect(csv, isNot(contains('Physics lab report')));
  });

  test('network CSV export ranks schools by completeness', () {
    final csv = SuperExecutiveReports.buildCsv(_superSchools);

    expect(csv, contains('network executive report'));
    expect(csv, contains('Schools,2'));
    expect(csv, contains('Alpha High'));
    expect(csv, contains('Beta Academy'));
    // Alpha is fully complete; Beta has no admin/password.
    expect(csv, contains('Alpha High,alpha.local,8000,Active,100'));
    expect(csv, contains('Beta Academy,beta.local,8001,Inactive,0'));
  });

  Future<void> scrollReport(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      final list = find.byType(ListView);
      if (list.evaluate().isEmpty) return;
      await tester.drag(list.first, const Offset(0, -420));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull,
          reason: 'overflow while scrolling report (step $i)');
    }
  }

  testWidgets('school report fits a phone viewport without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SchoolExecutiveReports(
          data: _sampleData(),
          loading: false,
          error: null,
          onRefresh: () async {},
          assignments: _sampleAssignments,
          schoolName: 'Demo School',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await scrollReport(tester);
  });

  testWidgets('super admin report fits a phone viewport without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SuperExecutiveReports(schools: _superSchools),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
