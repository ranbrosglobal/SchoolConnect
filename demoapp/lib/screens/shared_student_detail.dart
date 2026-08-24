import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';
import '../state/auth_provider.dart';
import '../models/student_detail_model.dart';

/// Shared student detail view (used by teachers browsing the class roster).
/// Reads the student id (+ optional group) from the route arguments and
/// renders real attendance + grades from the live backend.
class SharedStudentDetail extends ConsumerStatefulWidget {
  const SharedStudentDetail({super.key});

  @override
  ConsumerState<SharedStudentDetail> createState() => _SharedStudentDetailState();
}

class _SharedStudentDetailState extends ConsumerState<SharedStudentDetail> {
  StudentDetailModel? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String? _course;
  String? _courseName;

  Future<void> _load() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    final studentId = args is String
        ? args
        : args is Map
            ? args['student']?.toString()
            : null;
    _course = args is Map ? args['course']?.toString() : null;
    _courseName = args is Map ? args['courseName']?.toString() : null;

    if (studentId == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await ref
          .read(demoApiServiceProvider)
          .getStudentDetail(studentId, course: _course);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Student Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                        const SizedBox(height: 12),
                        Text('Could not load student details: $_error',
                            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
          : _detail == null
              ? const Center(child: Text('No student selected.'))
              : _buildBody(context, _detail!),
    );
  }

  Widget _buildBody(BuildContext context, StudentDetailModel student) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              student.name.isNotEmpty ? student.name[0] : 'S',
              style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          student.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${student.studentGroupName ?? 'No class'} · Roll ${student.rollNumber ?? '-'}',
          style: const TextStyle(color: AppColors.outline),
          textAlign: TextAlign.center,
        ),
        if (_courseName != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_courseName',
              style: const TextStyle(
                color: AppColors.info,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.hairlineBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Overall Attendance', style: TextStyle(color: AppColors.outline)),
                      const SizedBox(height: 8),
                      Text(
                        '${student.overallAttendance.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: student.overallAttendance >= 75 ? AppColors.tertiary : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 80,
                  width: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: (student.overallAttendance / 100).clamp(0.0, 1.0),
                        strokeWidth: 8,
                        backgroundColor: AppColors.hairlineBorder,
                        color: student.overallAttendance >= 75 ? AppColors.tertiary : AppColors.error,
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Text(
                          '${student.overallAttendance.toInt()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _courseName != null ? '$_courseName Attendance' : 'Subject-wise Attendance',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (student.courseWiseAttendance.isEmpty)
          const Text('No attendance data yet.', style: TextStyle(color: AppColors.outline))
        else
          ...student.courseWiseAttendance.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(
                        '${entry.value.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (entry.value / 100).clamp(0.0, 1.0),
                    backgroundColor: AppColors.hairlineBorder,
                    color: entry.value >= 75 ? AppColors.tertiary : AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 24),
        Text(
          'Grades',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (student.grades.isEmpty)
          const Text('No grades yet.', style: TextStyle(color: AppColors.outline))
        else
          ...student.grades.map((g) {
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.hairlineBorder),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: g.isGraded ? AppColors.tertiary.withValues(alpha: 0.1) : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    g.isGraded ? '${g.grade!.toInt()}' : '-',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: g.isGraded ? AppColors.tertiary : AppColors.outline,
                    ),
                  ),
                ),
                title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  [
                    if (g.courseName != null) g.courseName!,
                    if (g.dueDate != null) DateFormat('MMM d, yyyy').format(g.dueDate!),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            );
          }),
        const SizedBox(height: 32),
      ],
    );
  }
}
