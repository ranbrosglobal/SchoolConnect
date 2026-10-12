import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/assignment_model.dart';
import '../../state/student_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';
import 'assignment_detail_screen.dart';

/// The student's full assignment list, grouped by where the work stands.
class StudentAssignmentsScreen extends ConsumerStatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  ConsumerState<StudentAssignmentsScreen> createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState
    extends ConsumerState<StudentAssignmentsScreen> {
  int _tab = 0;
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
      await ref.read(studentProvider.notifier).loadDashboard();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  List<AssignmentModel> get _all {
    final list = [...ref.watch(studentProvider).assignments];
    list.sort((a, b) {
      final ad = a.dueDate ?? a.creation ?? DateTime(2100);
      final bd = b.dueDate ?? b.creation ?? DateTime(2100);
      return ad.compareTo(bd);
    });
    return list;
  }

  List<AssignmentModel> get _filtered {
    final all = _all;
    return switch (_tab) {
      1 => all.where((a) => !a.isSubmitted && !a.isOverdue).toList(),
      2 => all.where((a) => a.isSubmitted && !a.isGraded).toList(),
      3 => all.where((a) => a.isGraded).toList(),
      _ => all,
    };
  }

  @override
  Widget build(BuildContext context) {
    final counts = [
      _all.length,
      _all.where((a) => !a.isSubmitted && !a.isOverdue).length,
      _all.where((a) => a.isSubmitted && !a.isGraded).length,
      _all.where((a) => a.isGraded).length,
    ];
    final items = _filtered;

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
                eyebrow: '${_all.length} total · '
                    '${_all.where((a) => a.isOverdue && !a.isSubmitted).length} overdue',
                title: 'Assignments',
                subtitle: 'Everything your teachers have set, in one place',
                showBack: true,
              ),
            ),
            SliverToBoxAdapter(child: _tabs(counts)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading && _all.isEmpty)
                    ...const [
                      SkeletonCard(lines: 3),
                      SizedBox(height: 12),
                      SkeletonCard(lines: 3),
                    ]
                  else if (_error != null && _all.isEmpty)
                    ErrorState(message: _error!, onRetry: _load)
                  else if (items.isEmpty)
                    EmptyState(
                      icon: Icons.task_alt_rounded,
                      title: _emptyTitle,
                      message: _emptyMessage,
                      accent: AppColors.success,
                    )
                  else
                    StaggeredList(
                      count: items.length,
                      builder: (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _card(items[i]),
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

  String get _emptyTitle => switch (_tab) {
        1 => 'Nothing to do right now',
        2 => 'Nothing awaiting a grade',
        3 => 'No graded work yet',
        _ => 'No assignments yet',
      };

  String get _emptyMessage => switch (_tab) {
        1 => 'You have handed in everything with an upcoming deadline.',
        2 => 'Your submissions have all been graded.',
        3 => 'Graded work appears here once your teacher marks it.',
        _ => 'Assignments set by your teachers will show up here.',
      };

  Widget _tabs(List<int> counts) {
    const labels = ['All', 'To do', 'Submitted', 'Graded'];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: AppColors.hairlineBorder),
        boxShadow: AppShadows.soft(),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => setState(() => _tab = i),
                borderRadius: AppRadius.brPill,
                child: AnimatedContainer(
                  duration: AppMotion.base,
                  curve: AppMotion.emphasized,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: _tab == i ? AppGradients.student : null,
                    borderRadius: AppRadius.brPill,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        labels[i],
                        style: AppText.caption.copyWith(
                          fontSize: 11.5,
                          color: _tab == i ? Colors.white : AppColors.inkSoft,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (counts[i] > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _tab == i
                                ? Colors.white.withValues(alpha: 0.25)
                                : AppColors.surfaceContainerHigh,
                            borderRadius: AppRadius.brPill,
                          ),
                          child: Text(
                            '${counts[i]}',
                            style: AppText.caption.copyWith(
                              fontSize: 9.5,
                              color: _tab == i ? Colors.white : AppColors.inkSoft,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(AssignmentModel a) {
    final overdue = a.isOverdue && !a.isSubmitted;
    final accent = overdue
        ? AppColors.danger
        : a.isGraded
            ? AppColors.success
            : a.isSubmitted
                ? AppColors.tertiary
                : AppColors.studentAccent;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      borderColor: overdue ? AppColors.danger.withValues(alpha: 0.30) : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AssignmentDetailScreen(assignment: a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(
                  a.isSubmitted
                      ? Icons.check_circle_outline_rounded
                      : Icons.assignment_outlined,
                  size: 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: AppText.cardTitle.copyWith(fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        a.courseName ?? a.course ?? 'General',
                        if (a.studentGroupName != null) a.studentGroupName!,
                      ].join('  ·  '),
                      style: AppText.caption.copyWith(fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusPill(a),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.brSm,
            ),
            child: Row(
              children: [
                Icon(Icons.event_rounded, size: 14, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    a.dueDate == null
                        ? 'No due date'
                        : overdue
                            ? 'Was due ${DateFormat('EEE d MMM').format(a.dueDate!)}'
                            : 'Due ${DateFormat('EEE d MMM').format(a.dueDate!)}',
                    style: AppText.caption.copyWith(fontSize: 11.5, color: AppColors.inkSoft),
                  ),
                ),
                Text(
                  _relative(a),
                  style: AppText.caption.copyWith(
                    fontSize: 11.5,
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (a.feedback != null && a.feedback!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.mode_comment_outlined,
                    size: 14, color: AppColors.inkFaint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    a.feedback!,
                    style: AppText.caption.copyWith(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(AssignmentModel a) {
    if (a.isGraded) {
      return StatusPill(
        label: a.displayGrade,
        tone: PillTone.success,
        icon: Icons.workspace_premium_rounded,
        dense: true,
      );
    }
    if (a.isSubmitted) {
      return const StatusPill(label: 'Submitted', tone: PillTone.info, dense: true);
    }
    if (a.isOverdue) {
      return const StatusPill(label: 'Overdue', tone: PillTone.danger, dense: true);
    }
    return const StatusPill(label: 'To do', tone: PillTone.accent, dense: true);
  }

  String _relative(AssignmentModel a) {
    if (a.dueDate == null) return '';
    final now = DateTime.now();
    final due = DateTime(a.dueDate!.year, a.dueDate!.month, a.dueDate!.day);
    final today = DateTime(now.year, now.month, now.day);
    final days = due.difference(today).inDays;
    if (days < 0) return '${days.abs()}d late';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return '${days}d left';
  }
}
