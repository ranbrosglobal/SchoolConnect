import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_provider.dart';
import '../theme/colors.dart';
import '../utils/time_format.dart';
import '../models/timetable_model.dart';

/// Student timetable: a weekly grid (Mon–Sun × time slots) with week
/// navigation, plus the full list of the student's teachers and subjects.
class StudentTimetable extends ConsumerStatefulWidget {
  const StudentTimetable({super.key});

  @override
  ConsumerState<StudentTimetable> createState() => _StudentTimetableState();
}

class _StudentTimetableState extends ConsumerState<StudentTimetable> {
  DateTime _monday = _mondayOf(DateTime.now());
  TimetableModel? _data;
  bool _loading = true;
  String? _error;

  static DateTime _mondayOf(DateTime d) {
    final base = DateTime(d.year, d.month, d.day);
    return base.subtract(Duration(days: base.weekday - DateTime.monday));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(demoApiServiceProvider)
          .getMyTimetable(weekStart: _monday);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _shiftWeek(int delta) {
    setState(() => _monday = _monday.add(Duration(days: 7 * delta)));
    _load();
  }

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Timetable', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading && _data == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 42, color: AppColors.outline),
                        const SizedBox(height: 12),
                        Text('Could not load your timetable', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.outline, fontSize: 12)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildWeekNav(),
                      const SizedBox(height: 16),
                      _buildGrid(),
                      const SizedBox(height: 28),
                      _buildSectionTitle(context, 'My Teachers (${_data?.teachers.length ?? 0})'),
                      const SizedBox(height: 12),
                      ..._buildTeachers(),
                      const SizedBox(height: 28),
                      _buildSectionTitle(context, 'My Subjects (${_data?.subjects.length ?? 0})'),
                      const SizedBox(height: 12),
                      ..._buildSubjects(),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWeekNav() {
    final start = _monday;
    final end = _monday.add(const Duration(days: 6));
    final label = '${_fmt(start)} – ${_fmt(end)}';
    final isCurrentWeek = _mondayOf(DateTime.now()).isAtSameMomentAs(_monday);
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => _shiftWeek(-1),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous week',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (!isCurrentWeek)
                TextButton(onPressed: () => setState(() => _monday = _mondayOf(DateTime.now())), child: const Text('Jump to this week'))
              else
                const Text('This week', style: TextStyle(fontSize: 12, color: AppColors.outline)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () => _shiftWeek(1),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next week',
        ),
      ],
    );
  }

  String _fmt(DateTime d) => '${d.day} ${_monthName(d.month)}';

  String _monthName(int m) =>
      const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  Widget _buildGrid() {
    final rows = _data?.timetable ?? const <ScheduleRow>[];
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairlineBorder),
        ),
        child: const Column(
          children: [
            Icon(Icons.event_busy_outlined, color: AppColors.outline, size: 40),
            SizedBox(height: 10),
            Text('No classes scheduled this week', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Try the next or previous week.', style: TextStyle(color: AppColors.outline, fontSize: 12)),
          ],
        ),
      );
    }

    final byDay = <int, List<ScheduleRow>>{};
    for (final r in rows) {
      byDay.putIfAbsent(r.weekday, () => []).add(r);
    }
    // Distinct time slots, sorted; HH:MM:SS from the backend.
    final slots = rows.map((r) => r.fromTime).whereType<String>().toSet().toList()
      ..sort();
    if (slots.isEmpty) slots.add('00:00:00');

    const timeW = 66.0;
    const dayW = 108.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairlineBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: timeW + 7 * dayW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header row: time col + 7 days
              Row(
                children: [
                  Container(width: timeW, height: 44, color: AppColors.surfaceContainerLow),
                  for (var d = 0; d < 7; d++)
                    Container(
                      width: dayW,
                      height: 44,
                      color: d == DateTime.now().weekday - 1
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : AppColors.surfaceContainerLow,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _dayNames[d],
                            style: const TextStyle(fontSize: 11, color: AppColors.outline, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${_monday.add(Duration(days: d)).day}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: d == DateTime.now().weekday - 1 ? AppColors.primary : AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              // time rows
              for (final slot in slots)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: timeW,
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatTime12h(slot),
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.outline),
                      ),
                    ),
                    for (var d = 0; d < 7; d++)
                      Container(
                        width: dayW,
                        height: 58,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          border: Border(
                            right: const BorderSide(color: AppColors.hairlineBorder, width: 0.5),
                            bottom: const BorderSide(color: AppColors.hairlineBorder, width: 0.5),
                          ),
                          color: d == DateTime.now().weekday - 1
                              ? AppColors.primary.withValues(alpha: 0.04)
                              : Colors.white,
                        ),
                        child: _dayCell(_findRow(byDay[d], slot)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  ScheduleRow? _findRow(List<ScheduleRow>? list, String slot) {
    if (list == null) return null;
    for (final r in list) {
      if (r.fromTime == slot) return r;
    }
    return null;
  }

  Widget? _dayCell(ScheduleRow? row) {
    if (row == null) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            row.courseName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.info, height: 1.15),
          ),
        ),
        if (row.room != null && row.room!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            row.room!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9.5, color: AppColors.outline),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildTeachers() {
    final teachers = _data?.teachers ?? const <TeacherInfo>[];
    if (teachers.isEmpty) {
      return [const Text('No teachers assigned yet.', style: TextStyle(color: AppColors.outline))];
    }
    return teachers.map((t) {
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.hairlineBorder),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.info.withValues(alpha: 0.15),
            child: Text(
              t.instructorName.isNotEmpty ? t.instructorName[0] : 'T',
              style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(t.instructorName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            t.courses.map((c) => c.courseName).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            '${t.courses.length} subject${t.courses.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 12, color: AppColors.outline),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildSubjects() {
    final subjects = _data?.subjects ?? const <SubjectInfo>[];
    if (subjects.isEmpty) {
      return [const Text('No subjects assigned yet.', style: TextStyle(color: AppColors.outline))];
    }
    return subjects.map((s) {
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.hairlineBorder),
        ),
        child: ListTile(
          leading: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book_outlined, color: AppColors.primary, size: 22),
          ),
          title: Text(s.courseName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            s.teachers.map((t) => t.instructorName).join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
