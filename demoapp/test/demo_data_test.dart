import 'package:flutter_test/flutter_test.dart';
import 'package:demoapp/services/demo_data_service.dart';
import 'package:demoapp/models/user_model.dart';

void main() {
  final service = DemoDataService();

  group('Demo logins', () {
    test('demo teacher logs in with the instructor role', () {
      final user = service.login('teacher@school.com', 'teacher123');
      expect(user, isNotNull);
      expect(user!.role, UserRole.instructor);
      expect(user.id, 'INS-001');
    });

    test('demo student logs in with the student role', () {
      final user = service.login('student@school.com', 'student123');
      expect(user, isNotNull);
      expect(user!.role, UserRole.student);
      expect(user.id, 'STU-001');
    });

    test('wrong password is rejected', () {
      expect(service.login('student@school.com', 'nope'), isNull);
    });
  });

  group('Teacher demo data', () {
    test('demo teacher has classes', () {
      final classes = service.getMyClasses('INS-001');
      expect(classes, isNotEmpty);
    });

    test('demo teacher has assignments with submissions', () {
      final assignments = service.getMyTeacherAssignments('INS-001');
      expect(assignments, isNotEmpty);
      final anySubmitted =
          assignments.any((a) => a.submittedCount > 0 && a.totalStudents > 0);
      expect(anySubmitted, isTrue);
    });

    test('class roster resolves real student names', () {
      final students = service.getClassStudents('GRP-001');
      expect(students, isNotEmpty);
      for (final s in students) {
        expect(s.name, isNot(contains('Student Name')));
      }
    });

    test('submissions resolve real student names', () {
      final assignments = service.getMyTeacherAssignments('INS-001');
      expect(assignments, isNotEmpty);
      final subs = service.getAssignmentSubmissions(assignments.first.id);
      if (subs.isNotEmpty) {
        expect(subs.first.studentName, isNot(contains('Student Name')));
      }
    });
  });

  group('Student demo data', () {
    test('demo student has assignments with varied statuses', () {
      final assignments = service.getMyAssignments('GRP-001', studentId: 'STU-001');
      expect(assignments, isNotEmpty);
      final hasGraded = assignments.any((a) => a.submissionStatus == 'Graded');
      final hasPending =
          assignments.any((a) => a.submissionStatus == null || a.submissionStatus == 'Returned');
      expect(hasGraded, isTrue, reason: 'expected at least one graded assignment');
      expect(hasPending, isTrue, reason: 'expected at least one pending assignment');
    });

    test('demo student has attendance records and a summary', () {
      final records = service.getStudentAttendance('STU-001');
      expect(records.length, greaterThan(10));
      final summary = service.getAttendanceSummary('STU-001');
      expect(summary['overall'], greaterThan(0));
      expect(summary.keys.length, greaterThan(1), reason: 'expected course-wise entries too');
    });

    test('student detail includes attendance and grades', () {
      final detail = service.getStudentDetails('STU-001');
      expect(detail.name, 'Alex Smith');
      expect(detail.overallAttendance, greaterThan(0));
      expect(detail.courseWiseAttendance, isNotEmpty);
      expect(detail.grades, isNotEmpty);
      for (final g in detail.grades) {
        expect(g.title, isNot(contains('Student Name')));
      }
    });
  });

  group('Demo mutations', () {
    test('teacher can create an assignment', () {
      final created = service.createAssignment(
        title: 'Test Quiz',
        course: 'Mathematics',
        studentGroup: 'GRP-001',
        dueDate: DateTime.now().add(const Duration(days: 7)),
        description: 'Demo test assignment',
        instructorId: 'INS-001',
      );
      expect(created.id, isNotEmpty);
      expect(service.getMyTeacherAssignments('INS-001'), contains(created));
    });

    test('student can submit an assignment', () {
      final pending = service
          .getMyAssignments('GRP-001', studentId: 'STU-001')
          .where((a) => !a.submitted || a.submissionStatus == 'Returned')
          .toList();
      expect(pending, isNotEmpty);
      final target = pending.first;
      final ok = service.submitAssignment(
        assignment: target.id,
        filePath: '/tmp/demo_submission.pdf',
        studentId: 'STU-001',
      );
      expect(ok, isTrue);
      final updated = service
          .getMyAssignments('GRP-001', studentId: 'STU-001')
          .firstWhere((a) => a.id == target.id);
      expect(updated.submitted, isTrue);
    });

    test('signup registers a user who can then log in', () {
      final user = service.signupStudent(
        fullName: 'Test New Student',
        email: 'new.student@school.com',
        password: 'pass123',
        age: 14,
        gender: 'Female',
        city: 'Springfield',
        state: 'Illinois',
        country: 'USA',
        school: 'SCH-001',
        studentGroup: 'GRP-001',
      );
      expect(user, isNotNull);
      expect(user!.role, UserRole.student);

      final loggedIn = service.login('new.student@school.com', 'pass123');
      expect(loggedIn, isNotNull);
      expect(loggedIn!.fullName, 'Test New Student');

      // Duplicate email is rejected.
      final dup = service.signupStudent(
        fullName: 'Other',
        email: 'new.student@school.com',
        password: 'pass123',
        school: 'SCH-001',
      );
      expect(dup, isNull);
    });
  });
}
