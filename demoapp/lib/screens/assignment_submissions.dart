import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../state/teacher_provider.dart';

/// Submissions list for the teacher's currently selected assignment.
/// Renders the same submission cards as the detail screen, with quick
/// grade/return actions, for flows that land on a dedicated submissions page.
class AssignmentSubmissions extends ConsumerWidget {
  const AssignmentSubmissions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(teacherProvider);
    final assignment = state.selectedAssignment;
    final submissions = state.submissions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Submissions', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: assignment == null
          ? const Center(child: Text('No assignment selected.'))
          : state.isLoading && submissions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : submissions.isEmpty
                  ? const Center(child: Text('No submissions yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: submissions.length,
                      itemBuilder: (context, index) {
                        final submission = submissions[index];
                        final isGraded = submission.status == 'Graded';
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.hairlineBorder),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                (submission.studentName?.isNotEmpty ?? false) ? submission.studentName![0] : '?',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              submission.studentName ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              submission.fileName ?? 'No attachment',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: (isGraded ? AppColors.tertiary : AppColors.info).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isGraded ? 'Graded: ${submission.grade}' : (submission.status ?? 'Submitted'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isGraded ? AppColors.tertiary : AppColors.info,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
