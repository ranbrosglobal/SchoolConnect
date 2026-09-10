import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';
import '../state/teacher_provider.dart';
import '../models/assignment_model.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TeacherAssignments extends ConsumerStatefulWidget {
  const TeacherAssignments({super.key});

  @override
  ConsumerState<TeacherAssignments> createState() => _TeacherAssignmentsState();
}

class _TeacherAssignmentsState extends ConsumerState<TeacherAssignments> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherProvider.notifier).loadAssignments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherProvider);
    final assignments = state.assignments;
    final isLoading = state.isLoading;
    final error = state.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Assignments', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: error != null
          ? Center(child: Text('Error: $error', style: const TextStyle(color: Colors.red)))
          : isLoading && assignments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : assignments.isEmpty
              ? const Center(child: Text('No assignments found. Tap + to create one.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(24.0),
                  itemCount: assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = assignments[index];
                    return _buildAssignmentCard(context, assignment);
                  },
                ).animate().fade().slideY(begin: 0.1),
    );
  }

  Widget _buildAssignmentCard(BuildContext context, AssignmentModel assignment) {
    final isPastDue = assignment.dueDate != null && assignment.dueDate!.isBefore(DateTime.now());
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.hairlineBorder),
      ),
      child: InkWell(
        onTap: () {
          ref.read(teacherProvider.notifier).loadSubmissions(assignment).then((_) {
            Navigator.pushNamed(context, '/AssignmentDetail');
          });
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
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      assignment.studentGroupName ?? 'Unknown Group',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.info),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 14, color: AppColors.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${assignment.submittedCount}/${assignment.totalStudents}',
                        style: const TextStyle(color: AppColors.outline, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: assignment.totalStudents > 0 ? (assignment.submittedCount / assignment.totalStudents) : 0,
                backgroundColor: AppColors.hairlineBorder,
                color: AppColors.info,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
