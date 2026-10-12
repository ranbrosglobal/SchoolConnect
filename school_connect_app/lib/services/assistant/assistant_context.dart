import '../../models/assignment_model.dart';
import '../../models/course_schedule_model.dart';
import '../../models/timetable_model.dart';
import '../../models/user_model.dart';
import '../../services/google_sheets_service.dart' show AttendanceSummary;

/// Everything the assistant is allowed to reason over.
///
/// The engine never touches providers or the network itself: it receives this
/// immutable snapshot and answers from it. That keeps the reasoning pure and
/// testable, and means the assistant can never leak another user's data.
class AssistantContext {
  final String userName;
  final UserRole role;
  final String? schoolName;
  final List<String> classNames;

  /// Student-only.
  final AttendanceSummary? attendance;

  /// Student assignments OR the teacher's created assignments.
  final List<AssignmentModel> assignments;

  /// Student-only week grid.
  final TimetableModel? timetable;

  /// Teacher-only class list.
  final List<CourseScheduleModel> classes;

  final DateTime now;
  final bool isFresh;

  const AssistantContext({
    required this.userName,
    required this.role,
    this.schoolName,
    this.classNames = const [],
    this.attendance,
    this.assignments = const [],
    this.timetable,
    this.classes = const [],
    required this.now,
    this.isFresh = true,
  });

  factory AssistantContext.empty({DateTime? now}) => AssistantContext(
        userName: 'there',
        role: UserRole.student,
        now: now ?? DateTime.now(),
        isFresh: false,
      );

  String get firstName {
    final parts = userName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'there' : parts.first;
  }

  bool get isTeacher =>
      role == UserRole.instructor || role == UserRole.admin || role == UserRole.schoolAdmin;

  bool get hasData => attendance != null || assignments.isNotEmpty || classes.isNotEmpty;

  // ─── Attendance analytics ────────────────────────────────────────────────

  double get overallAttendance => attendance?.overallPercentage ?? 0;

  Map<String, double> get courseAttendance =>
      attendance?.courseWisePercentage ?? const {};

  /// Weakest subject first — the assistant leads with what needs work.
  List<MapEntry<String, double>> get weakestCourses {
    final entries = courseAttendance.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  /// Courses below the given threshold.
  List<MapEntry<String, double>> coursesBelow(double threshold) =>
      weakestCourses.where((e) => e.value < threshold).toList();

  /// Daily attendance for the trailing [days] entries of the monthly feed.
  List<({String label, String status, DateTime date})> recentDays({int days = 14}) {
    final monthly = attendance?.monthlyAttendance ?? const [];
    if (monthly.isEmpty) return const [];
    final sorted = [...monthly]..sort((a, b) => a.date.compareTo(b.date));
    final tail = sorted.length > days ? sorted.sublist(sorted.length - days) : sorted;
    return tail
        .map((m) => (label: '${m.date.day}', status: m.status, date: m.date))
        .toList();
  }

  /// Present/absent counts over the monthly feed.
  ({int present, int absent, int leave}) get attendanceCounts {
    var present = 0, absent = 0, leave = 0;
    for (final m in attendance?.monthlyAttendance ?? const []) {
      final s = m.status.toLowerCase();
      if (s.contains('present')) {
        present++;
      } else if (s.contains('absent')) {
        absent++;
      } else {
        leave++;
      }
    }
    return (present: present, absent: absent, leave: leave);
  }

  /// Attendance percentage per week over the monthly feed (oldest → newest),
  /// used for the trend chart.
  List<double> get attendanceTrend {
    final monthly = attendance?.monthlyAttendance ?? const [];
    if (monthly.length < 5) return const [];
    final sorted = [...monthly]..sort((a, b) => a.date.compareTo(b.date));
    final buckets = <List<DateTime>>[];
    for (int i = 0; i < sorted.length; i += 5) {
      buckets.add(sorted
          .sublist(i, i + 5 > sorted.length ? sorted.length : i + 5)
          .map((m) => m.date)
          .toList());
    }
    final result = <double>[];
    for (final bucket in buckets) {
      final days = sorted.where((m) => bucket.contains(m.date)).toList();
      if (days.isEmpty) continue;
      final present = days.where((d) => d.status.toLowerCase().contains('present')).length;
      result.add(present / days.length * 100);
    }
    return result;
  }

  // ─── Assignment analytics ────────────────────────────────────────────────

  List<AssignmentModel> get upcomingAssignments {
    final list = assignments
        .where((a) => a.dueDate != null && !a.isOverdue)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return list;
  }

  /// Not yet submitted and not yet past the deadline.
  List<AssignmentModel> get todoAssignments =>
      upcomingAssignments.where((a) => !a.isSubmitted).toList();

  List<AssignmentModel> get overdueAssignments =>
      assignments.where((a) => a.isOverdue && !a.isSubmitted).toList();

  /// Submitted but not yet graded.
  List<AssignmentModel> get awaitingGrade =>
      assignments.where((a) => a.isSubmitted && !a.isGraded).toList();

  List<AssignmentModel> get gradedAssignments =>
      assignments.where((a) => a.isGraded).toList();

  List<AssignmentModel> dueWithin(int days) {
    final limit = now.add(Duration(days: days));
    return assignments
        .where((a) =>
            a.dueDate != null &&
            !a.isSubmitted &&
            a.dueDate!.isAfter(now.subtract(const Duration(days: 1))) &&
            a.dueDate!.isBefore(limit))
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  double get averageGrade {
    final graded = gradedAssignments;
    if (graded.isEmpty) return 0;
    final total = graded.fold<double>(0, (sum, a) => sum + (a.grade ?? 0));
    return total / graded.length;
  }

  /// Highest and lowest graded work — used for the performance story.
  AssignmentModel? get bestAssignment {
    final graded = gradedAssignments;
    if (graded.isEmpty) return null;
    return graded.reduce((a, b) => (a.grade ?? 0) >= (b.grade ?? 0) ? a : b);
  }

  AssignmentModel? get worstAssignment {
    final graded = gradedAssignments;
    if (graded.isEmpty) return null;
    return graded.reduce((a, b) => (a.grade ?? 0) <= (b.grade ?? 0) ? a : b);
  }

  /// Grade in 0..100 per course (average across graded work).
  Map<String, double> get gradeByCourse {
    final map = <String, List<double>>{};
    for (final a in gradedAssignments) {
      final key = a.courseName ?? a.course ?? 'General';
      map.putIfAbsent(key, () => []).add(a.grade ?? 0);
    }
    return map.map((k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length));
  }

  /// A coarse academic standing derived from grades + attendance. Deliberately
  /// explainable so the assistant can say *why* it said it.
  ({String label, String why, AssistantToneFor tone}) get standing {
    final grade = averageGrade;
    final att = overallAttendance;
    final score = (grade * 0.65) + (att * 0.35);
    if (gradedAssignments.isEmpty) {
      return (
        label: 'Getting started',
        why: 'Nothing has been graded yet — this will sharpen up as grades come in.',
        tone: AssistantToneFor.neutral,
      );
    }
    if (score >= 85) {
      return (
        label: 'Excellent',
        why: 'Average grade ${grade.toStringAsFixed(1)} with ${att.toStringAsFixed(0)}% attendance.',
        tone: AssistantToneFor.success,
      );
    }
    if (score >= 72) {
      return (
        label: 'On track',
        why: 'Average grade ${grade.toStringAsFixed(1)} with ${att.toStringAsFixed(0)}% attendance.',
        tone: AssistantToneFor.info,
      );
    }
    if (score >= 58) {
      return (
        label: 'Needs focus',
        why: 'Average grade ${grade.toStringAsFixed(1)} — a couple of subjects are pulling it down.',
        tone: AssistantToneFor.warning,
      );
    }
    return (
      label: 'Needs support',
      why: 'Average grade ${grade.toStringAsFixed(1)} with ${att.toStringAsFixed(0)}% attendance.',
      tone: AssistantToneFor.danger,
    );
  }

  // ─── Timetable / class analytics ─────────────────────────────────────────

  List<ScheduleRow> get classesToday {
    final rows = timetable?.timetable ?? const [];
    return rows
        .where((r) =>
            r.date.year == now.year &&
            r.date.month == now.month &&
            r.date.day == now.day)
        .toList()
      ..sort((a, b) => (a.fromTime ?? '').compareTo(b.fromTime ?? ''));
  }

  List<ScheduleRow> get classesTomorrow {
    final t = now.add(const Duration(days: 1));
    final rows = timetable?.timetable ?? const [];
    return rows
        .where((r) => r.date.year == t.year && r.date.month == t.month && r.date.day == t.day)
        .toList()
      ..sort((a, b) => (a.fromTime ?? '').compareTo(b.fromTime ?? ''));
  }

  /// The next class starting after [now] today, if any.
  ScheduleRow? get nextClass {
    for (final r in classesToday) {
      final start = _timeToday(r.fromTime);
      if (start != null && start.isAfter(now)) return r;
    }
    return null;
  }

  ScheduleRow? get currentClass {
    for (final r in classesToday) {
      final start = _timeToday(r.fromTime);
      final end = _timeToday(r.toTime);
      if (start != null && end != null && !now.isBefore(start) && now.isBefore(end)) {
        return r;
      }
    }
    return null;
  }

  /// Minutes until the next class today (null when there is none left).
  int? get minutesToNextClass {
    final next = nextClass;
    if (next == null) return null;
    final start = _timeToday(next.fromTime);
    if (start == null) return null;
    return start.difference(now).inMinutes;
  }

  static DateTime? _timeToday(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return null;
    final parts = hhmm.split(':');
    if (parts.isEmpty) return null;
    final h = int.tryParse(parts[0]);
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    if (h == null) return null;
    final t = DateTime.now();
    return DateTime(t.year, t.month, t.day, h, m);
  }

  /// Distinct subjects the student takes.
  List<String> get subjects {
    final set = <String>{};
    for (final r in timetable?.timetable ?? const []) {
      if (r.courseName.isNotEmpty) set.add(r.courseName);
    }
    for (final a in assignments) {
      final name = a.courseName ?? a.course;
      if (name != null && name.isNotEmpty) set.add(name);
    }
    for (final c in courseAttendance.keys) {
      set.add(c);
    }
    return set.toList();
  }

  // ─── Teacher analytics ───────────────────────────────────────────────────

  /// Submission rate per assignment, weakest first.
  List<({AssignmentModel assignment, double rate, int pending})> get gradingBacklog {
    final rows = assignments
        .map((a) => (
              assignment: a,
              rate: a.submissionRate,
              pending: (a.submittedCount - a.gradedCount).clamp(0, 9999),
            ))
        .toList()
      ..sort((a, b) => b.pending.compareTo(a.pending));
    return rows;
  }

  List<AssignmentModel> get assignmentsNeedingGrades => assignments
      .where((a) => a.submittedCount > a.gradedCount && a.totalStudents > 0)
      .toList();

  int get totalStudentsTaught {
    var total = 0;
    for (final c in classes) {
      total += c.studentCount ?? 0;
    }
    return total;
  }

  List<String> get classNamesFromClasses {
    final names = <String>{};
    for (final c in classes) {
      if ((c.studentGroupName ?? '').isNotEmpty) names.add(c.studentGroupName!);
    }
    return names.toList();
  }
}

/// Small alias so context can describe a standing without importing UI tones.
enum AssistantToneFor { neutral, accent, success, warning, danger, info }
