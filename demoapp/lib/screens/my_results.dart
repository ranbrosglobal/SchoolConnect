import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../state/student_provider.dart';
import '../models/assignment_model.dart';
import '../utils/responsive.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MyResults extends ConsumerWidget {
  const MyResults({super.key});

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

    final gradedAssignments = assignments.where((a) {
      return a.submissionStatus == 'Graded';
    }).toList();

    double totalScore = 0;
    if (gradedAssignments.isNotEmpty) {
      for (var a in gradedAssignments) {
        totalScore += (a.grade ?? 0);
      }
      totalScore = totalScore / gradedAssignments.length;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Results', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ResponsiveCenter(
              maxWidth: 760,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAverageCard(context, totalScore),
                    const SizedBox(height: 32),
                    _buildSectionTitle(context, 'Recent Grades'),
                    const SizedBox(height: 16),
                    if (gradedAssignments.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('No graded assignments yet.', style: TextStyle(color: AppColors.outline)),
                        ),
                      )
                    else
                      ...gradedAssignments.map((a) => _buildGradeCard(context, a)),
                  ],
                ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageCard(BuildContext context, double score) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.hairlineBorder),
      ),
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Average Score',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  score > 0 ? 'Great Job!' : 'Keep it up!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 100,
              width: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.white24,
                    color: AppColors.secondaryContainer,
                    strokeCap: StrokeCap.round,
                  ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
                  Center(
                    child: Text(
                      '${score.toInt()}%',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          height: 3,
          width: 40,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildGradeCard(BuildContext context, AssignmentModel assignment) {
    final grade = assignment.grade ?? 0.0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.hairlineBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.courseName ?? 'Unknown Course',
                        style: const TextStyle(fontSize: 12, color: AppColors.outline, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assignment.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${grade.toInt()}/100',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.tertiary),
                  ),
                ),
              ],
            ),
            if (assignment.feedback != null && assignment.feedback!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: AppColors.primary, width: 4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        assignment.feedback!,
                        style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
