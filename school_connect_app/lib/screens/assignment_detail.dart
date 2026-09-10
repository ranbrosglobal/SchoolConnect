import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';
import '../state/teacher_provider.dart';
import '../models/assignment_submission_model.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AssignmentDetail extends ConsumerStatefulWidget {
  const AssignmentDetail({super.key});

  @override
  ConsumerState<AssignmentDetail> createState() => _AssignmentDetailState();
}

class _AssignmentDetailState extends ConsumerState<AssignmentDetail> {
  void _gradeSubmission(AssignmentSubmissionModel submission) {
    double grade = submission.grade ?? 100;
    String feedback = submission.feedback ?? '';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Grade ${submission.studentName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Grade (0-100)'),
                controller: TextEditingController(text: grade.toString()),
                onChanged: (v) => grade = double.tryParse(v) ?? 100,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(labelText: 'Feedback'),
                controller: TextEditingController(text: feedback),
                onChanged: (v) => feedback = v,
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                ref.read(teacherProvider.notifier).gradeSubmission(
                  submission: submission.id,
                  grade: grade,
                  feedback: feedback,
                ).then((success) {
                  if (success && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Graded successfully!')));
                  }
                });
              },
              child: const Text('Save Grade'),
            ),
          ],
        );
      },
    );
  }

  void _returnSubmission(AssignmentSubmissionModel submission) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Return Submission?'),
          content: const Text('This will clear the grade and allow the student to resubmit.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                ref.read(teacherProvider.notifier).unsubmitSubmission(submission.id).then((success) {
                  if (success && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submission returned.')));
                  }
                });
              },
              child: const Text('Return', style: TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherProvider);
    final assignment = state.selectedAssignment;
    final submissions = state.submissions;

    if (assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No assignment selected.')),
      );
    }

    final isPastDue = assignment.dueDate != null && assignment.dueDate!.isBefore(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Submissions', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: state.isLoading && submissions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 14, color: isPastDue ? AppColors.error : AppColors.outline),
                            const SizedBox(width: 6),
                            Text(
                              'Due: ${assignment.dueDate != null ? DateFormat('MMM d, yyyy').format(assignment.dueDate!) : 'N/A'}',
                              style: TextStyle(color: isPastDue ? AppColors.error : AppColors.outline, fontSize: 13, fontWeight: isPastDue ? FontWeight.bold : FontWeight.normal),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: _buildStatCard('Total', assignment.totalStudents.toString(), Colors.blue)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStatCard('Submitted', assignment.submittedCount.toString(), Colors.orange)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStatCard('Graded', assignment.gradedCount.toString(), Colors.green)),
                          ],
                        ),
                      ],
                    ).animate().fade().slideY(begin: 0.1),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final submission = submissions[index];
                        final isGraded = submission.status == 'Graded';
                        final isReturned = submission.status == 'Returned';
                        
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.hairlineBorder),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        submission.studentName ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isGraded ? Colors.green.withValues(alpha: 0.1) : (isReturned ? Colors.red.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        submission.status ?? 'Pending',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isGraded ? Colors.green : (isReturned ? Colors.red : AppColors.primary),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (submission.file != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.attach_file, size: 14, color: AppColors.outline),
                                      const SizedBox(width: 4),
                                      Text(submission.fileName ?? 'attachment', style: const TextStyle(color: AppColors.outline, fontSize: 12)),
                                    ],
                                  ),
                                ],
                                if (isGraded) ...[
                                  const SizedBox(height: 8),
                                  Text('Grade: ${submission.grade}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  if (submission.feedback != null) Text('Feedback: ${submission.feedback}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (submission.status != 'Returned')
                                      TextButton(
                                        onPressed: () => _returnSubmission(submission),
                                        child: const Text('Return', style: TextStyle(color: AppColors.error)),
                                      ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _gradeSubmission(submission),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                      child: Text(isGraded ? 'Edit Grade' : 'Grade'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: submissions.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
