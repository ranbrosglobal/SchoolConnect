import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/course_schedule_model.dart';
import 'attendance_marking_screen.dart';
import 'attendance_history_screen.dart';
import 'class_students_screen.dart';

/// Landing screen for one class: everything the teacher can do with it —
/// mark today's attendance, browse past attendance, view the roster.
/// Replaces the old hardcoded demo detail screen.
class TeacherClassHubScreen extends StatelessWidget {
  final CourseScheduleModel courseSchedule;
  final int studentCount;

  const TeacherClassHubScreen({
    super.key,
    required this.courseSchedule,
    this.studentCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final title = courseSchedule.studentGroupName ?? 'Class';
    final subject = courseSchedule.courseName ?? courseSchedule.course ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subject,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        '$studentCount students'
                        '${(courseSchedule.room ?? '').isNotEmpty ? ' · Room ${courseSchedule.room}' : ''}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06),
          const SizedBox(height: 18),
          _HubAction(
            icon: Icons.fact_check_outlined,
            color: const Color(0xFF16A34A),
            title: 'Mark Attendance',
            subtitle: "Mark or edit today's register — defaults to Present",
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AttendanceMarkingScreen(courseSchedule: courseSchedule),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _HubAction(
            icon: Icons.history_rounded,
            color: const Color(0xFFEA580C),
            title: 'Attendance History',
            subtitle:
                'Past weeks, months, quarter, year or any custom range',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AttendanceHistoryScreen(courseSchedule: courseSchedule),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _HubAction(
            icon: Icons.groups_outlined,
            color: const Color(0xFF2563EB),
            title: 'Class Roster',
            subtitle: 'All enrolled students and their details',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    TeacherClassStudentsScreen(courseSchedule: courseSchedule),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 19),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Attendance is saved per day — each new day starts fresh, '
                    'and past days can always be corrected from here.',
                    style: TextStyle(
                        fontSize: 12.5, height: 1.4, color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
