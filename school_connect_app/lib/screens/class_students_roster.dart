import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../state/teacher_provider.dart';
import '../services/export_service.dart';
import '../widgets/export_sheet.dart';

class ClassStudentsRoster extends ConsumerWidget {
  const ClassStudentsRoster({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(teacherProvider);
    final students = state.currentClassStudents;
    final selectedClass = state.selectedClass;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Class Roster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (selectedClass != null)
              Text(
                '${selectedClass.courseName} - ${selectedClass.studentGroupName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70),
              ),
          ],
        ),
        titleSpacing: 8,
        backgroundColor: AppColors.info,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed:
                state.isLoading || students.isEmpty ? null : () => _export(context, ref, state),
            icon: const Icon(Icons.ios_share, size: 16, color: Colors.white),
            label: const Text('Export',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            style: TextButton.styleFrom(
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 40),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: state.isLoading && students.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : students.isEmpty
              ? const Center(child: Text('No students found in this class.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(24.0),
                  itemCount: students.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.hairlineBorder),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        child: Text(student.rollNumber ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                      ),
                      title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(student.email ?? 'No email', style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/SharedStudentDetail',
                          arguments: {
                            'student': student.id,
                            'group': selectedClass?.studentGroup,
                            'course': selectedClass?.course,
                            'courseName': selectedClass?.courseName,
                          },
                        );
                      },
                    );
                  },
                ),
    );
  }
}

Future<void> _export(BuildContext context, WidgetRef ref, TeacherState state) async {
  final selectedClass = state.selectedClass;
  if (selectedClass == null || state.currentClassStudents.isEmpty) return;

  final data = AttendanceExportData(
    className: selectedClass.studentGroupName ?? selectedClass.displayName,
    subject: selectedClass.courseName ?? 'Class',
    teacher: selectedClass.instructorName ?? '',
    room: selectedClass.room ?? '',
    date: DateTime.now(),
    rows: [
      for (final s in state.currentClassStudents)
        AttendanceExportRow(
          roll: s.rollNumber ?? '',
          name: s.name,
        ),
    ],
  );
  await showExportSheet(context, data);
}
