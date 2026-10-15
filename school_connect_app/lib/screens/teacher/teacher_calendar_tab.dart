import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/course_schedule_model.dart';
import '../../models/timetable_model.dart';
import '../../state/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';
import 'teacher_class_hub_screen.dart';

/// Teacher calendar: the real weekly timetable, one day at a time.
/// Tapping a lesson opens that class.
class TeacherCalendarTab extends ConsumerStatefulWidget {
  const TeacherCalendarTab({super.key});

  @override
  ConsumerState<TeacherCalendarTab> createState() => _TeacherCalendarTabState();
}

class _TeacherCalendarTabState extends ConsumerState<TeacherCalendarTab> {
  TimetableModel? _timetable;
  bool _loading = true;
  String? _error;
  DateTime _selected = _dayOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday of the current week.
  DateTime get _weekStart {
    final today = _dayOnly(DateTime.now());
    return today.subtract(Duration(days: today.weekday - 1));
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      final timetable = await ref.read(apiServiceProvider).getMyTimetable();
      if (mounted) setState(() => _timetable = timetable);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  List<ScheduleRow> _rowsFor(DateTime day) {
    final rows = (_timetable?.timetable ?? const <ScheduleRow>[])
        .where((r) => _dayOnly(r.date) == day)
        .toList();
    rows.sort((a, b) => (a.fromTime ?? '').compareTo(b.fromTime ?? ''));
    return rows;
  }

  CourseScheduleModel _scheduleFor(ScheduleRow r) => CourseScheduleModel(
        id: r.classId ?? r.name,
        course: r.course,
        courseName: r.courseName,
        studentGroup: r.classId,
        studentGroupName: r.studentGroupName,
        instructorName: r.instructorName,
        scheduleDate: r.date,
        startTime: r.fromTime,
        endTime: r.toTime,
        room: r.room,
      );

  @override
  Widget build(BuildContext context) {
    final rows = _rowsFor(_selected);
    final isToday = _selected == _dayOnly(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientHeader(
            role: AppRoleStyle.teacher,
            eyebrow: 'Your timetable',
            title: 'Calendar',
            subtitle: DateFormat('MMMM y').format(DateTime.now()),
          ),
          _weekStrip(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.teacherAccent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                children: [
                  SectionHeader(
                    eyebrow: DateFormat('EEEE, d MMM').format(_selected),
                    title: isToday ? 'Today' : 'Lessons',
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (_loading && _timetable == null)
                    const SkeletonCard(lines: 3)
                  else if (_error != null && _timetable == null)
                    ErrorState(message: _error!, onRetry: _load)
                  else if (rows.isEmpty)
                    const EmptyState(
                      icon: Icons.event_available_rounded,
                      title: 'No lessons this day',
                      message:
                          'Lessons from your timetable will show up here.',
                    )
                  else
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _lessonCard(r),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekStrip() {
    final start = _weekStart;
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final day = start.add(Duration(days: i));
          final selected = day == _selected;
          final hasLessons = _rowsFor(day).isNotEmpty;
          return Pressable(
            onTap: () => setState(() => _selected = day),
            borderRadius: AppRadius.brLg,
            child: AnimatedContainer(
              duration: AppMotion.base,
              width: 52,
              decoration: BoxDecoration(
                color: selected ? AppColors.teacherAccent : AppColors.surface,
                borderRadius: AppRadius.brLg,
                border: Border.all(
                  color: selected
                      ? AppColors.teacherAccent
                      : AppColors.hairlineBorder,
                ),
                boxShadow:
                    selected ? AppShadows.glow(AppColors.teacherAccent) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(day).toUpperCase(),
                    style: AppText.eyebrow.copyWith(
                      fontSize: 10,
                      color: selected ? Colors.white70 : AppColors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: AppText.cardTitle.copyWith(
                      fontSize: 16,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasLessons
                          ? (selected ? Colors.white : AppColors.teacherAccent)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _lessonCard(ScheduleRow r) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TeacherClassHubScreen(courseSchedule: _scheduleFor(r)),
      )),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.teacherAccentSoft,
              borderRadius: AppRadius.brMd,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r.fromTime ?? '—',
                  style: AppText.cardTitle.copyWith(
                    fontSize: 12,
                    color: AppColors.teacherAccent,
                  ),
                ),
                if (r.toTime != null)
                  Text(r.toTime!,
                      style: AppText.caption.copyWith(fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.courseName,
                  style: AppText.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (r.studentGroupName != null) r.studentGroupName!,
                    if (r.room != null) 'Room ${r.room}',
                  ].join('  ·  '),
                  style: AppText.caption.copyWith(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}
