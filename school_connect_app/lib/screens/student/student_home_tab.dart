import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/assignment_model.dart';
import '../../models/timetable_model.dart';
import '../../models/user_model.dart';
import '../../services/assistant/assistant_context.dart';
import '../../state/assistant_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/school_provider.dart';
import '../../state/student_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';
import '../assistant/assistant_screen.dart';
import 'assignment_detail_screen.dart';
import 'student_assignments_screen.dart';
import 'student_grades_screen.dart';

/// Student home.
///
/// The whole screen is driven by one [AssistantContext] snapshot, so the
/// numbers here are the same numbers the AI copilot reasons over — the app can
/// never contradict itself.
class StudentHomeTab extends ConsumerStatefulWidget {
  const StudentHomeTab({super.key});

  @override
  ConsumerState<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends ConsumerState<StudentHomeTab> {
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
      final student = ref.read(studentProvider);
      if (student.attendanceSummary == null || student.assignments.isEmpty) {
        await ref.read(studentProvider.notifier).loadDashboard();
      }
      final timetable = await ref.read(apiServiceProvider).getMyTimetable();
      if (timetable.timetable.isNotEmpty) _timetable = timetable;
      await ref.read(assistantProvider.notifier).syncData(fetchTimetable: true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  // ─── Derived snapshot ────────────────────────────────────────────────────

  AssistantContext get _ctx {
    final user = ref.watch(authProvider).user;
    final school = ref.watch(schoolProvider).profile;
    final student = ref.watch(studentProvider);
    return AssistantContext(
      userName: user?.fullName ?? 'Student',
      role: UserRole.student,
      schoolName: school?.schoolName ?? user?.schoolName,
      classNames: user?.studentGroups ?? const [],
      attendance: student.attendanceSummary,
      assignments: student.assignments,
      timetable: _timetable,
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
        color: AppColors.studentAccent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _header(ctx, user)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading && ctx.attendance == null && ctx.assignments.isEmpty)
                    ..._loadingSkeleton()
                  else if (_error != null && !ctx.hasData)
                    ErrorState(message: _error!, onRetry: _load)
                  else ...[
                    _quickStats(ctx),
                    const SizedBox(height: AppSpace.xl),
                    if (ctx.todoAssignments.isNotEmpty) ...[
                      _upNext(ctx.todoAssignments.first, ctx),
                      const SizedBox(height: AppSpace.xl),
                    ],
                    _askAiCard(ctx),
                    const SizedBox(height: AppSpace.xl),
                    _todaySection(ctx),
                    const SizedBox(height: AppSpace.xl),
                    if (ctx.gradedAssignments.isNotEmpty) _resultsSection(ctx),
                    if (ctx.courseAttendance.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.xl),
                      _attendanceSection(ctx),
                    ],
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

  List<Widget> _loadingSkeleton() => const [
        Row(
          children: [
            Expanded(child: SkeletonCard(lines: 2)),
            SizedBox(width: 12),
            Expanded(child: SkeletonCard(lines: 2)),
          ],
        ),
        SizedBox(height: 12),
        SkeletonCard(lines: 3),
      ];

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _header(AssistantContext ctx, UserModel? user) {
    final attendance = ctx.overallAttendance;
    final next = ctx.nextClass;
    final mins = ctx.minutesToNextClass;

    return GradientHeader(
      role: AppRoleStyle.student,
      eyebrow: _greeting,
      title: ctx.userName,
      subtitle: ctx.classNames.isEmpty
          ? (user?.email ?? 'Student')
          : ctx.classNames.take(3).join(' · '),
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
          tooltip: 'Notifications',
          badge: ctx.overdueAssignments.isEmpty ? null : ctx.overdueAssignments.length,
          onTap: () => _showNotificationsSheet(ctx),
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ProgressRing(
              percent: attendance,
              size: 62,
              stroke: 7,
              gradient: ProgressRing.gradientFor(attendance),
              trackColor: Colors.white.withValues(alpha: 0.22),
              center: Text(
                '${attendance.toStringAsFixed(0)}%',
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
                    'ATTENDANCE',
                    style: AppText.eyebrow.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attendance >= 85
                        ? 'Excellent — keep it up'
                        : attendance >= 75
                            ? 'Safely above the requirement'
                            : 'Needs attention',
                    style: AppText.body.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (next != null && mins != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_fill_rounded,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '${next.courseName} · ${mins <= 0 ? 'now' : 'in ${mins}m'}',
                              style: AppText.caption.copyWith(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
    final dueSoon = ctx.dueWithin(7);
    final tiles = [
      StatTile(
        label: 'Assignments to do',
        value: '${ctx.todoAssignments.length}',
        icon: Icons.assignment_outlined,
        accent: AppColors.studentAccent,
        delta: dueSoon.isEmpty ? null : '${dueSoon.length} this week',
        deltaPositive: false,
        onTap: () => _push(const StudentAssignmentsScreen()),
      ),
      StatTile(
        label: 'Overdue',
        value: '${ctx.overdueAssignments.length}',
        icon: Icons.error_outline_rounded,
        accent: ctx.overdueAssignments.isEmpty
            ? AppColors.success
            : AppColors.danger,
        onTap: () => _push(const StudentAssignmentsScreen()),
      ),
      StatTile(
        label: 'Average grade',
        value: ctx.gradedAssignments.isEmpty
            ? '—'
            : ctx.averageGrade.toStringAsFixed(1),
        icon: Icons.insights_rounded,
        accent: AppColors.tertiary,
        onTap: () => _push(const StudentGradesScreen()),
      ),
      StatTile(
        label: 'Classes today',
        value: '${ctx.classesToday.length}',
        icon: Icons.schedule_rounded,
        accent: AppColors.secondary,
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: 12),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: 12),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }

  // ─── Up next ─────────────────────────────────────────────────────────────

  Widget _upNext(AssignmentModel a, AssistantContext ctx) {
    final days = a.dueDate!.difference(ctx.now).inDays;
    final urgency = days <= 1
        ? 'Due ${days <= 0 ? 'today' : 'tomorrow'}'
        : 'Due in $days days';

    return GradientCard(
      gradient: days <= 1 ? AppGradients.rose : AppGradients.student,
      padding: const EdgeInsets.all(AppSpace.lg),
      onTap: () => _push(AssignmentDetailScreen(assignment: a)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StatusPill(
                label: 'UP NEXT',
                tone: PillTone.inverse,
                dense: true,
              ),
              const Spacer(),
              Text(
                urgency,
                style: AppText.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            a.title,
            style: AppText.title.copyWith(color: Colors.white, fontSize: 19),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (a.courseName != null) a.courseName!,
              if (a.studentGroupName != null) a.studentGroupName!,
              if (a.dueDate != null) DateFormat('EEE d MMM').format(a.dueDate!),
            ].join('  ·  '),
            style: AppText.body.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: AppRadius.brSm,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Open assignment',
                    style: AppText.caption.copyWith(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }

  // ─── AI entry point ──────────────────────────────────────────────────────

  Widget _askAiCard(AssistantContext ctx) {
    final prompt = ctx.overdueAssignments.isNotEmpty
        ? 'I have ${ctx.overdueAssignments.length} overdue item'
            '${ctx.overdueAssignments.length == 1 ? '' : 's'} — help me catch up'
        : ctx.todoAssignments.isNotEmpty
            ? 'What is due this week?'
            : 'How am I doing overall?';

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
                Text('Ask your Study Assistant', style: AppText.cardTitle),
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
            child: const Icon(Icons.arrow_forward_rounded,
                size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ─── Today's schedule ────────────────────────────────────────────────────

  Widget _todaySection(AssistantContext ctx) {
    final rows = ctx.classesToday;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          eyebrow: DateFormat('EEEE d MMMM').format(DateTime.now()),
          title: "Today's classes",
          trailing: rows.isEmpty
              ? null
              : StatusPill(
                  label: '${rows.length}',
                  tone: PillTone.accent,
                  accentOverride: AppColors.studentAccent,
                ),
        ),
        const SizedBox(height: AppSpace.md),
        if (rows.isEmpty)
          const AppCard(
            elevated: false,
            child: EmptyState(
              icon: Icons.free_breakfast_rounded,
              title: 'No classes today',
              message: 'A free day — a good window for revision or getting ahead.',
              padding: EdgeInsets.symmetric(vertical: 24),
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
    final accent = isCurrent ? AppColors.success : AppColors.studentAccent;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 54,
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
                    Text(
                      row.toTime!,
                      style: AppText.caption.copyWith(fontSize: 10.5),
                    ),
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
                        const StatusPill(
                          label: 'NOW',
                          tone: PillTone.success,
                          dense: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (row.instructorName != null) row.instructorName!,
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

  // ─── Results ─────────────────────────────────────────────────────────────

  Widget _resultsSection(AssistantContext ctx) {
    final recent = ctx.gradedAssignments.toList()
      ..sort((a, b) => (b.submittedAt ?? b.dueDate ?? ctx.now)
          .compareTo(a.submittedAt ?? a.dueDate ?? ctx.now));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          eyebrow: 'Average ${ctx.averageGrade.toStringAsFixed(1)}',
          title: 'Recent results',
          action: 'All',
          onAction: () => _push(const StudentGradesScreen()),
        ),
        const SizedBox(height: AppSpace.md),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (int i = 0; i < recent.take(3).length; i++)
                _resultRow(recent[i], i == recent.take(3).length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultRow(AssignmentModel a, bool isLast) {
    final grade = a.grade ?? 0;
    final tone = grade >= 85
        ? AppColors.success
        : grade >= 70
            ? AppColors.tertiary
            : grade >= 55
                ? AppColors.warning
                : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.hairlineBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: AppRadius.brSm,
            ),
            alignment: Alignment.center,
            child: Text(
              a.displayGrade,
              style: AppText.cardTitle.copyWith(fontSize: 13, color: tone),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: AppText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  a.courseName ?? a.course ?? 'General',
                  style: AppText.caption.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          GradientBar(
            percent: grade,
            height: 6,
            gradient: LinearGradient(
              colors: [tone.withValues(alpha: 0.7), tone],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Attendance breakdown ────────────────────────────────────────────────

  Widget _attendanceSection(AssistantContext ctx) {
    final entries = ctx.courseAttendance.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          eyebrow: 'Weakest first',
          title: 'Attendance by subject',
        ),
        const SizedBox(height: AppSpace.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entries[i].key,
                        style: AppText.cardTitle.copyWith(fontSize: 12.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entries[i].value.toStringAsFixed(0)}%',
                      style: AppText.caption.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: entries[i].value >= 75
                            ? AppColors.successDark
                            : AppColors.dangerDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                GradientBar(
                  percent: entries[i].value,
                  height: 7,
                  gradient: entries[i].value >= 85
                      ? AppGradients.mint
                      : entries[i].value >= 75
                          ? AppGradients.brand
                          : entries[i].value >= 60
                              ? AppGradients.amber
                              : AppGradients.rose,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Sheets & navigation ─────────────────────────────────────────────────

  void _showNotificationsSheet(AssistantContext ctx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Notifications'),
            const SizedBox(height: AppSpace.md),
            if (ctx.overdueAssignments.isNotEmpty)
              for (final a in ctx.overdueAssignments)
                _notificationRow(
                  icon: Icons.error_outline_rounded,
                  color: AppColors.danger,
                  title: '${a.title} is overdue',
                  subtitle: 'Was due ${DateFormat('d MMM').format(a.dueDate!)}',
                ),
            for (final a in ctx.dueWithin(3))
              _notificationRow(
                icon: Icons.schedule_rounded,
                color: AppColors.warning,
                title: '${a.title} is due soon',
                subtitle: '${DateFormat('EEE d MMM').format(a.dueDate!)} · ${a.courseName ?? ''}',
              ),
            if (ctx.overdueAssignments.isEmpty && ctx.dueWithin(3).isEmpty)
              const EmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'Nothing needs you right now',
                message: 'Deadlines and alerts will appear here.',
              ),
          ],
        ),
      ),
    );
  }

  Widget _notificationRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitle.copyWith(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.caption.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
