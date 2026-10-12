import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/course_schedule_model.dart';
import '../../state/auth_provider.dart';
import '../../state/teacher_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';
import 'teacher_class_hub_screen.dart';

/// The teacher's classes, each showing how the class is actually doing.
class TeacherClassesTab extends ConsumerStatefulWidget {
  const TeacherClassesTab({super.key});

  @override
  ConsumerState<TeacherClassesTab> createState() => _TeacherClassesTabState();
}

class _TeacherClassesTabState extends ConsumerState<TeacherClassesTab> {
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
      await ref.read(teacherProvider.notifier).loadClasses();
      final teacher = ref.read(teacherProvider);
      if (teacher.assignments.isEmpty) {
        await ref.read(teacherProvider.notifier).loadAssignments();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final teacher = ref.watch(teacherProvider);
    final classes = teacher.classes;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teacherAccent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: GradientHeader(
                role: AppRoleStyle.teacher,
                eyebrow: 'Assigned to you',
                title: 'My Classes',
                subtitle: classes.isEmpty
                    ? 'No classes assigned yet'
                    : '${classes.length} class${classes.length == 1 ? '' : 'es'} · '
                        '${teacher.assignments.length} assignment'
                        '${teacher.assignments.length == 1 ? '' : 's'} set',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading && classes.isEmpty)
                    ...const [
                      SkeletonCard(lines: 3),
                      SizedBox(height: 12),
                      SkeletonCard(lines: 3),
                    ]
                  else if (_error != null && classes.isEmpty)
                    ErrorState(message: _error!, onRetry: _load)
                  else if (classes.isEmpty)
                    const EmptyState(
                      icon: Icons.class_outlined,
                      title: 'No classes yet',
                      message:
                          'Once your school admin assigns you a class, it will appear '
                          'here with its roster and attendance.',
                    )
                  else
                    StaggeredList(
                      count: classes.length,
                      builder: (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _classCard(classes[i], teacher.assignments),
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

  Widget _classCard(CourseScheduleModel c, List<dynamic> assignments) {
    // Resolve this class's own submission health.
    final classAssignments = assignments
        .where((a) => a.studentGroupName == c.studentGroupName)
        .toList();
    final rate = classAssignments.isEmpty
        ? null
        : classAssignments.map((a) => a.submissionRate as double).reduce((a, b) => a + b) /
            classAssignments.length *
            100;
    final pending = classAssignments
        .fold<int>(0, (s, a) => s + ((a.submittedCount - a.gradedCount).clamp(0, 9999) as int));

    final accent = _accentFor(c.studentGroupName ?? c.id);

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TeacherClassHubScreen(
            courseSchedule: c,
            studentCount: c.studentCount ?? 0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: AppRadius.brMd,
                ),
                alignment: Alignment.center,
                child: Text(
                  _monogram(c.studentGroupName ?? 'Class'),
                  style: AppText.cardTitle.copyWith(fontSize: 15, color: accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.studentGroupName ?? 'Class',
                      style: AppText.cardTitle.copyWith(fontSize: 15.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        c.courseName ?? 'Course',
                        if (c.room != null) 'Room ${c.room}',
                        if (c.startTime != null) c.startTime!,
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
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat(
                icon: Icons.people_alt_rounded,
                label: '${c.studentCount ?? 0} students',
                color: AppColors.teacherAccent,
              ),
              const SizedBox(width: 8),
              _miniStat(
                icon: Icons.assignment_rounded,
                label: '${classAssignments.length} set',
                color: AppColors.tertiary,
              ),
              if (pending > 0) ...[
                const SizedBox(width: 8),
                _miniStat(
                  icon: Icons.rate_review_rounded,
                  label: '$pending to grade',
                  color: AppColors.warningDark,
                ),
              ],
            ],
          ),
          if (rate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Submission rate',
                    style: AppText.caption.copyWith(fontSize: 11),
                  ),
                ),
                Text(
                  '${rate.toStringAsFixed(0)}%',
                  style: AppText.caption.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: rate >= 80
                        ? AppColors.successDark
                        : rate >= 60
                            ? AppColors.warningDark
                            : AppColors.dangerDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GradientBar(
              percent: rate,
              height: 7,
              gradient: rate >= 80
                  ? AppGradients.mint
                  : rate >= 60
                      ? AppGradients.amber
                      : AppGradients.rose,
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppText.caption.copyWith(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  static const List<Color> _palette = [
    AppColors.teacherAccent,
    AppColors.tertiary,
    AppColors.secondary,
    AppColors.adminAccent,
    AppColors.warning,
    AppColors.studentAccent,
  ];

  Color _accentFor(String key) => _palette[key.hashCode.abs() % _palette.length];

  String _monogram(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.length <= 2
          ? parts.first.toUpperCase()
          : parts.first.substring(0, 2).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
