import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/assignment_model.dart';
import '../../models/student_group_model.dart';
import '../../models/student_model.dart';
import '../../models/super_school_model.dart';
import '../../services/export_service.dart' show ExportService;
import '../../services/google_sheets_service.dart' show AdminDashboardData;
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';

/// Shared chart palette. Colors cycle when a chart has more slices than entries.
const List<Color> _palette = <Color>[
  AppColors.adminAccent,
  AppColors.primary,
  AppColors.tertiary,
  AppColors.warning,
  AppColors.danger,
  AppColors.secondary,
  AppColors.info,
];

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String _pct(num v) => '${v.round()}%';

String _stamp([DateTime? at]) =>
    DateFormat('d MMM yyyy, HH:mm').format(at ?? DateTime.now());

String _slug(String value) {
  final s = value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  return s.isEmpty ? 'school' : s;
}

String _csvCell(Object? value) {
  final text = value?.toString() ?? '';
  if (text.contains(',') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String _csv(List<List<Object?>> rows) =>
    rows.map((r) => r.map(_csvCell).join(',')).join('\n');

Future<void> _shareCsv(
  BuildContext context,
  String content,
  String filename, {
  required String label,
}) async {
  try {
    await ExportService.instance.shareBytes(
      Uint8List.fromList(utf8.encode(content)),
      filename,
      'text/csv',
      text: label,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('Could not share report: $e')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared aggregation
// ─────────────────────────────────────────────────────────────────────────────

/// Everything the school report and its CSV export need, computed once.
class _SchoolStats {
  final AdminDashboardData data;
  final String? programKey;
  final List<AssignmentModel> allAssignments;

  _SchoolStats({
    required this.data,
    this.programKey,
    this.allAssignments = const [],
  });

  static String studentProgramKey(StudentModel s) =>
      (s.program ?? s.programName ?? '').trim();

  static String studentProgramLabel(StudentModel s) =>
      (s.programName ?? s.program ?? '').trim();

  static String classProgramKey(StudentGroupModel c) =>
      (c.program ?? c.programName ?? '').trim();

  /// Program keys that exist on the roster, mapped to their display names.
  static Map<String, String> programOptions(AdminDashboardData data) {
    final map = <String, String>{};
    for (final s in data.students) {
      final key = studentProgramKey(s);
      if (key.isEmpty) continue;
      map[key] = studentProgramLabel(s);
    }
    for (final c in data.classes) {
      final key = classProgramKey(c);
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => (c.programName ?? c.program ?? '').trim());
    }
    return map;
  }

  late final List<StudentModel> students = programKey == null
      ? data.students
      : data.students
          .where((s) => studentProgramKey(s) == programKey)
          .toList();

  late final List<StudentGroupModel> classes = programKey == null
      ? data.classes
      : data.classes
          .where((c) => classProgramKey(c) == programKey)
          .toList();

  late final int activeTeachers = data.teachers.where((t) => t.isEnabled).length;
  late final int activeStudents = students.where((s) => s.isEnabled).length;
  late final int unassigned =
      students.where((s) => (s.studentGroup ?? '').trim().isEmpty).length;

  late final int totalSeats =
      classes.fold<int>(0, (sum, c) => sum + (c.groupSize ?? 0));
  late final double avgClassSize =
      classes.isEmpty ? 0 : totalSeats / classes.length;

  /// Assignments for the selected program (by class), or every assignment.
  late final List<AssignmentModel> assignments = () {
    if (programKey == null) return allAssignments;
    final ids = classes.map((c) => c.id).toSet();
    final names = classes.map((c) => c.name).toSet();
    return allAssignments
        .where((a) =>
            ids.contains(a.studentGroup) || names.contains(a.studentGroupName))
        .toList();
  }();

  late final int expectedSubmissions =
      assignments.fold<int>(0, (sum, a) => sum + a.totalStudents);
  late final int submittedSubmissions =
      assignments.fold<int>(0, (sum, a) => sum + a.submittedCount);
  late final int gradedSubmissions =
      assignments.fold<int>(0, (sum, a) => sum + a.gradedCount);

  double get submissionRate => expectedSubmissions == 0
      ? 0
      : submittedSubmissions / expectedSubmissions * 100;

  double get gradingRate => submittedSubmissions == 0
      ? 0
      : gradedSubmissions / submittedSubmissions * 100;

  int get awaitingGrading =>
      math.max(0, submittedSubmissions - gradedSubmissions);

  late final Map<String, int> genderCounts = () {
    final counts = <String, int>{};
    for (final s in students) {
      final g = (s.gender ?? '').trim();
      final key = g.isEmpty ? 'Not set' : g;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }();

  late final Map<String, int> programCounts = () {
    final counts = <String, int>{};
    for (final s in data.students) {
      final key = studentProgramKey(s);
      final label = key.isEmpty
          ? 'Unassigned'
          : (studentProgramLabel(s).isEmpty ? key : studentProgramLabel(s));
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }();

  /// Classes, largest first.
  late final List<StudentGroupModel> classesBySize = [...classes]..sort(
      (a, b) => (b.groupSize ?? 0).compareTo(a.groupSize ?? 0));

  bool studentInClass(StudentModel student, StudentGroupModel group) =>
      (student.studentGroup ?? '') == group.id ||
      (student.studentGroupName ?? '') == group.name;

  List<StudentModel> studentsOf(StudentGroupModel group) {
    final inProgram = programKey == null
        ? data.students
        : data.students
            .where((s) => studentProgramKey(s) == programKey)
            .toList();
    return inProgram.where((s) => studentInClass(s, group)).toList();
  }

  List<StudentGroupModel> classesInBand(int min, int max) =>
      classes.where((c) {
        final size = c.groupSize ?? 0;
        return size >= min && size <= max;
      }).toList()
        ..sort((a, b) => (b.groupSize ?? 0).compareTo(a.groupSize ?? 0));
}

// ─────────────────────────────────────────────────────────────────────────────
// School admin: executive reports built from the school's own records.
// ─────────────────────────────────────────────────────────────────────────────

class SchoolExecutiveReports extends StatefulWidget {
  final AdminDashboardData? data;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final List<AssignmentModel> assignments;
  final String? schoolName;

  const SchoolExecutiveReports({
    super.key,
    required this.data,
    required this.loading,
    required this.error,
    required this.onRefresh,
    this.assignments = const [],
    this.schoolName,
  });

  /// Plain-CSV version of the report — used by the share button and tests.
  static String buildCsv({
    required AdminDashboardData data,
    List<AssignmentModel> assignments = const [],
    String? schoolName,
    String? programKey,
    String? programLabel,
  }) {
    final s = _SchoolStats(
      data: data,
      programKey: programKey,
      allAssignments: assignments,
    );
    final rows = <List<Object?>>[
      ['School Connect executive report'],
      ['School', schoolName ?? 'School'],
      ['Scope', programLabel ?? 'All programs'],
      ['Generated', _stamp()],
      [],
      ['Metric', 'Value'],
      ['Teachers', data.teachers.length],
      ['Active teachers', s.activeTeachers],
      ['Students', s.students.length],
      ['Active students', s.activeStudents],
      ['Classes', s.classes.length],
      ['Average class size', _fmt(s.avgClassSize)],
      ['Students without a class', s.unassigned],
      [],
      ['Gender', 'Students'],
      for (final e in s.genderCounts.entries) [e.key, e.value],
      [],
      ['Classes by size band', 'Classes'],
      ['1–10', s.classesInBand(0, 10).length],
      ['11–20', s.classesInBand(11, 20).length],
      ['21–30', s.classesInBand(21, 30).length],
      ['31+', s.classesInBand(31, 1 << 30).length],
      [],
      ['Program', 'Students'],
      for (final e in s.programCounts.entries) [e.key, e.value],
      [],
      ['Assignments', 'Value'],
      ['Assignments published', s.assignments.length],
      ['Expected submissions', s.expectedSubmissions],
      ['Submitted', s.submittedSubmissions],
      ['Graded', s.gradedSubmissions],
      ['Submission rate (%)', s.submissionRate.round()],
      ['Grading rate (%)', s.gradingRate.round()],
      ['Awaiting grading', s.awaitingGrading],
      [],
      ['Assignment', 'Class', 'Submitted', 'Expected', 'Graded', 'Due'],
      for (final a in s.assignments)
        [
          a.title,
          a.studentGroupName ?? a.courseName ?? '',
          a.submittedCount,
          a.totalStudents,
          a.gradedCount,
          a.dueDate == null ? '' : DateFormat('yyyy-MM-dd').format(a.dueDate!),
        ],
    ];
    return _csv(rows);
  }

  @override
  State<SchoolExecutiveReports> createState() => _SchoolExecutiveReportsState();
}

class _SchoolExecutiveReportsState extends State<SchoolExecutiveReports> {
  String? _programKey;

  Map<String, String> get _programOptions => widget.data == null
      ? const {}
      : _SchoolStats.programOptions(widget.data!);

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final List<Widget> children;
    if (d == null) {
      children = [
        if (widget.error != null)
          ErrorState(message: widget.error!, onRetry: widget.onRefresh)
        else if (widget.loading)
          const SkeletonCard(lines: 4)
        else
          const EmptyState(
            icon: Icons.insights_rounded,
            title: 'No reports yet',
            message:
                'Reports appear once your school has teachers, students or classes.',
          ),
      ];
    } else {
      if (_programKey != null && !_programOptions.containsKey(_programKey)) {
        _programKey = null;
      }
      children = _schoolSections(_SchoolStats(
        data: d,
        programKey: _programKey,
        allAssignments: widget.assignments,
      ));
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.adminAccent,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: AppSpace.pageScroll,
        children: children,
      ),
    );
  }

  Future<void> _export(AdminDashboardData data) async {
    final options = _programOptions;
    final csv = SchoolExecutiveReports.buildCsv(
      data: data,
      assignments: widget.assignments,
      schoolName: widget.schoolName,
      programKey: _programKey,
      programLabel: _programKey == null ? null : options[_programKey],
    );
    await _shareCsv(
      context,
      csv,
      'executive-report-${_slug(widget.schoolName ?? 'school')}'
      '-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
      label: '${widget.schoolName ?? 'School'} — executive report',
    );
  }

  List<Widget> _schoolSections(_SchoolStats s) {
    final options = _programOptions;
    final genderSlices = [
      for (var i = 0; i < s.genderCounts.length; i++)
        _Slice(
          s.genderCounts.keys.elementAt(i),
          s.genderCounts.values.elementAt(i).toDouble(),
          _palette[i % _palette.length],
        ),
    ];

    final classBars = [
      for (var i = 0; i < math.min(8, s.classesBySize.length); i++)
        _Bar(
          s.classesBySize[i].name,
          (s.classesBySize[i].groupSize ?? 0).toDouble(),
          _palette[i % _palette.length],
          onTap: () => _openClassSheet(s, s.classesBySize[i]),
        ),
    ];

    final spread = [
      _Bar('1–10', s.classesInBand(0, 10).length.toDouble(),
          AppColors.tertiary,
          onTap: () => _openBandSheet(s, '1–10', 0, 10)),
      _Bar('11–20', s.classesInBand(11, 20).length.toDouble(),
          AppColors.primary,
          onTap: () => _openBandSheet(s, '11–20', 11, 20)),
      _Bar('21–30', s.classesInBand(21, 30).length.toDouble(),
          AppColors.warning,
          onTap: () => _openBandSheet(s, '21–30', 21, 30)),
      _Bar('31+', s.classesInBand(31, 1 << 30).length.toDouble(),
          AppColors.danger,
          onTap: () => _openBandSheet(s, '31+', 31, 1 << 30)),
    ];

    final programs = s.programCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final programBars = [
      for (var i = 0; i < math.min(6, programs.length); i++)
        _Bar(
          programs[i].key,
          programs[i].value.toDouble(),
          _palette[i % _palette.length],
          onTap: () {
            final entry = options.entries
                .where((e) => e.value == programs[i].key)
                .toList();
            if (entry.isEmpty) return;
            setState(() => _programKey = entry.first.key);
          },
        ),
    ];

    final gradedBars = [
      for (final a in [...s.assignments]
        ..sort((a, b) => a.submissionRate.compareTo(b.submissionRate)))
        _Bar(
          a.title,
          (a.submissionRate * 100).clamp(0, 100),
          a.submissionRate >= 0.8
              ? AppColors.success
              : a.submissionRate >= 0.5
                  ? AppColors.warning
                  : AppColors.danger,
          onTap: () => _openAssignmentSheet(a),
        ),
    ];

    final insights = <_Insight>[
      if (s.classesBySize.isNotEmpty)
        _Insight(
          'Largest class is ${s.classesBySize.first.name} with '
          '${s.classesBySize.first.groupSize ?? 0} students.',
          AppColors.tertiary,
        ),
      if (s.classesBySize.length > 1)
        _Insight(
          'Smallest class is ${s.classesBySize.last.name} with '
          '${s.classesBySize.last.groupSize ?? 0} students.',
          AppColors.primary,
        ),
      if (s.unassigned > 0)
        _Insight(
          '${s.unassigned} student${s.unassigned == 1 ? '' : 's'} not in a class yet.',
          AppColors.warning,
        ),
      if (s.data.teachers.length - s.activeTeachers > 0)
        _Insight(
          '${s.data.teachers.length - s.activeTeachers} teacher account'
          '${s.data.teachers.length - s.activeTeachers == 1 ? '' : 's'} disabled.',
          AppColors.danger,
        ),
      if (s.assignments.isNotEmpty)
        _Insight(
          '${_pct(s.submissionRate)} of ${s.expectedSubmissions} expected '
          'submissions are in across ${s.assignments.length} assignment'
          '${s.assignments.length == 1 ? '' : 's'}.',
          AppColors.adminAccent,
        ),
      if (s.awaitingGrading > 0)
        _Insight(
          '${s.awaitingGrading} submission${s.awaitingGrading == 1 ? '' : 's'} '
          'still waiting to be graded.',
          AppColors.warning,
        ),
      if (s.students.isEmpty && s.data.teachers.isEmpty && s.classes.isEmpty)
        const _Insight(
          'No records yet. Add teachers, classes and students to see reports.',
          AppColors.inkFaint,
        ),
    ];

    return [
      _ReportToolbar(
        accent: AppColors.adminAccent,
        caption: 'Live snapshot · updated ${_stamp()}',
        onRefresh: widget.onRefresh,
        onExport: () => _export(s.data),
      ),
      if (options.length > 1) ...[
        const SizedBox(height: AppSpace.md),
        _FilterChipRow(
          options: options,
          selected: _programKey,
          accent: AppColors.adminAccent,
          onSelect: (key) => setState(() => _programKey = key),
        ),
      ],
      const SizedBox(height: AppSpace.lg),
      Row(
        children: [
          Expanded(
            child: StatTile(
              label: 'Teachers',
              value: '${s.data.teachers.length}',
              icon: Icons.badge_outlined,
              accent: AppColors.adminAccent,
              delta: '${s.activeTeachers} active',
              onTap: () => _openTeacherSheet(s),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              label: 'Students',
              value: '${s.students.length}',
              icon: Icons.school_outlined,
              accent: AppColors.primary,
              delta: '${s.activeStudents} active',
              onTap: () => _openStudentSheet(
                s.students,
                title: 'Students',
                subtitle: _programKey == null
                    ? '${s.students.length} on the roster'
                    : '${s.students.length} in ${options[_programKey]}',
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: StatTile(
              label: 'Classes',
              value: '${s.classes.length}',
              icon: Icons.class_outlined,
              accent: AppColors.tertiary,
              onTap: () => _openClassListSheet(s),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              label: 'Avg class size',
              value: _fmt(s.avgClassSize),
              icon: Icons.groups_2_outlined,
              accent: AppColors.warning,
              onTap: () => _openBandSheet(
                s,
                '${s.classes.length} classes by size',
                0,
                1 << 30,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpace.lg),
      _Panel(
        title: 'Students by gender',
        subtitle: '${s.students.length} students on the roster · tap a row',
        icon: Icons.pie_chart_rounded,
        child: s.students.isEmpty
            ? const _NoData()
            : _Donut(
                slices: genderSlices,
                center: '${s.students.length}',
                centerLabel: 'students',
                onSliceTap: (slice) => _openStudentSheet(
                  s.students
                      .where((st) =>
                          ((st.gender ?? '').trim().isEmpty
                              ? 'Not set'
                              : st.gender!.trim()) ==
                          slice.label)
                      .toList(),
                  title: slice.label,
                  subtitle: '${slice.value.toInt()} students',
                ),
              ),
      ),
      const SizedBox(height: AppSpace.md),
      _Panel(
        title: 'Biggest classes',
        subtitle: 'Students enrolled per class · tap to see the roster',
        icon: Icons.bar_chart_rounded,
        child: classBars.isEmpty ? const _NoData() : _HBars(bars: classBars),
      ),
      const SizedBox(height: AppSpace.md),
      _Panel(
        title: 'Class size spread',
        subtitle: 'How many classes fall in each size band',
        icon: Icons.stacked_bar_chart_rounded,
        child: s.classes.isEmpty
            ? const _NoData()
            : _Columns(bars: spread),
      ),
      const SizedBox(height: AppSpace.md),
      _Panel(
        title: 'Students by program',
        subtitle: _programKey == null
            ? 'Tap a program to filter the report'
            : 'Tap a program to switch the filter',
        icon: Icons.menu_book_rounded,
        child: programBars.isEmpty ? const _NoData() : _HBars(bars: programBars),
      ),
      const SizedBox(height: AppSpace.md),
      _Panel(
        title: 'Assessment pipeline',
        subtitle: s.assignments.isEmpty
            ? 'No assignments published yet'
            : '${s.assignments.length} assignments · tap for details',
        icon: Icons.fact_check_outlined,
        child: s.assignments.isEmpty
            ? const _NoData(
                'Publish an assignment to track submissions and grading here.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MiniMetric(
                          label: 'Submitted',
                          value: _pct(s.submissionRate),
                          accent: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniMetric(
                          label: 'Graded',
                          value: _pct(s.gradingRate),
                          accent: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MiniMetric(
                          label: 'To grade',
                          value: '${s.awaitingGrading}',
                          accent: s.awaitingGrading > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    'Submission rate by assignment',
                    style: AppText.eyebrow.copyWith(fontSize: 9.5),
                  ),
                  const SizedBox(height: 10),
                  _HBars(bars: gradedBars, unit: '%'),
                ],
              ),
      ),
      const SizedBox(height: AppSpace.md),
      _Panel(
        title: 'Setup health',
        subtitle: 'How complete your school records are',
        icon: Icons.playlist_add_check_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Check(
              label: 'Teacher accounts active',
              done: s.activeTeachers,
              total: s.data.teachers.length,
              color: AppColors.adminAccent,
            ),
            _Check(
              label: 'Student accounts active',
              done: s.activeStudents,
              total: s.students.length,
              color: AppColors.primary,
            ),
            _Check(
              label: 'Students placed in a class',
              done: s.students.length - s.unassigned,
              total: s.students.length,
              color: AppColors.tertiary,
            ),
            _Check(
              label: 'Classes with students',
              done: s.classes.where((c) => (c.groupSize ?? 0) > 0).length,
              total: s.classes.length,
              color: AppColors.warning,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpace.md),
      _Panel(
        title: 'Key insights',
        subtitle: 'Generated from your live records',
        icon: Icons.auto_awesome_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: insights.isEmpty
              ? const [_Insight('Everything looks on track.', AppColors.success)]
              : insights,
        ),
      ),
    ];
  }

  void _openTeacherSheet(_SchoolStats s) {
    _openDetailSheet(
      context,
      title: 'Teachers',
      subtitle: '${s.activeTeachers} of ${s.data.teachers.length} active',
      icon: Icons.badge_outlined,
      accent: AppColors.adminAccent,
      children: [
        for (final t in s.data.teachers)
          _DetailRow(
            title: t.name,
            subtitle: [
              if ((t.email ?? '').isNotEmpty) t.email!,
              if ((t.department ?? '').isNotEmpty) t.department!,
            ].join(' · '),
            trailing: t.isEnabled ? 'Active' : 'Disabled',
            tone: t.isEnabled ? PillTone.success : PillTone.warning,
          ),
        if (s.data.teachers.isEmpty) const _EmptySheet('No teachers yet.'),
      ],
    );
  }

  void _openStudentSheet(
    List<StudentModel> students, {
    required String title,
    String? subtitle,
  }) {
    _openDetailSheet(
      context,
      title: title,
      subtitle: subtitle,
      icon: Icons.people_outline_rounded,
      accent: AppColors.primary,
      children: [
        for (final st in students)
          _DetailRow(
            title: st.name,
            subtitle: [
              if ((st.studentGroupName ?? '').isNotEmpty) st.studentGroupName!,
              if ((st.email ?? '').isNotEmpty) st.email!,
            ].join(' · '),
            trailing: st.isEnabled ? 'Active' : 'Disabled',
            tone: st.isEnabled ? PillTone.success : PillTone.warning,
          ),
        if (students.isEmpty) const _EmptySheet('No students in this view.'),
      ],
    );
  }

  void _openClassListSheet(_SchoolStats s) {
    _openDetailSheet(
      context,
      title: 'Classes',
      subtitle: '${s.classes.length} classes · ${s.totalSeats} seats',
      icon: Icons.class_outlined,
      accent: AppColors.tertiary,
      children: [
        for (final c in s.classesBySize)
          _DetailRow(
            title: c.name,
            subtitle: [
              if ((c.programName ?? c.program ?? '').isNotEmpty)
                c.programName ?? c.program!,
              '${c.groupSize ?? 0} students',
            ].join(' · '),
            trailing: 'Open',
            icon: Icons.chevron_right_rounded,
            onTap: () => _openClassSheet(s, c),
          ),
        if (s.classes.isEmpty) const _EmptySheet('No classes yet.'),
      ],
    );
  }

  void _openClassSheet(_SchoolStats s, StudentGroupModel group) {
    final roster = s.studentsOf(group);
    final size = group.groupSize ?? roster.length;
    final share = s.totalSeats == 0 ? 0 : size / s.totalSeats * 100;
    _openDetailSheet(
      context,
      title: group.name,
      subtitle: (group.programName ?? group.program ?? '').isEmpty
          ? '$size students'
          : '${group.programName ?? group.program} · $size students',
      icon: Icons.groups_2_outlined,
      accent: AppColors.tertiary,
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniMetric(
                label: 'Class size',
                value: '$size',
                accent: AppColors.tertiary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniMetric(
                label: 'School average',
                value: _fmt(s.avgClassSize),
                accent: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniMetric(
                label: 'Share of seats',
                value: _pct(share),
                accent: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Text('Roster', style: AppText.eyebrow.copyWith(fontSize: 9.5)),
        const SizedBox(height: 10),
        for (final st in roster)
          _DetailRow(
            title: st.name,
            subtitle: (st.rollNumber ?? '').isEmpty
                ? (st.email ?? '')
                : 'Roll ${st.rollNumber} · ${st.email ?? ''}',
            trailing: st.isEnabled ? 'Active' : 'Disabled',
            tone: st.isEnabled ? PillTone.success : PillTone.warning,
          ),
        if (roster.isEmpty)
          const _EmptySheet('No roster rows loaded for this class.'),
      ],
    );
  }

  void _openBandSheet(_SchoolStats s, String label, int min, int max) {
    final groups = s.classesInBand(min, max);
    _openDetailSheet(
      context,
      title: 'Class size $label',
      subtitle: '${groups.length} class${groups.length == 1 ? '' : 'es'}',
      icon: Icons.stacked_bar_chart_rounded,
      accent: AppColors.warning,
      children: [
        for (final c in groups)
          _DetailRow(
            title: c.name,
            subtitle: '${c.groupSize ?? 0} students',
            trailing: 'Open',
            icon: Icons.chevron_right_rounded,
            onTap: () => _openClassSheet(s, c),
          ),
        if (groups.isEmpty) const _EmptySheet('No classes in this band.'),
      ],
    );
  }

  void _openAssignmentSheet(AssignmentModel a) {
    final rate = a.submissionRate * 100;
    _openDetailSheet(
      context,
      title: a.title,
      subtitle: [
        if ((a.studentGroupName ?? '').isNotEmpty) a.studentGroupName!,
        if ((a.courseName ?? '').isNotEmpty) a.courseName!,
      ].join(' · '),
      icon: Icons.assignment_outlined,
      accent: AppColors.adminAccent,
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniMetric(
                label: 'Submitted',
                value: '${a.submittedCount}/${a.totalStudents}',
                accent: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniMetric(
                label: 'Graded',
                value: '${a.gradedCount}',
                accent: AppColors.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniMetric(
                label: 'Rate',
                value: _pct(rate),
                accent: rate >= 80
                    ? AppColors.success
                    : rate >= 50
                        ? AppColors.warning
                        : AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        _DetailRow(
          title: 'Due date',
          subtitle: a.dueDate == null
              ? 'No deadline set'
              : DateFormat('EEE d MMM yyyy').format(a.dueDate!),
          trailing: a.isOverdue ? 'Past due' : 'Open',
          tone: a.isOverdue ? PillTone.warning : PillTone.success,
        ),
        _DetailRow(
          title: 'Awaiting grading',
          subtitle: '${math.max(0, a.submittedCount - a.gradedCount)} '
              'submission${a.submittedCount - a.gradedCount == 1 ? '' : 's'}',
        ),
        _DetailRow(
          title: 'Expected submissions',
          subtitle: '${a.totalStudents} students in the class',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Super admin: network-wide reports across every registered school.
// ─────────────────────────────────────────────────────────────────────────────

class SuperExecutiveReports extends StatelessWidget {
  final List<SuperSchoolModel> schools;
  final Future<void> Function()? onRefresh;

  const SuperExecutiveReports({
    super.key,
    required this.schools,
    this.onRefresh,
  });

  /// The fields a school record should have. Used for the completeness score.
  static const _fieldLabels = <String>[
    'Admin assigned',
    'Admin password set',
    'Contact email',
    'Contact number',
    'Address',
    'Motto',
    'Logo',
  ];

  static List<bool> _fields(SuperSchoolModel s) => [
        (s.adminEmail ?? '').isNotEmpty,
        s.hasPassword,
        (s.contactEmail ?? '').isNotEmpty,
        (s.contactNumber ?? '').isNotEmpty,
        (s.address ?? '').isNotEmpty,
        (s.motto ?? '').isNotEmpty,
        (s.logoUrl ?? '').isNotEmpty,
      ];

  static double _score(SuperSchoolModel s) {
    final f = _fields(s);
    return f.where((x) => x).length / f.length;
  }

  /// Plain-CSV version of the network report.
  static String buildCsv(List<SuperSchoolModel> schools) {
    final active =
        schools.where((s) => s.status.toLowerCase() == 'active').length;
    final withAdmin =
        schools.where((s) => (s.adminEmail ?? '').isNotEmpty).length;
    final avgScore = schools.isEmpty
        ? 0.0
        : schools.map(_score).reduce((a, b) => a + b) / schools.length;
    final rows = <List<Object?>>[
      ['School Connect — network executive report'],
      ['Generated', _stamp()],
      [],
      ['Metric', 'Value'],
      ['Schools', schools.length],
      ['Active', active],
      ['With admin', withAdmin],
      ['Average setup score (%)', (avgScore * 100).round()],
      [],
      [
        'School',
        'Site',
        'Port',
        'Status',
        'Setup score (%)',
        'Admin',
        'Admin email',
        'Contact email',
        'Contact number',
        'Address',
        'Created fields',
      ],
      for (final s in [...schools]..sort((a, b) => _score(b).compareTo(_score(a))))
        [
          s.schoolName,
          s.site,
          s.port,
          s.status,
          (_score(s) * 100).round(),
          s.adminName ?? '',
          s.adminEmail ?? '',
          s.contactEmail ?? '',
          s.contactNumber ?? '',
          s.address ?? '',
          '${_fields(s).where((x) => x).length}/${_fieldLabels.length}',
        ],
    ];
    return _csv(rows);
  }

  @override
  Widget build(BuildContext context) {
    final total = schools.length;
    final active = schools.where((s) => s.status.toLowerCase() == 'active').length;
    final withAdmin = schools.where((s) => (s.adminEmail ?? '').isNotEmpty).length;
    final withPassword = schools.where((s) => s.hasPassword).length;
    final avgScore = total == 0
        ? 0.0
        : schools.map(_score).reduce((a, b) => a + b) / total;

    final statusCounts = <String, int>{};
    for (final s in schools) {
      final key = s.status.trim().isEmpty ? 'Unknown' : s.status.trim();
      statusCounts[key] = (statusCounts[key] ?? 0) + 1;
    }
    final statusSlices = [
      for (var i = 0; i < statusCounts.length; i++)
        _Slice(
          statusCounts.keys.elementAt(i),
          statusCounts.values.elementAt(i).toDouble(),
          statusCounts.keys.elementAt(i).toLowerCase() == 'active'
              ? AppColors.success
              : _palette[i % _palette.length],
        ),
    ];

    final checklist = <_Check>[
      for (var i = 0; i < _fieldLabels.length; i++)
        _Check(
          label: _fieldLabels[i],
          done: schools.where((s) => _fields(s)[i]).length,
          total: total,
          color: AppColors.superAccent,
        ),
    ];

    final ranked = [...schools]..sort((a, b) => _score(b).compareTo(_score(a)));
    final rankBars = [
      for (var i = 0; i < math.min(8, ranked.length); i++)
        _Bar(
          ranked[i].schoolName,
          _score(ranked[i]) * 100,
          _palette[i % _palette.length],
          onTap: () => _openSchoolSheet(context, ranked[i]),
        ),
    ];

    final withoutAdmin = total - withAdmin;
    final withoutPassword = total - withPassword;
    final inactive = total - active;

    // Schools with at least one gap, worst first.
    final needsAttention = [
      for (final s in ranked)
        if (_issues(s).isNotEmpty) s,
    ];

    final insights = <_Insight>[
      if (withoutAdmin > 0)
        _Insight(
          '$withoutAdmin school${withoutAdmin == 1 ? '' : 's'} without an admin account.',
          AppColors.danger,
        ),
      if (withoutPassword > 0 && withAdmin > 0)
        _Insight(
          '$withoutPassword school${withoutPassword == 1 ? '' : 's'} without a set admin password.',
          AppColors.warning,
        ),
      if (inactive > 0)
        _Insight(
          '$inactive school${inactive == 1 ? '' : 's'} not currently active.',
          AppColors.warning,
        ),
      if (ranked.isNotEmpty && ranked.last.schoolName != ranked.first.schoolName)
        _Insight(
          '${ranked.last.schoolName} has the least complete setup '
          '(${(_score(ranked.last) * 100).round()}%).',
          AppColors.primary,
        ),
      if (total == 0)
        const _Insight(
          'No schools registered yet. Register one to start reporting.',
          AppColors.inkFaint,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportToolbar(
          accent: AppColors.superAccent,
          caption: total == 0
              ? 'Live snapshot · updated ${_stamp()}'
              : '$total schools · ${_pct(avgScore * 100)} average setup '
                  '· updated ${_stamp()}',
          onRefresh: onRefresh,
          onExport: () => _shareCsv(
            context,
            buildCsv(schools),
            'network-executive-report-'
            '${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
            label: 'School Connect — network executive report',
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Schools',
                value: '$total',
                icon: Icons.apartment_rounded,
                accent: AppColors.superAccent,
                onTap: () => _openSchoolListSheet(
                  context,
                  schools,
                  title: 'Registered schools',
                  subtitle: '$total in the network',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Active',
                value: '$active',
                icon: Icons.check_circle_outline_rounded,
                accent: AppColors.success,
                onTap: () => _openSchoolListSheet(
                  context,
                  schools
                      .where((s) => s.status.toLowerCase() == 'active')
                      .toList(),
                  title: 'Active schools',
                  subtitle: '$active of $total schools',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'With admin',
                value: '$withAdmin',
                icon: Icons.verified_user_outlined,
                accent: AppColors.tertiary,
                onTap: () => _openSchoolListSheet(
                  context,
                  schools
                      .where((s) => (s.adminEmail ?? '').isNotEmpty)
                      .toList(),
                  title: 'Schools with an admin',
                  subtitle: '$withAdmin of $total schools',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Setup score',
                value: _pct(avgScore * 100),
                icon: Icons.speed_rounded,
                accent: AppColors.warning,
                onTap: () => _openSchoolListSheet(
                  context,
                  ranked,
                  title: 'Setup completeness',
                  subtitle: 'Average ${_pct(avgScore * 100)} across $total schools',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        _Panel(
          title: 'School status',
          subtitle: '$total registered across the network',
          icon: Icons.pie_chart_rounded,
          accent: AppColors.superAccent,
          child: total == 0
              ? const _NoData()
              : _Donut(
                  slices: statusSlices,
                  center: '$total',
                  centerLabel: 'schools',
                  onSliceTap: (slice) => _openSchoolListSheet(
                    context,
                    schools
                        .where((s) =>
                            (s.status.trim().isEmpty
                                ? 'Unknown'
                                : s.status.trim()) ==
                            slice.label)
                        .toList(),
                    title: slice.label,
                    subtitle: '${slice.value.toInt()} schools',
                  ),
                ),
        ),
        const SizedBox(height: AppSpace.md),
        _Panel(
          title: 'Setup checklist',
          subtitle: 'Share of schools with each record filled in',
          icon: Icons.playlist_add_check_rounded,
          accent: AppColors.superAccent,
          child: total == 0
              ? const _NoData()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _fieldLabels.length; i++)
                      Pressable(
                        onTap: () => _openSchoolListSheet(
                          context,
                          schools.where((s) => !_fields(s)[i]).toList(),
                          title: 'Missing: ${_fieldLabels[i]}',
                          subtitle: '${schools.where((s) => !_fields(s)[i]).length} '
                              'of $total schools',
                        ),
                        borderRadius: AppRadius.brSm,
                        child: checklist[i],
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpace.md),
        _Panel(
          title: 'Most complete schools',
          subtitle: 'Setup score per school · tap a school for details',
          icon: Icons.bar_chart_rounded,
          accent: AppColors.superAccent,
          child: rankBars.isEmpty ? const _NoData() : _HBars(bars: rankBars, unit: '%'),
        ),
        const SizedBox(height: AppSpace.md),
        _Panel(
          title: 'Needs attention',
          subtitle: 'Schools with gaps in their registry record',
          icon: Icons.report_gmailerrorred_rounded,
          accent: AppColors.warning,
          child: needsAttention.isEmpty
              ? const _NoData('Every school record is complete.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final s in needsAttention.take(5))
                      _DetailRow(
                        title: s.schoolName,
                        subtitle: _issues(s).join(' · '),
                        trailing: '${(_score(s) * 100).round()}%',
                        tone: _score(s) < 0.5 ? PillTone.danger : PillTone.warning,
                        icon: Icons.chevron_right_rounded,
                        onTap: () => _openSchoolSheet(context, s),
                      ),
                    if (needsAttention.length > 5)
                      Text(
                        '+${needsAttention.length - 5} more — tap a bar above '
                        'or open the school list.',
                        style: AppText.caption.copyWith(fontSize: 11.5),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpace.md),
        _Panel(
          title: 'Key insights',
          subtitle: 'Generated from the school registry',
          icon: Icons.auto_awesome_rounded,
          accent: AppColors.superAccent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: insights.isEmpty
                ? const [_Insight('Every school is fully set up.', AppColors.success)]
                : insights,
          ),
        ),
      ],
    );
  }

  static List<String> _issues(SuperSchoolModel s) => [
        if ((s.adminEmail ?? '').isEmpty) 'No admin',
        if (!s.hasPassword) 'No admin password',
        if ((s.contactEmail ?? '').isEmpty) 'No contact email',
        if ((s.contactNumber ?? '').isEmpty) 'No phone',
        if ((s.address ?? '').isEmpty) 'No address',
        if (s.status.toLowerCase() != 'active') '${s.status} status',
      ];

  void _openSchoolListSheet(
    BuildContext context,
    List<SuperSchoolModel> list, {
    required String title,
    String? subtitle,
  }) {
    _openDetailSheet(
      context,
      title: title,
      subtitle: subtitle,
      icon: Icons.apartment_rounded,
      accent: AppColors.superAccent,
      children: [
        for (final s in list)
          _DetailRow(
            title: s.schoolName,
            subtitle: '${s.site} · port ${s.port}',
            trailing: '${(_score(s) * 100).round()}%',
            tone: _score(s) >= 0.8
                ? PillTone.success
                : _score(s) >= 0.5
                    ? PillTone.warning
                    : PillTone.danger,
            icon: Icons.chevron_right_rounded,
            onTap: () => _openSchoolSheet(context, s),
          ),
        if (list.isEmpty) const _EmptySheet('No schools in this view.'),
      ],
    );
  }

  void _openSchoolSheet(BuildContext context, SuperSchoolModel school) {
    final fields = _fields(school);
    final isActive = school.status.toLowerCase() == 'active';
    _openDetailSheet(
      context,
      title: school.schoolName,
      subtitle: '${school.site} · port ${school.port}',
      icon: Icons.apartment_rounded,
      accent: AppColors.superAccent,
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniMetric(
                label: 'Setup score',
                value: _pct(_score(school) * 100),
                accent: AppColors.superAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniMetric(
                label: 'Fields filled',
                value: '${fields.where((f) => f).length}/${fields.length}',
                accent: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniMetric(
                label: 'Status',
                value: isActive ? 'Active' : 'Inactive',
                accent: isActive ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Text('Profile', style: AppText.eyebrow.copyWith(fontSize: 9.5)),
        const SizedBox(height: 10),
        _DetailRow(
          title: school.adminName ?? 'No admin name',
          subtitle: (school.adminEmail ?? '').isEmpty
              ? 'No admin account assigned'
              : school.adminEmail!,
          trailing: school.hasPassword ? 'Password set' : 'No password',
          tone: school.hasPassword ? PillTone.success : PillTone.warning,
        ),
        _DetailRow(
          title: 'Contact',
          subtitle: [
            if ((school.contactEmail ?? '').isNotEmpty) school.contactEmail!,
            if ((school.contactNumber ?? '').isNotEmpty) school.contactNumber!,
          ].join(' · '),
        ),
        _DetailRow(
          title: 'Address',
          subtitle: (school.address ?? '').isEmpty ? 'Not set' : school.address!,
        ),
        _DetailRow(
          title: 'Website',
          subtitle: (school.website ?? '').isEmpty ? 'Not set' : school.website!,
        ),
        const SizedBox(height: AppSpace.sm),
        Text('Record completeness', style: AppText.eyebrow.copyWith(fontSize: 9.5)),
        const SizedBox(height: 10),
        for (var i = 0; i < _fieldLabels.length; i++)
          _Check(
            label: _fieldLabels[i],
            done: fields[i] ? 1 : 0,
            total: 1,
            color: AppColors.superAccent,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared report chrome
// ─────────────────────────────────────────────────────────────────────────────

/// Pressable that degrades to a plain child when there is no tap handler.
class _Tappable extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _Tappable({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Pressable(
      onTap: onTap!,
      borderRadius: AppRadius.brSm,
      child: child,
    );
  }
}

class _ReportToolbar extends StatelessWidget {
  final Color accent;
  final String caption;
  final Future<void> Function()? onRefresh;
  final VoidCallback onExport;

  const _ReportToolbar({
    required this.accent,
    required this.caption,
    required this.onExport,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EXECUTIVE REPORT',
                style: AppText.eyebrow.copyWith(fontSize: 9.5, color: accent),
              ),
              const SizedBox(height: 3),
              Text(caption, style: AppText.caption.copyWith(fontSize: 11.5)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (onRefresh != null)
          _ToolbarButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh report',
            accent: accent,
            onTap: () => onRefresh!(),
          ),
        const SizedBox(width: 8),
        _ToolbarButton(
          icon: Icons.ios_share_rounded,
          tooltip: 'Share report as CSV',
          accent: accent,
          onTap: onExport,
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color accent;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.hairlineBorder),
            boxShadow: AppShadows.soft(),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  final Map<String, String> options;
  final String? selected;
  final Color accent;
  final ValueChanged<String?> onSelect;

  const _FilterChipRow({
    required this.options,
    required this.selected,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String? key, String label) {
      final active = selected == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Pressable(
          onTap: () => onSelect(key),
          borderRadius: AppRadius.brPill,
          child: AnimatedContainer(
            duration: AppMotion.base,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? accent : AppColors.surface,
              borderRadius: AppRadius.brPill,
              border: Border.all(
                color: active ? accent : AppColors.hairlineBorder,
              ),
            ),
            child: Text(
              label,
              style: AppText.cardTitle.copyWith(
                fontSize: 12,
                color: active ? Colors.white : AppColors.inkSoft,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          chip(null, 'All programs'),
          for (final e in options.entries) chip(e.key, e.value),
        ],
      ),
    );
  }
}

Future<void> _openDetailSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required IconData icon,
  required List<Widget> children,
  Color accent = AppColors.adminAccent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      margin: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: AppRadius.brPill,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brMd,
                    ),
                    child: Icon(icon, size: 19, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppText.title.copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: AppText.caption.copyWith(fontSize: 11.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: children,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailing;
  final PillTone? tone;
  final IconData? icon;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.tone,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.hairlineBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppText.caption.copyWith(fontSize: 11.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            if (tone != null)
              StatusPill(label: trailing!, tone: tone!, dense: true)
            else
              Text(
                trailing!,
                style: AppText.cardTitle.copyWith(fontSize: 12),
              ),
          ],
          if (icon != null) Icon(icon, size: 18, color: AppColors.inkFaint),
        ],
      ),
    );

    if (onTap == null) return row;
    return Pressable(
      onTap: onTap!,
      borderRadius: AppRadius.brMd,
      child: row,
    );
  }
}

class _EmptySheet extends StatelessWidget {
  final String message;
  const _EmptySheet(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        message,
        style: AppText.caption.copyWith(fontSize: 12.5),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppText.metric.copyWith(fontSize: 17, color: accent),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppText.caption.copyWith(fontSize: 10.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chart pieces
// ─────────────────────────────────────────────────────────────────────────────

class _Slice {
  final String label;
  final double value;
  final Color color;
  const _Slice(this.label, this.value, this.color);
}

class _Bar {
  final String label;
  final double value;
  final Color color;
  final VoidCallback? onTap;
  const _Bar(this.label, this.value, this.color, {this.onTap});
}

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final Color accent;

  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.accent = AppColors.adminAccent,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.cardTitle),
                    if (subtitle != null)
                      Text(subtitle!, style: AppText.caption.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          child,
        ],
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  final String? message;
  const _NoData([this.message]);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message ?? 'No data to chart yet.',
        style: AppText.caption.copyWith(fontSize: 12.5),
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  final List<_Slice> slices;
  final String center;
  final String centerLabel;
  final ValueChanged<_Slice>? onSliceTap;

  const _Donut({
    required this.slices,
    required this.center,
    required this.centerLabel,
    this.onSliceTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, x) => s + x.value);
    return Row(
      children: [
        SizedBox(
          width: 128,
          height: 128,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: AppMotion.slow,
            curve: AppMotion.emphasized,
            builder: (_, t, __) => CustomPaint(
              painter: _DonutPainter(slices: slices, progress: t),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(center, style: AppText.metric.copyWith(fontSize: 20)),
                    Text(centerLabel, style: AppText.caption.copyWith(fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in slices)
                _Tappable(
                  onTap: onSliceTap == null ? null : () => onSliceTap!(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.label,
                            style: AppText.body.copyWith(fontSize: 12.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          total == 0 ? '0%' : '${(s.value / total * 100).round()}%',
                          style: AppText.cardTitle.copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
  final double progress;

  const _DonutPainter({required this.slices, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = AppColors.surfaceContainerHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final total = slices.fold<double>(0, (s, x) => s + x.value);
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * math.pi * 2 * progress;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, math.max(0, sweep - 0.06), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.slices != slices;
}

class _HBars extends StatelessWidget {
  final List<_Bar> bars;
  final String unit;

  const _HBars({required this.bars, this.unit = ''});

  @override
  Widget build(BuildContext context) {
    final max = bars.fold<double>(0, (m, b) => math.max(m, b.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in bars)
          _Tappable(
            onTap: b.onTap,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.label,
                          style: AppText.body.copyWith(
                            fontSize: 12.5,
                            color: AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_fmt(b.value)}$unit',
                        style: AppText.cardTitle.copyWith(fontSize: 12.5),
                      ),
                      if (b.onTap != null)
                        const Icon(Icons.chevron_right_rounded,
                            size: 16, color: AppColors.inkFaint),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _Track(
                    fraction: max == 0 ? 0 : b.value / max,
                    color: b.color,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Track extends StatelessWidget {
  final double fraction;
  final Color color;

  const _Track({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    final target = fraction.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: AppRadius.brPill,
      child: Stack(
        children: [
          Container(height: 9, color: AppColors.surfaceContainerHigh),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: target),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                height: 9,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, Color.lerp(color, Colors.white, 0.25)!],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Columns extends StatelessWidget {
  final List<_Bar> bars;
  final double height;

  const _Columns({required this.bars}) : height = 160;

  @override
  Widget build(BuildContext context) {
    final max = bars.fold<double>(0, (m, b) => math.max(m, b.value));
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in bars)
            Expanded(
              child: _Tappable(
                onTap: b.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(_fmt(b.value), style: AppText.cardTitle.copyWith(fontSize: 12)),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: max == 0 ? 0.0 : b.value / max,
                        ),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Container(
                          height: math.max(4, v * (height - 58)),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [b.color, b.color.withValues(alpha: 0.55)],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        b.label,
                        style: AppText.caption.copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final String label;
  final int done;
  final int total;
  final Color color;

  const _Check({
    required this.label,
    required this.done,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total * 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(fontSize: 12.5, color: AppColors.ink),
                ),
              ),
              Text(
                total == 0 ? '—' : '$done of $total · ${pct.round()}%',
                style: AppText.caption.copyWith(fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GradientBar(
            percent: pct,
            height: 8,
            gradient: LinearGradient(
              colors: [color, Color.lerp(color, Colors.white, 0.25)!],
            ),
          ),
        ],
      ),
    );
  }
}

class _Insight extends StatelessWidget {
  final String text;
  final Color color;

  const _Insight(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DoodleIcon(
              kind: DoodleKind.star,
              color: color,
              size: 18,
              filled: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppText.body.copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
