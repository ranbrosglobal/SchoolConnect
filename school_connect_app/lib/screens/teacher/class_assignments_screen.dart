import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/assignment_model.dart';
import '../../models/assignment_material.dart';
import '../../models/course_schedule_model.dart';
import '../../state/teacher_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/assignment_material_tile.dart';
import '../../widgets/kit/kit.dart';
import 'assignment_detail_screen.dart';
import 'create_assignment_screen.dart';

/// Everything set for one class: the work, the due dates and the material the
/// teacher shared (PDFs, images, video clips and voice notes). Uploading from
/// here always lands in this class, so a teacher never has to re-pick it.
class ClassAssignmentsScreen extends ConsumerStatefulWidget {
  final CourseScheduleModel courseSchedule;

  const ClassAssignmentsScreen({super.key, required this.courseSchedule});

  @override
  ConsumerState<ClassAssignmentsScreen> createState() =>
      _ClassAssignmentsScreenState();
}

class _ClassAssignmentsScreenState
    extends ConsumerState<ClassAssignmentsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await ref.read(teacherProvider.notifier).loadAssignments();
    if (mounted) setState(() => _loading = false);
  }

  String get _className =>
      widget.courseSchedule.studentGroupName ?? 'This class';

  bool _belongs(AssignmentModel a) {
    final key = widget.courseSchedule.classKey;
    final group = widget.courseSchedule.studentGroup;
    return a.studentGroup == key || (group != null && a.studentGroup == group);
  }

  List<AssignmentModel> _classAssignments(List<AssignmentModel> all) {
    final list = all.where(_belongs).toList();
    list.sort((a, b) {
      final ad = a.dueDate ?? a.creation ?? DateTime(2100);
      final bd = b.dueDate ?? b.creation ?? DateTime(2100);
      return ad.compareTo(bd);
    });
    return list;
  }

  Future<void> _upload() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CreateAssignmentScreen(courseSchedule: widget.courseSchedule),
      ),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherProvider);
    final assignments = _classAssignments(state.assignments);
    final materials = assignments.fold<int>(
      0,
      (sum, a) => sum + a.materials.length,
    );
    final pending = assignments.fold<int>(
      0,
      (sum, a) =>
          sum + (a.submittedCount - a.gradedCount).clamp(0, 999999).toInt(),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        backgroundColor: AppColors.teacherAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text(
          'Upload',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teacherAccent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: GradientHeader(
                role: AppRoleStyle.teacher,
                showBack: true,
                eyebrow: _className,
                title: 'Assignments',
                subtitle: assignments.isEmpty
                    ? 'Share work and material with ${widget.courseSchedule.studentCountLabel()}'
                    : '${assignments.length} assignment${assignments.length == 1 ? '' : 's'} · '
                          '$materials material${materials == 1 ? '' : 's'}'
                          '${pending > 0 ? ' · $pending to grade' : ''}',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _uploadHint(),
                  const SizedBox(height: 16),
                  if (_loading && assignments.isEmpty) ...const [
                    SkeletonCard(lines: 3),
                    SizedBox(height: 12),
                    SkeletonCard(lines: 3),
                  ] else if (state.error != null && assignments.isEmpty)
                    ErrorState(message: state.error!, onRetry: _load)
                  else if (assignments.isEmpty)
                    Column(
                      children: [
                        EmptyState(
                          icon: Icons.assignment_add,
                          title: 'No assignments yet',
                          message:
                              'Upload a worksheet, photos, a video or a voice '
                              'note for $_className. Students see it instantly '
                              'in their assignments.',
                          actionLabel: 'Upload assignment',
                          onAction: _upload,
                          accent: AppColors.teacherAccent,
                        ),
                      ],
                    )
                  else
                    for (final assignment in assignments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _card(assignment),
                      ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.teacherAccent.withValues(alpha: 0.07),
        borderRadius: AppRadius.brLg,
        border: Border.all(
          color: AppColors.teacherAccent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.teacherAccent.withValues(alpha: 0.14),
              borderRadius: AppRadius.brSm,
            ),
            child: const Icon(
              Icons.file_upload_outlined,
              size: 19,
              color: AppColors.teacherAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload anything the class needs',
                  style: AppText.cardTitle.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  'PDF · images · video · voice notes · documents. '
                  'Up to $kMaxMaterialsPerAssignment files, 20 MB each.',
                  style: AppText.caption.copyWith(fontSize: 11.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(AssignmentModel a) {
    final pending = (a.submittedCount - a.gradedCount).clamp(0, 999999).toInt();
    final overdue = a.isOverdue;
    final due = a.dueDate == null
        ? 'No due date'
        : overdue
        ? 'Was due ${DateFormat('d MMM').format(a.dueDate!)}'
        : 'Due ${DateFormat('EEE d MMM').format(a.dueDate!)}';

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TeacherAssignmentDetailScreen(assignment: a),
        ),
      ),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${a.courseName ?? a.course ?? 'General'}  ·  $due',
                      style: AppText.caption.copyWith(
                        fontSize: 11.5,
                        color: overdue ? AppColors.danger : AppColors.inkSoft,
                        fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (pending > 0)
                StatusPill(
                  label: '$pending to grade',
                  tone: pending > 10 ? PillTone.danger : PillTone.warning,
                  dense: true,
                )
              else
                StatusPill(
                  label: overdue ? 'Closed' : 'Up to date',
                  tone: overdue ? PillTone.neutral : PillTone.success,
                  dense: true,
                ),
            ],
          ),
          if (a.hasMaterials) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final material in a.materials.take(3))
                  _materialChip(material),
                if (a.materials.length > 3)
                  StatusPill(
                    label: '+${a.materials.length - 3}',
                    tone: PillTone.neutral,
                    dense: true,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${a.submittedCount} of ${a.totalStudents} submitted',
                  style: AppText.caption.copyWith(fontSize: 11.5),
                ),
              ),
              Text(
                '${(a.submissionRate * 100).toStringAsFixed(0)}%',
                style: AppText.caption.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GradientBar(
            percent: a.submissionRate * 100,
            height: 6,
            gradient: a.submissionRate >= 0.8
                ? AppGradients.mint
                : a.submissionRate >= 0.6
                ? AppGradients.amber
                : AppGradients.rose,
          ),
        ],
      ),
    );
  }

  Widget _materialChip(AssignmentMaterial material) {
    final color = materialColor(material.kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(materialIcon(material.kind), size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              material.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on CourseScheduleModel {
  String studentCountLabel() {
    final count = studentCount;
    return count == null || count <= 0 ? 'the class' : '$count students';
  }
}
