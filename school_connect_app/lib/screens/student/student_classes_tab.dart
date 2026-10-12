import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/timetable_model.dart';
import '../../state/assistant_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/student_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';
import 'attendance_detail_screen.dart';
import 'student_grades_screen.dart';

/// One row per subject the student actually takes.
class _SubjectView {
  final String name;
  final String? teacher;
  final String? room;
  final double? attendance;
  final int weeklyPeriods;
  final String? nextSlot;
  final DateTime? nextDate;

  const _SubjectView({
    required this.name,
    this.teacher,
    this.room,
    this.attendance,
    this.weeklyPeriods = 0,
    this.nextSlot,
    this.nextDate,
  });
}

/// "My Classes" — derived from the real timetable, not a hardcoded list, so it
/// always matches whatever the school has scheduled.
class StudentClassesTab extends ConsumerStatefulWidget {
  const StudentClassesTab({super.key});

  @override
  ConsumerState<StudentClassesTab> createState() => _StudentClassesTabState();
}

class _StudentClassesTabState extends ConsumerState<StudentClassesTab> {
  TimetableModel? _timetable;
  bool _loading = true;
  String? _error;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      final student = ref.read(studentProvider);
      if (student.attendanceSummary == null || student.assignments.isEmpty) {
        await ref.read(studentProvider.notifier).loadDashboard();
      }
      final timetable = await ref.read(apiServiceProvider).getMyTimetable();
      _timetable = timetable;
      await ref.read(assistantProvider.notifier).syncData(fetchTimetable: true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  List<_SubjectView> get _subjects {
    final tt = _timetable;
    if (tt == null) return const [];
    final now = DateTime.now();
    final attendance = ref.watch(studentProvider).attendanceSummary?.courseWisePercentage ??
        const <String, double>{};

    final byName = <String, List<ScheduleRow>>{};
    for (final row in tt.timetable) {
      if (row.courseName.isEmpty) continue;
      byName.putIfAbsent(row.courseName, () => []).add(row);
    }

    final views = <_SubjectView>[];
    for (final entry in byName.entries) {
      final rows = [...entry.value]..sort((a, b) => a.date.compareTo(b.date));
      final upcoming = rows.where((r) => !r.date.isBefore(DateTime(now.year, now.month, now.day)));
      final next = upcoming.isNotEmpty ? upcoming.first : null;
      views.add(_SubjectView(
        name: entry.key,
        teacher: rows.firstWhere(
          (r) => (r.instructorName ?? '').isNotEmpty,
          orElse: () => rows.first,
        ).instructorName,
        room: rows.firstWhere((r) => (r.room ?? '').isNotEmpty, orElse: () => rows.first).room,
        attendance: attendance[entry.key],
        weeklyPeriods: rows.length,
        nextSlot: next?.fromTime,
        nextDate: next?.date,
      ));
    }
    views.sort((a, b) {
      final aa = a.attendance ?? 101;
      final bb = b.attendance ?? 101;
      return aa.compareTo(bb);
    });
    return views;
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _subjects;
    final filtered = _filter == 'All'
        ? subjects
        : subjects.where((s) => s.name.toLowerCase().contains(_filter.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.studentAccent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: GradientHeader(
                role: AppRoleStyle.student,
                eyebrow: 'Enrolled subjects',
                title: 'My Classes',
                subtitle: subjects.isEmpty
                    ? 'Your timetable has not been published yet'
                    : '${subjects.length} subjects · tap a class for details',
                leading: HeaderIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () {},
                ),
              ),
            ),
            if (subjects.length > 3)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _filters(subjects),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading && subjects.isEmpty)
                    ...const [
                      SkeletonCard(lines: 3),
                      SizedBox(height: 12),
                      SkeletonCard(lines: 3),
                    ]
                  else if (_error != null && subjects.isEmpty)
                    ErrorState(message: _error!, onRetry: _load)
                  else if (filtered.isEmpty)
                    const EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'No classes yet',
                      message:
                          'Once your timetable is published, every subject will appear here '
                          'with its teacher and your attendance.',
                    )
                  else
                    StaggeredList(
                      count: filtered.length,
                      builder: (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _subjectCard(filtered[i], i),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters(List<_SubjectView> subjects) {
    final names = ['All', ...subjects.map((s) => s.name).take(6)];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: names.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = _filter == names[i];
          return Pressable(
            onTap: () => setState(() => _filter = names[i]),
            borderRadius: AppRadius.brPill,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.studentAccent : AppColors.surface,
                borderRadius: AppRadius.brPill,
                border: Border.all(
                  color: selected ? AppColors.studentAccent : AppColors.hairlineBorder,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                names[i],
                style: AppText.caption.copyWith(
                  fontSize: 12,
                  color: selected ? Colors.white : AppColors.inkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _subjectCard(_SubjectView s, int index) {
    final att = s.attendance;
    final tone = att == null
        ? AppColors.inkFaint
        : att >= 85
            ? AppColors.success
            : att >= 75
                ? AppColors.tertiary
                : att >= 60
                    ? AppColors.warning
                    : AppColors.danger;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => _openSubject(s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.studentAccent.withValues(alpha: 0.18),
                      AppColors.secondary.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: AppRadius.brMd,
                ),
                alignment: Alignment.center,
                child: Text(
                  s.name.trimLeft().charactersTaken(2).toUpperCase(),
                  style: AppText.cardTitle.copyWith(
                    color: AppColors.studentAccentDark,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: AppText.cardTitle.copyWith(fontSize: 15.5)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (s.teacher != null) s.teacher!,
                        if (s.weeklyPeriods > 0) '${s.weeklyPeriods} periods/week',
                      ].join('  ·  '),
                      style: AppText.caption.copyWith(fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (att != null)
                StatusPill(
                  label: '${att.toStringAsFixed(0)}%',
                  tone: att >= 75 ? PillTone.success : PillTone.danger,
                  dense: true,
                )
              else
                const StatusPill(label: 'No data', dense: true),
            ],
          ),
          const SizedBox(height: 14),
          if (att != null) ...[
            GradientBar(
              percent: att,
              height: 7,
              gradient: att >= 85
                  ? AppGradients.mint
                  : att >= 75
                      ? AppGradients.brand
                      : att >= 60
                          ? AppGradients.amber
                          : AppGradients.rose,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 13, color: tone),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  s.nextDate == null
                      ? 'No upcoming session'
                      : 'Next: ${DateFormat('EEE d MMM').format(s.nextDate!)}'
                          '${s.nextSlot != null ? ' at ${s.nextSlot}' : ''}'
                          '${s.room != null ? ' · Room ${s.room}' : ''}',
                  style: AppText.caption.copyWith(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.inkFaint),
            ],
          ),
        ],
      ),
    );
  }

  void _openSubject(_SubjectView s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(eyebrow: 'Subject', title: s.name),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                if (s.attendance != null)
                  ProgressRing(
                    percent: s.attendance!,
                    size: 84,
                    gradient: ProgressRing.gradientFor(s.attendance!),
                    center: Text(
                      '${s.attendance!.toStringAsFixed(0)}%',
                      style: AppText.cardTitle.copyWith(fontSize: 16),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detail('Teacher', s.teacher ?? 'Not assigned'),
                      _detail('Room', s.room ?? 'TBD'),
                      _detail('Periods / week', '${s.weeklyPeriods}'),
                      _detail(
                        'Next session',
                        s.nextDate == null
                            ? 'None scheduled'
                            : '${DateFormat('EEE d MMM').format(s.nextDate!)}'
                                '${s.nextSlot != null ? ' · ${s.nextSlot}' : ''}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AttendanceDetailScreen(course: s.name),
                        ),
                      );
                    },
                    icon: const Icon(Icons.event_available_outlined, size: 17),
                    label: const Text('Attendance'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StudentGradesScreen()),
                      );
                    },
                    icon: const Icon(Icons.insights_rounded, size: 17),
                    label: const Text('Results'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.eyebrow.copyWith(fontSize: 9.5)),
          const SizedBox(height: 1),
          Text(value, style: AppText.cardTitle.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

extension on String {
  /// First [n] letters of the first word — used for subject monograms.
  String charactersTaken(int n) {
    final clean = trim();
    if (clean.isEmpty) return '?';
    return clean.length <= n ? clean : clean.substring(0, n);
  }
}
