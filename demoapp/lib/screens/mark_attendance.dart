import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../state/teacher_provider.dart';
import '../models/attendance_model.dart';
import '../services/demo_api_service.dart';
import '../services/export_service.dart';
import '../widgets/export_sheet.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MarkAttendance extends ConsumerStatefulWidget {
  const MarkAttendance({super.key});

  @override
  ConsumerState<MarkAttendance> createState() => _MarkAttendanceState();
}

class _MarkAttendanceState extends ConsumerState<MarkAttendance> {
  final Map<String, AttendanceStatus> _attendanceStatus = {};
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAttendance();
    });
  }

  void _initAttendance() {
    final state = ref.read(teacherProvider);
    final students = state.currentClassStudents;
    final existingRecords = state.currentAttendance;
    
    setState(() {
      for (var student in students) {
        final existing = existingRecords.where((a) => a.student == student.id).toList();
        if (existing.isNotEmpty) {
          _attendanceStatus[student.id] = existing.first.status;
        } else {
          _attendanceStatus[student.id] = AttendanceStatus.present; // Default
        }
      }
    });
  }

  void _markAll(AttendanceStatus status) {
    setState(() {
      for (var key in _attendanceStatus.keys) {
        _attendanceStatus[key] = status;
      }
    });
  }

  Future<void> _showExport() async {
    final state = ref.read(teacherProvider);
    final selectedClass = state.selectedClass;
    if (selectedClass == null || state.currentClassStudents.isEmpty) return;

    final data = AttendanceExportData(
      className: selectedClass.studentGroupName ?? selectedClass.displayName,
      subject: selectedClass.courseName ?? 'Class',
      teacher: selectedClass.instructorName ?? '',
      room: selectedClass.room ?? '',
      date: _selectedDate,
      rows: [
        for (final s in state.currentClassStudents)
          AttendanceExportRow(
            roll: s.rollNumber ?? '',
            name: s.name,
            status: _attendanceStatus[s.id] == null
                ? ''
                : _statusLabel(_attendanceStatus[s.id]!),
          ),
      ],
    );
    await showExportSheet(context, data);
  }

  String _statusLabel(AttendanceStatus status) {
    switch (status) {
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

  Future<void> _submitAttendance() async {
    final state = ref.read(teacherProvider);
    if (state.selectedClass == null) return;
    
    final records = _attendanceStatus.entries.map((e) {
      return AttendanceRecord(studentId: e.key, status: e.value);
    }).toList();
    
    final success = await ref.read(teacherProvider.notifier).markAttendance(
      studentGroup: state.selectedClass!.studentGroup ?? '',
      date: _selectedDate,
      records: records,
    );
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherProvider);
    final students = state.currentClassStudents;
    final selectedClass = state.selectedClass;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mark Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            onPressed: state.isLoading || students.isEmpty ? null : _showExport,
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
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : students.isEmpty
              ? const Center(child: Text('No students found.'))
              : Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _markAll(AttendanceStatus.present),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('All Present'),
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.tertiary),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _markAll(AttendanceStatus.absent),
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('All Absent'),
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: students.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final student = students[index];
                          final currentStatus = _attendanceStatus[student.id] ?? AttendanceStatus.present;
                          return _buildStudentRow(student.id, student.name, student.rollNumber, currentStatus);
                        },
                      ).animate().fade().slideY(begin: 0.05),
                    ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          // Slightly tighter padding on narrow screens so the two buttons
          // always fit side by side without overlapping.
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 380 ? 10 : 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: students.isEmpty ? null : _showExport,
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Export',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    side: const BorderSide(color: AppColors.info),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _submitAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Save Attendance',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentRow(String studentId, String name, String? rollNumber, AttendanceStatus status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.hairlineBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.surfaceContainerHigh,
              radius: 20,
              child: Text(rollNumber ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            _buildStatusButton(studentId, AttendanceStatus.present, 'P', AppColors.tertiary, status),
            const SizedBox(width: 4),
            _buildStatusButton(studentId, AttendanceStatus.absent, 'A', AppColors.error, status),
            const SizedBox(width: 4),
            _buildStatusButton(studentId, AttendanceStatus.halfDay, 'H', AppColors.secondaryContainer, status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(String studentId, AttendanceStatus targetStatus, String label, Color color, AttendanceStatus currentStatus) {
    final isSelected = currentStatus == targetStatus;
    return GestureDetector(
      onTap: () {
        setState(() {
          _attendanceStatus[studentId] = targetStatus;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : AppColors.hairlineBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.outline,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
