import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/assignment_model.dart';
import '../../state/teacher_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';
import 'assignment_detail_screen.dart';
import 'create_assignment_screen.dart';

enum _Filter { all, toGrade, graded, upcoming }

/// Every assignment the teacher has set, filterable by what needs them.
/// Opening one goes to its submissions and grading screen.
class TeacherAssignmentsScreen extends ConsumerStatefulWidget {
  final bool startWithToGrade;

  const TeacherAssignmentsScreen({super.key, this.startWithToGrade = false});

  @override
  ConsumerState<TeacherAssignmentsScreen> createState() =>
      _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState
    extends ConsumerState<TeacherAssignmentsScreen> {
  late _Filter _filter =
      widget.startWithToGrade ? _Filter.toGrade : _Filter.all;
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
      await ref.read(teacherProvider.notifier).loadAssignments();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateAssignmentScreen()),
    );
    if (created == true) await _load();
  }

  static int _pending(AssignmentModel a) =>
      (a.submittedCount - a.gradedCount).clamp(0, 999999).toInt();

  bool _matches(AssignmentModel a) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.toGrade:
        return _pending(a) > 0;
      case _Filter.graded:
        return a.submittedCount > 0 && _pending(a) == 0;
      case _Filter.upcoming:
        return a.dueDate != null && a.dueDate!.isAfter(DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignments = ref.watch(teacherProvider).assignments;
    final toGrade = assignments.where((a) => _pending(a) > 0).length;
    final visible = assignments.where(_matches).toList()
      ..sort((a, b) => _pending(b).compareTo(_pending(a)));

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.teacherAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text(
          'Upload',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientHeader(
            role: AppRoleStyle.teacher,
            showBack: true,
            eyebrow: 'Grading',
            title: 'Assignments',
            subtitle: toGrade == 0
                ? 'Everything is graded'
                : '$toGrade assignment${toGrade == 1 ? '' : 's'} need grading',
          ),
          _filterRow(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.teacherAccent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
                children: [
                  if (_loading && assignments.isEmpty)
                    const SkeletonCard(lines: 3)
                  else if (_error != null && assignments.isEmpty)
                    ErrorState(message: _error!, onRetry: _load)
                  else if (visible.isEmpty)
                    EmptyState(
                      icon: Icons.assignment_outlined,
                      title: assignments.isEmpty
                          ? 'No assignments yet'
                          : 'Nothing in this view',
                      message: assignments.isEmpty
                          ? 'Assignments you set for your classes will appear here.'
                          : 'Try another filter to see more assignments.',
                    )
                  else
                    for (final a in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _card(a),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow() {
    const items = <(_Filter, String)>[
      (_Filter.all, 'All'),
      (_Filter.toGrade, 'To grade'),
      (_Filter.graded, 'Graded'),
      (_Filter.upcoming, 'Upcoming'),
    ];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (filter, label) = items[i];
          final selected = _filter == filter;
          return Pressable(
            onTap: () => setState(() => _filter = filter),
            borderRadius: AppRadius.brPill,
            child: AnimatedContainer(
              duration: AppMotion.base,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.teacherAccent : AppColors.surface,
                borderRadius: AppRadius.brPill,
                border: Border.all(
                  color: selected
                      ? AppColors.teacherAccent
                      : AppColors.hairlineBorder,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppText.cardTitle.copyWith(
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.inkSoft,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(AssignmentModel a) {
    final rate = a.submissionRate * 100;
    final pending = _pending(a);
    final due = a.dueDate == null
        ? 'No due date'
        : 'Due ${DateFormat('d MMM').format(a.dueDate!)}';

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TeacherAssignmentDetailScreen(assignment: a),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 3),
                    Text(
                      '${a.studentGroupName ?? 'Class'}  ·  $due',
                      style: AppText.caption.copyWith(fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (pending > 0)
                StatusPill(
                  label: '$pending to grade',
                  tone: pending > 10 ? PillTone.danger : PillTone.warning,
                  dense: true,
                )
              else
                const StatusPill(
                  label: 'Graded',
                  tone: PillTone.success,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${a.submittedCount} of ${a.totalStudents} submitted',
                  style: AppText.caption.copyWith(fontSize: 11.5),
                ),
              ),
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: AppText.caption.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
    );
  }
}
