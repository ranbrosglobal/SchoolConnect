import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/teacher_provider.dart';
import '../../models/course_schedule_model.dart';
import '../../models/student_model.dart';
import '../../services/export_service.dart';
import '../../widgets/export_sheet.dart';
import '../common/student_detail_screen.dart';

class TeacherClassStudentsScreen extends ConsumerStatefulWidget {
  final CourseScheduleModel courseSchedule;

  const TeacherClassStudentsScreen({super.key, required this.courseSchedule});

  @override
  ConsumerState<TeacherClassStudentsScreen> createState() =>
      _TeacherClassStudentsScreenState();
}

class _TeacherClassStudentsScreenState
    extends ConsumerState<TeacherClassStudentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherProvider.notifier).selectClass(widget.courseSchedule);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherProvider);
    final students = state.currentClassStudents;
    // Sort by roll number when available
    final sorted = [...students]..sort((a, b) {
        final ra = int.tryParse(a.rollNumber ?? '');
        final rb = int.tryParse(b.rollNumber ?? '');
        if (ra != null && rb != null) return ra.compareTo(rb);
        return (a.rollNumber ?? '').compareTo(b.rollNumber ?? '');
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.courseSchedule.studentGroupName ?? 'Class Students',
        ),
        actions: [
          IconButton(
            tooltip: 'Export class',
            icon: const Icon(Icons.ios_share),
            onPressed: state.currentClassStudents.isEmpty
                ? null
                : () => _showExportSheet(sorted),
          ),
        ],
      ),
      body: Column(
        children: [
          // Class summary header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.groups,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.courseSchedule.courseName ?? 'Course',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.courseSchedule.studentGroupName ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${sorted.length} students',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Student list
          Expanded(
            child: state.isLoading && students.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : sorted.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No students in this class',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Students added to this class will appear here.',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(teacherProvider.notifier)
                            .selectClass(widget.courseSchedule),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            return _buildStudentRow(sorted[index], index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportSheet(List<StudentModel> students) async {
    final data = AttendanceExportData(
      className: widget.courseSchedule.studentGroupName ??
          widget.courseSchedule.studentGroup ??
          'Class',
      subject: widget.courseSchedule.courseName ??
          widget.courseSchedule.course ??
          'Subject',
      teacher: widget.courseSchedule.instructorName ?? 'Teacher',
      room: widget.courseSchedule.room ?? '',
      date: DateTime.now(),
      rows: [
        for (var i = 0; i < students.length; i++)
          AttendanceExportRow(
            roll: students[i].rollNumber ?? '${i + 1}',
            name: students[i].name,
            status: '', // roster mode: no Status column
          ),
      ],
    );
    await showExportSheet(context, data);
  }

  Widget _buildStudentRow(StudentModel student, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shadowColor: const Color(0xFF1976D2).withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(
                studentId: student.id,
                studentGroup: widget.courseSchedule.studentGroup,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                student.rollNumber ?? '—',
                style: const TextStyle(
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            student.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            student.email ?? 'No email',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          trailing: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
