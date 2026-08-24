import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';
import '../state/student_provider.dart';
import '../models/assignment_model.dart';
import 'student/assignment_detail_screen.dart';

class AssignmentsList extends ConsumerWidget {
  const AssignmentsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentState = ref.watch(studentProvider);
    final assignments = studentState.assignments;
    final isLoading = studentState.isLoading;

    if (isLoading && assignments.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pendingAssignments = assignments.where((a) {
      return !a.submitted || a.submissionStatus == 'Returned';
    }).toList();

    final completedAssignments = assignments.where((a) {
      return a.submitted && a.submissionStatus != 'Returned';
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Assignments', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.outline,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: 'Pending'),
                  Tab(text: 'Completed'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildList(context, pendingAssignments),
                  _buildList(context, completedAssignments),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<AssignmentModel> assignments) {
    if (assignments.isEmpty) {
      return const Center(child: Text('No assignments found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24.0),
      itemCount: assignments.length,
      itemBuilder: (context, index) {
        final assignment = assignments[index];
        
        Color statusColor = AppColors.primary;
        String statusText = 'Pending';
        
        if (assignment.submissionStatus == 'Submitted') {
          statusColor = AppColors.info;
          statusText = 'Submitted';
        } else if (assignment.submissionStatus == 'Graded') {
          statusColor = AppColors.tertiary;
          statusText = 'Graded (${assignment.grade}/100)';
        } else if (assignment.submissionStatus == 'Returned') {
          statusColor = AppColors.error;
          statusText = 'Returned';
        } else if (assignment.isOverdue) {
          statusColor = AppColors.error;
          statusText = 'Overdue';
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.hairlineBorder),
          ),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AssignmentDetailScreen(assignment: assignment),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          assignment.courseName ?? 'Unknown Course',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    assignment.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.outline),
                      const SizedBox(width: 6),
                      Text(
                        'Due: ${assignment.dueDate != null ? DateFormat('MMM d, yyyy').format(assignment.dueDate!) : 'N/A'}',
                        style: TextStyle(color: AppColors.outline, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
