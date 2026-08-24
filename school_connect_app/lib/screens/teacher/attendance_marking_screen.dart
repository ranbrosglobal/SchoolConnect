import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../state/teacher_provider.dart';
import '../../models/course_schedule_model.dart';
import '../../models/student_model.dart';
import '../../models/attendance_model.dart';
import '../../services/google_sheets_service.dart';
import '../../services/export_service.dart';
import '../../widgets/export_sheet.dart';

class AttendanceMarkingScreen extends ConsumerStatefulWidget {
  final CourseScheduleModel courseSchedule;

  const AttendanceMarkingScreen({
    super.key,
    required this.courseSchedule,
  });

  @override
  ConsumerState<AttendanceMarkingScreen> createState() =>
      _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends ConsumerState<AttendanceMarkingScreen> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, AttendanceStatus> _attendanceMap = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherProvider.notifier).selectClass(widget.courseSchedule);
    });
  }

  Widget _buildSvgPicture(String asset, {double? height, double? width, Key? key}) {
    return SvgPicture.asset(
      asset,
      key: key,
      height: height,
      width: width,
      placeholderBuilder: (context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image, color: Colors.grey),
      ),
    );
  }

  void _initializeAttendance(List<StudentModel> students, List<AttendanceModel> existing) {
    // Initialize with existing attendance or default to present
    for (var student in students) {
      final existingRecord = existing.firstWhere(
        (a) => a.student == student.id,
        orElse: () => AttendanceModel(
          id: '',
          student: student.id,
          status: AttendanceStatus.present,
        ),
      );
      _attendanceMap[student.id] = existingRecord.status;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitAttendance() async {
    if (_attendanceMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students to mark attendance for')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final records = _attendanceMap.entries.map((entry) {
        return AttendanceRecord(
          studentId: entry.key,
          status: entry.value,
        );
      }).toList();

      final success = await ref.read(teacherProvider.notifier).markAttendance(
        studentGroup: widget.courseSchedule.studentGroup ?? '',
        date: _selectedDate,
        records: records,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ------------------------------------------------------------------
  // Export (PDF / CSV / Excel → download, share, print)
  // ------------------------------------------------------------------
  AttendanceExportData _buildExportData(TeacherState state) {
    final students = state.currentClassStudents;
    final saved = state.currentAttendance;
    return AttendanceExportData(
      className: widget.courseSchedule.studentGroupName ??
          widget.courseSchedule.studentGroup ??
          'Class',
      subject: widget.courseSchedule.courseName ?? widget.courseSchedule.course ?? 'Subject',
      teacher: widget.courseSchedule.instructorName ?? 'Teacher',
      room: widget.courseSchedule.room ?? '',
      date: _selectedDate,
      rows: [
        for (var i = 0; i < students.length; i++)
          AttendanceExportRow(
            roll: students[i].rollNumber ?? '${i + 1}',
            name: students[i].name,
            status: _statusFor(students[i], saved),
          ),
      ],
    );
  }

  String _statusFor(StudentModel student, List<AttendanceModel> saved) {
    final live = _attendanceMap[student.id];
    if (live != null) {
      switch (live) {
        case AttendanceStatus.present:
          return 'Present';
        case AttendanceStatus.absent:
          return 'Absent';
        case AttendanceStatus.halfDay:
          return 'Half Day';
        case AttendanceStatus.leave:
          return 'Leave';
      }
    }
    final recs = saved.where((a) => a.student == student.id).toList();
    return recs.isNotEmpty ? recs.first.statusString : 'Present';
  }

  Future<void> _showExportSheet() async {
    final state = ref.read(teacherProvider);
    if (state.currentClassStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students loaded yet to export')),
      );
      return;
    }
    final data = _buildExportData(state);
    await showExportSheet(context, data);
  }

  @override
  Widget build(BuildContext context) {
    final teacherState = ref.watch(teacherProvider);

    // Initialize attendance map when students are loaded
    if (teacherState.currentClassStudents.isNotEmpty && _attendanceMap.isEmpty) {
      _initializeAttendance(
        teacherState.currentClassStudents,
        teacherState.currentAttendance,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mark Attendance',
          style: TextStyle(fontSize: 17),
        ),
        actions: [
          // Export — same option sheet as the roster screen (PDF / CSV /
          // Excel / share / print).
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _showExportSheet,
              icon: const Icon(Icons.ios_share, size: 16, color: Color(0xFF1E3A8A)),
              label: const Text(
                'Export',
                style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 13),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitAttendance,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(_isSubmitting ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Class info header
          _buildClassHeader().animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),

          // Date picker
          _buildDatePicker().animate().fadeIn(delay: 150.ms),

          // Quick actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _attendanceMap.updateAll((_, __) => AttendanceStatus.present);
                      });
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('All Present'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _attendanceMap.updateAll((_, __) => AttendanceStatus.absent);
                      });
                    },
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('All Absent'),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 250.ms),

          // Legend
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendDot(Colors.green, 'Present'),
                const SizedBox(width: 16),
                _buildLegendDot(Colors.red, 'Absent'),
                const SizedBox(width: 16),
                _buildLegendDot(Colors.orange, 'Half Day'),
                const SizedBox(width: 16),
                _buildLegendDot(Colors.blue, 'Leave'),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 4),

          // Student list
          Expanded(
            child: _buildStudentList(teacherState),
          ),
        ],
      ),
    );
  }

  Widget _buildClassHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.class_, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.courseSchedule.courseName ?? 'Unknown Course',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.courseSchedule.studentGroupName ?? 'Unknown Group',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (widget.courseSchedule.room != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.room,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.courseSchedule.room!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStudentList(TeacherState state) {
    if (state.isLoading && state.currentClassStudents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.currentClassStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSvgPicture(
              'assets/images/attendance_character.svg',
              height: 120,
              width: 120,
            ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 24),
            Text(
              'No Students Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              'This class has no students enrolled.',
              style: TextStyle(color: Colors.grey[600]),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: state.currentClassStudents.length,
      itemBuilder: (context, index) {
        final student = state.currentClassStudents[index];
        final currentStatus = _attendanceMap[student.id] ?? AttendanceStatus.present;
        final statusColor = _getStatusColor(currentStatus);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: statusColor.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Text(
                student.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              student.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              student.id,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: _buildStatusToggle(student.id, currentStatus),
          ),
        );
      },
    );
  }

  Widget _buildStatusToggle(String studentId, AttendanceStatus currentStatus) {
    return SegmentedButton<AttendanceStatus>(
      segments: const [
        ButtonSegment(
          value: AttendanceStatus.present,
          label: Text('P'),
        ),
        ButtonSegment(
          value: AttendanceStatus.absent,
          label: Text('A'),
        ),
        ButtonSegment(
          value: AttendanceStatus.halfDay,
          label: Text('H'),
        ),
        ButtonSegment(
          value: AttendanceStatus.leave,
          label: Text('L'),
        ),
      ],
      selected: {currentStatus},
      onSelectionChanged: (Set<AttendanceStatus> selected) {
        setState(() {
          _attendanceMap[studentId] = selected.first;
        });
      },
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.halfDay:
        return Colors.orange;
      case AttendanceStatus.leave:
        return Colors.blue;
    }
  }
}
