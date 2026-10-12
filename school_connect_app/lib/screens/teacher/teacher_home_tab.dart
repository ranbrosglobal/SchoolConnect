import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/assignment_model.dart';
import '../../models/course_schedule_model.dart';
import '../../models/timetable_model.dart';
import '../../models/user_model.dart';
import '../../services/assistant/assistant_context.dart';
import '../../state/assistant_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/school_provider.dart';
import '../../state/teacher_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';
import '../assistant/assistant_screen.dart';
import 'assignment_detail_screen.dart';
import 'teacher_assignments_screen.dart';
import 'teacher_class_hub_screen.dart';

/// Teacher home.
///
/// Leads with the two things a teacher actually opens the app for: what is
/// happening *now*, and what still needs grading.
class TeacherHomeTab extends ConsumerStatefulWidget {
  const TeacherHomeTab({super.key});

  @override
  ConsumerState<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends ConsumerState<TeacherHomeTab> {
  TimetableModel? _timetable;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      final teacher = ref.read(teacherProvider);
      if (teacher.classes.isEmpty) {
        await ref.read(teacherProvider.notifier).loadClasses();
      }
      if (teacher.assignments.isEmpty) {
        await ref.read(teacherProvider.notifier).loadAssignments();
      }
      try {
        final timetable = await ref.read(apiServiceProvider).getMyTimetable();
        if (timetable.timetable.isNotEmpty) _timetable = timetable;
      } catch (_) {
        // Timetable is optional for teachers.
      }
      await ref.read(assistantProvider.notifier).syncData();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  AssistantContext get _ctx {
    final user = ref.watch(authProvider).user;
    final school = ref.watch(schoolProvider).profile;
    final teacher = ref.watch(teacherProvider);
    return AssistantContext(
      userName: user?.fullName ?? 'Teacher',
      role: user?.role ?? UserRole.instructor,
      schoolName: school?.schoolName ?? user?.schoolName,
      classNames: teacher.classes
          .map((c) => c.studentGroupName ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList(),
      assignments: teacher.assignments,
      timetable: _timetable,
      classes: teacher.classes,
      now: DateTime.now(),
    );
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _ctx;
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teacherAccent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _header(ctx, user)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading && ctx.classes.isEmpty && ctx.assignments.isEmpty)
                    ..._skeleton()
                  else if (_error != null && !ctx.hasData)
                    ErrorState(message: _error!, onRetry: _load)
                  else ...[
                    _quickStats(ctx),
                    const SizedBox(height: AppSpace.xl),
                    _askAiCard(ctx),
                    const SizedBox(height: AppSpace.xl),
                    if (ctx.assignmentsNeedingGrades.isNotEmpty) ...[
                      _gradingQueue(ctx),
                      const SizedBox(height: AppSpace.xl),
                    ],
                    _todaySection(ctx),
                    const SizedBox(height: AppSpace.xl),
                    if (ctx.classes.isNotEmpty) _classHealth(ctx),
                  ],
                  const SizedBox(height: AppSpace.xl),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _skeleton() => const [
        SkeletonCard(lines: 2),
        SizedBox(height: 12),
        SkeletonCard(lines: 3),
      ];

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _header(AssistantContext ctx, UserModel? user) {
    final totalSubmitted = ctx.assignments.fold<int>(0, (s, a) => s + a.submittedCount);
    final totalGraded = ctx.assignments.fold<int>(0, (s, a) => s + a.gradedCount);
    final gradedPct = totalSubmitted == 0 ? 0.0 : totalGraded / totalSubmitted * 100;

    final subjects = ctx.classes
        .map((c) => c.courseName ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .take(2)
        .join(' · ');

    return GradientHeader(
      role: AppRoleStyle.teacher,
      eyebrow: _greeting,
      title: ctx.userName,
      subtitle: subjects.isEmpty ? (user?.email ?? 'Teacher') : subjects,
      leading: InitialsAvatar(
        name: ctx.userName,
        size: 44,
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.14),
          ],
        ),
      ),
      actions: [
        HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Alerts',
          badge: ctx.assignmentsNeedingGrades.length,
          onTap: () => _showAlertsSheet(ctx),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ProgressRing(
              percent: gradedPct,
              size: 62,
              stroke: 7,
              gradient: gradedPct >= 80 ? AppGradients.mint : AppGradients.amber,
              trackColor: Colors.white.withValues(alpha: 0.22),
              center: Text(
                '${gradedPct.toStringAsFixed(0)}%',
                style: AppText.cardTitle.copyWith(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MARKING PROGRESS',
                    style: AppText.eyebrow.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalGraded of $totalSubmitted submissions graded',
                    style: AppText.body.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatusPill(
                    label: ctx.assignmentsNeedingGrades.isEmpty
                        ? 'All caught up'
                        : '${ctx.assignmentsNeedingGrades.length} to grade',
                    tone: ctx.assignmentsNeedingGrades.isEmpty
                        ? PillTone.success
                        : PillTone.warning,
                    icon: ctx.assignmentsNeedingGrades.isEmpty
                        ? Icons.check_circle_rounded
                        : Icons.rate_review_rounded,
                    dense: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quick stats ─────────────────────────────────────────────────────────

  Widget _quickStats(AssistantContext ctx) {
    final students = ctx.totalStudentsTaught;
    final avgRate = ctx.assignments.isEmpty
        ? 0.0
        : ctx.assignments.map((a) => a.submissionRate).reduce((a, b) => a + b) /
            ctx.assignments.length *
            100;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'My classes',
                value: '${ctx.classNamesFromClasses.isEmpty ? ctx.classes.length : ctx.classNamesFromClasses.length}',
                icon: Icons.groups_2_outlined,
                accent: AppColors.teacherAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Students',
                value: students == 0 ? '—' : '$students',
                icon: Icons.people_alt_outlined,
                accent: AppColors.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'To grade',
                value: '${ctx.assignmentsNeedingGrades.length}',
                icon: Icons.fact_check_outlined,
                accent: ctx.assignmentsNeedingGrades.isEmpty
                    ? AppColors.success
                    : AppColors.warning,
                delta: ctx.assignmentsNeedingGrades.isEmpty ? null : 'action',
                deltaPositive: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Submission rate',
                value: ctx.assignments.isEmpty ? '—' : '${avgRate.toStringAsFixed(0)}%',
                icon: Icons.trending_up_rounded,
                accent: avgRate >= 80
                    ? AppColors.success
                    : avgRate >= 60
                        ? AppColors.warning
                        : AppColors.danger,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── AI ──────────────────────────────────────────────────────────────────

  Widget _askAiCard(AssistantContext ctx) {
    final prompt = ctx.assignmentsNeedingGrades.isNotEmpty
        ? 'What still needs grading?'
        : ctx.classes.isNotEmpty
            ? 'How are my classes doing?'
            : 'Summarise my week';

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => _push(const AssistantScreen()),
      child: Row(
        children: [
          const AssistantOrb(size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ask your Teaching Assistant', style: AppText.cardTitle),
                const SizedBox(height: 2),
                Text(
                  '"$prompt"',
                  style: AppText.caption.copyWith(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppGradients.ai,
              borderRadius: AppRadius.brSm,
              boxShadow: AppShadows.glow(AppColors.primary, strength: 0.3),
            ),
            child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ─── Grading queue ───────────────────────────────────────────────────────

  Widget _gradingQueue(AssistantContext ctx) {
    final queue = ctx.gradingBacklog
        .where((r) => r.pending > 0)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          eyebrow: 'Needs your attention',
          title: 'Grading queue',
          action: 'All',
          onAction: () => _push(const TeacherAssignmentsScreen()),
        ),
        const SizedBox(height: AppSpace.md),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (int i = 0; i < queue.length; i++)
                _queueRow(queue[i].assignment, queue[i].pending, i == queue.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _queueRow(AssignmentModel a, int pending, bool isLast) {
    final rate = a.submissionRate * 100;
    return Pressable(
      onTap: () => _push(TeacherAssignmentDetailScreen(assignment: a)),
      borderRadius: AppRadius.brSm,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.hairlineBorder)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: AppText.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${a.studentGroupName ?? 'Class'} · '
                        '${a.submittedCount}/${a.totalStudents} submitted',
                        style: AppText.caption.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusPill(
                  label: '$pending to grade',
                  tone: pending > 10 ? PillTone.danger : PillTone.warning,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 9),
            GradientBar(
              percent: rate,
              height: 6,
              gradient: rate >= 80
                  ? AppGradients.mint
                  : rate >= 60
                      ? AppGradients.amber
                      : AppGradients.rose,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Today ───────────────────────────────────────────────────────────────

  Widget _todaySection(AssistantContext ctx) {
    final rows = ctx.timetable == null ? <ScheduleRow>[] : ctx.classesToday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          eyebrow: DateFormat('EEEE d MMMM').format(DateTime.now()),
          title: 'Today',
          action: 'Calendar',
          onAction: () => _push(const TeacherAssignmentsScreen()),
        ),
        const SizedBox(height: AppSpace.md),
        if (ctx.classes.isEmpty && rows.isEmpty)
          const AppCard(
            elevated: false,
            child: EmptyState(
              icon: Icons.event_busy_rounded,
              title: 'No classes scheduled',
              message: 'Your timetable will appear here once classes are assigned.',
              padding: EdgeInsets.symmetric(vertical: 24),
            ),
          )
        else if (rows.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (int i = 0; i < ctx.classes.length; i++)
                  _classRow(ctx.classes[i], i == ctx.classes.length - 1),
              ],
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++)
                  _scheduleRow(rows[i], ctx, i == rows.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _scheduleRow(ScheduleRow row, AssistantContext ctx, bool isLast) {
    final isCurrent = ctx.currentClass?.name == row.name;
    final accent = isCurrent ? AppColors.success : AppColors.teacherAccent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    row.fromTime ?? '—',
                    style: AppText.cardTitle.copyWith(fontSize: 12.5, color: accent),
                  ),
                  if (row.toTime != null)
                    Text(row.toTime!, style: AppText.caption.copyWith(fontSize: 10.5)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 16),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent ? accent : AppColors.surface,
                  border: Border.all(color: accent, width: 2),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: isLast
                      ? Colors.transparent
                      : AppColors.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.courseName,
                          style: AppText.cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrent)
                        const StatusPill(label: 'NOW', tone: PillTone.success, dense: true),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (row.studentGroupName != null) row.studentGroupName!,
                      if (row.room != null) 'Room ${row.room}',
                    ].join('  ·  '),
                    style: AppText.caption.copyWith(fontSize: 11.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _classRow(CourseScheduleModel c, bool isLast) {
    return Pressable(onTap: () => _push(TeacherClassHubScreen(courseSchedule: c)),
              borderRadius: AppRadius.brSm,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.hairlineBorder)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.teacherAccentSoft,
                borderRadius: AppRadius.brSm,
              ),
              child: const Icon(Icons.groups_rounded,
                  size: 18, color: AppColors.teacherAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.studentGroupName ?? 'Class',
                    style: AppText.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      c.courseName ?? 'Course',
                      if (c.room != null) 'Room ${c.room}',
                      if (c.studentCount != null) '${c.studentCount} students',
                    ].join('  ·  '),
                    style: AppText.caption.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }

  // ─── Class health ────────────────────────────────────────────────────────

  Widget _classHealth(AssistantContext ctx) {
    final withRate = ctx.classes.where((c) => (c.studentCount ?? 0) > 0).toList();
    if (withRate.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(eyebrow: 'At a glance', title: 'Class health'),
        const SizedBox(height: AppSpace.md),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: withRate.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final c = withRate[i];
              final classAssignments = ctx.assignments
                  .where((a) => a.studentGroupName == c.studentGroupName)
                  .toList();
              final rate = classAssignments.isEmpty
                  ? 0.0
                  : classAssignments
                          .map((a) => a.submissionRate)
                          .reduce((a, b) => a + b) /
                      classAssignments.length *
                      100;
              return SizedBox(
                width: 168,
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => _push(TeacherClassHubScreen(courseSchedule: c)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.studentGroupName ?? 'Class',
                        style: AppText.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.courseName ?? 'Course',
                        style: AppText.caption.copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        '${c.studentCount} students',
                        style: AppText.caption.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        classAssignments.isEmpty
                            ? 'No assignments yet'
                            : '${rate.toStringAsFixed(0)}% submitted',
                        style: AppText.cardTitle.copyWith(
                          fontSize: 13,
                          color: rate >= 80
                              ? AppColors.successDark
                              : rate >= 60
                                  ? AppColors.warningDark
                                  : AppColors.dangerDark,
                        ),
                      ),
                      const SizedBox(height: 7),
                      GradientBar(
                        percent: rate,
                        height: 6,
                        gradient: rate >= 80
                            ? AppGradients.mint
                            : rate >= 60
                                ? AppGradients.amber
                                : AppGradients.rose,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Alerts sheet ────────────────────────────────────────────────────────

  void _showAlertsSheet(AssistantContext ctx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Alerts'),
            const SizedBox(height: AppSpace.md),
            if (ctx.assignmentsNeedingGrades.isEmpty)
              const EmptyState(
                icon: Icons.done_all_rounded,
                title: 'Nothing needs you',
                message: 'Grading is up to date and no class is falling behind.',
              )
            else
              for (final a in ctx.assignmentsNeedingGrades.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: AppRadius.brSm,
                        ),
                        child: const Icon(Icons.rate_review_rounded,
                            size: 18, color: AppColors.warningDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title,
                                style: AppText.cardTitle.copyWith(fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(
                              '${a.submittedCount - a.gradedCount} submissions waiting',
                              style: AppText.caption.copyWith(fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
