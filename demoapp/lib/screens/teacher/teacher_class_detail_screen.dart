import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_model.dart';
import '../../models/course_schedule_model.dart';
import '../../models/student_model.dart';
import '../../state/auth_provider.dart';
import '../../services/export_service.dart';
import '../../widgets/export_sheet.dart';
import 'attendance_marking_screen.dart';
import 'teacher_attendance_history_screen.dart';

/// Detail screen for a single class the teacher teaches.  Shows the class
/// header, quick-action buttons (Mark Attendance, Attendance History, Export),
/// and a summary grid.
class TeacherClassDetailScreen extends ConsumerStatefulWidget {
  final String className;
  final String subject;
  final String? courseScheduleId;
  final String? studentGroupId;

  const TeacherClassDetailScreen({
    super.key,
    required this.className,
    required this.subject,
    this.courseScheduleId,
    this.studentGroupId,
  });

  @override
  ConsumerState<TeacherClassDetailScreen> createState() =>
      _TeacherClassDetailScreenState();
}

class _TeacherClassDetailScreenState
    extends ConsumerState<TeacherClassDetailScreen> {
  List<StudentModel> _students = [];
  List<AttendanceModel> _recentAttendance = [];
  bool _loading = true;
  int _totalDays = 0;
  double _avgAttendance = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(demoServiceProvider);

      // Get students for this class
      final groupId = widget.studentGroupId ?? '';
      if (groupId.isNotEmpty) {
        _students = service.getClassStudents(groupId);
      }

      // Get recent attendance for stats
      final csId = widget.courseScheduleId ?? '';
      if (csId.isNotEmpty) {
        _recentAttendance = service.getAttendanceForCourse(
          courseSchedule: csId,
          studentGroup: groupId,
        );
        // Count unique dates
        final dates = <String>{};
        for (final a in _recentAttendance) {
          if (a.date != null) {
            dates.add(
                '${a.date!.year}-${a.date!.month}-${a.date!.day}');
          }
        }
        _totalDays = dates.length;

        // Calculate average attendance
        final presentCount =
            _recentAttendance.where((a) => a.status == AttendanceStatus.present).length;
        _avgAttendance = _recentAttendance.isEmpty
            ? 0
            : (100 * presentCount / _recentAttendance.length);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  CourseScheduleModel? _findCourseSchedule() {
    final service = ref.read(demoServiceProvider);
    final auth = ref.read(authProvider);
    final instructorId = auth.user?.instructorId;
    if (instructorId == null) return null;
    final classes = service.getMyClasses(instructorId);
    if (widget.courseScheduleId != null) {
      final matches = classes.where((c) => c.id == widget.courseScheduleId);
      if (matches.isNotEmpty) return matches.first;
    }
    // Fallback: find by class name
    final matches = classes.where((c) =>
        (c.studentGroupName ?? '').toLowerCase() ==
        widget.className.toLowerCase());
    return matches.isNotEmpty ? matches.first : null;
  }

  void _openMarkAttendance() {
    final cs = _findCourseSchedule();
    if (cs == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course schedule not found for this class.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AttendanceMarkingScreen(courseSchedule: cs)),
    );
  }

  void _openAttendanceHistory() {
    final csId = widget.courseScheduleId ?? '';
    final gId = widget.studentGroupId ?? '';
    if (csId.isEmpty || gId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class data not fully loaded yet.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherAttendanceHistoryScreen(
          className: widget.className,
          subject: widget.subject,
          courseScheduleId: csId,
          studentGroupId: gId,
        ),
      ),
    );
  }

  Future<void> _showExportSheet() async {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students loaded yet to export.')),
      );
      return;
    }
    // Export today's attendance summary
    final data = AttendanceExportData(
      className: widget.className,
      subject: widget.subject,
      teacher: _findCourseSchedule()?.instructorName ?? 'Teacher',
      date: DateTime.now(),
      rows: [
        for (var i = 0; i < _students.length; i++)
          AttendanceExportRow(
            roll: _students[i].rollNumber ?? '${i + 1}',
            name: _students[i].name,
            status: 'Present', // default for class roster export
          ),
      ],
    );
    await showExportSheet(context, data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E3A8A), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.className,
          style: const TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  _buildStatsGrid(),
                  const SizedBox(height: 24),
                  _buildAttendanceSummaryCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.class_, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.className,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.subject,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_students.length} Students',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_totalDays > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_totalDays Days Recorded',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Image.asset(
            'assets/images/students_group.png',
            width: 90,
            height: 90,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.people, size: 40, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.how_to_reg,
                label: 'Mark\nAttendance',
                color: const Color(0xFF1976D2),
                bgColor: const Color(0xFFE3F2FD),
                onTap: _openMarkAttendance,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.history,
                label: 'Attendance\nHistory',
                color: const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
                onTap: _openAttendanceHistory,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.ios_share,
                label: 'Export\nPDF / Excel',
                color: const Color(0xFFE53935),
                bgColor: const Color(0xFFFFEBEE),
                onTap: _showExportSheet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.print,
                label: 'Print\nReport',
                color: const Color(0xFF7C4DFF),
                bgColor: const Color(0xFFF3E5F5),
                onTap: () async {
                  if (_students.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No students to print.')),
                    );
                    return;
                  }
                  final data = AttendanceExportData(
                    className: widget.className,
                    subject: widget.subject,
                    teacher: _findCourseSchedule()?.instructorName ?? 'Teacher',
                    date: DateTime.now(),
                    rows: [
                      for (var i = 0; i < _students.length; i++)
                        AttendanceExportRow(
                          roll: _students[i].rollNumber ?? '${i + 1}',
                          name: _students[i].name,
                        ),
                    ],
                  );
                  final bytes = await ExportService.instance.buildPdf(data);
                  await ExportService.instance.printBytes(bytes);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final presentCount = _recentAttendance
        .where((a) => a.status == AttendanceStatus.present)
        .length;
    final absentCount = _recentAttendance
        .where((a) => a.status == AttendanceStatus.absent)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistics',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _buildStatCard(
              title: 'Present',
              value: '$presentCount',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF4CAF50),
              bgColor: const Color(0xFFE8F5E9),
            ),
            _buildStatCard(
              title: 'Absent',
              value: '$absentCount',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFE53935),
              bgColor: const Color(0xFFFFEBEE),
            ),
            _buildStatCard(
              title: 'Attendance %',
              value: '${_avgAttendance.toStringAsFixed(0)}%',
              icon: Icons.pie_chart_outline,
              color: const Color(0xFF1976D2),
              bgColor: const Color(0xFFE3F2FD),
            ),
            _buildStatCard(
              title: 'Total Records',
              value: '${_recentAttendance.length}',
              icon: Icons.analytics_outlined,
              color: const Color(0xFF9C27B0),
              bgColor: const Color(0xFFF3E5F5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSummaryCard() {
    if (_recentAttendance.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3F2FD)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF1976D2), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No attendance records yet. Tap "Mark Attendance" to start recording.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show last 7 days breakdown
    final now = DateTime.now();
    final recentDates = <String, int>{};
    for (var d = 0; d < 7; d++) {
      final date = now.subtract(Duration(days: d));
      final dateKey = DateFormat('EEE').format(date);
      final dayRecords = _recentAttendance.where((a) =>
          a.date != null &&
          a.date!.year == date.year &&
          a.date!.month == date.month &&
          a.date!.day == date.day);
      final present = dayRecords.where((a) => a.status == AttendanceStatus.present).length;
      recentDates[dateKey] = present;
    }
    final entries = recentDates.entries.toList().reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: entries.map((e) {
              final pct = _students.isEmpty
                  ? 0.0
                  : (e.value / _students.length * 100);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          backgroundColor: Colors.grey.shade100,
                          color: const Color(0xFF4CAF50),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${pct.toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
