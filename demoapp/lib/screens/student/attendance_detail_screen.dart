import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../state/student_provider.dart';
import '../../models/attendance_model.dart';

class AttendanceDetailScreen extends ConsumerStatefulWidget {
  final String course;

  const AttendanceDetailScreen({
    super.key,
    required this.course,
  });

  @override
  ConsumerState<AttendanceDetailScreen> createState() =>
      _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState extends ConsumerState<AttendanceDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studentProvider.notifier).loadAttendanceForCourse(widget.course);
    });
  }

  @override
  Widget build(BuildContext context) {
    final studentState = ref.watch(studentProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course),
      ),
      body: _buildBody(studentState),
    );
  }

  Widget _buildBody(StudentState state) {
    if (state.isLoading && state.attendanceRecords.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.attendanceRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No Attendance Records',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'No attendance records found for this course.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Calculate statistics
    final total = state.attendanceRecords.length;
    final present = state.attendanceRecords
        .where((a) => a.status == AttendanceStatus.present)
        .length;
    final percentage = total > 0 ? (present / total * 100) : 0.0;

    return Column(
      children: [
        // Statistics header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', '$total'),
              _buildStatItem('Present', '$present'),
              _buildStatItem('Absent', '${total - present}'),
              _buildStatItem(
                'Attendance',
                '${percentage.toStringAsFixed(1)}%',
                color: percentage >= 75 ? Colors.green : Colors.orange,
              ),
            ],
          ),
        ),

        // Attendance list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.attendanceRecords.length,
            itemBuilder: (context, index) {
              final attendance = state.attendanceRecords[index];
              return _buildAttendanceCard(attendance);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard(AttendanceModel attendance) {
    final statusColor = _getStatusColor(attendance.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              _getStatusIcon(attendance.status),
              color: statusColor,
            ),
          ),
        ),
        title: Text(
          attendance.statusString,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: statusColor,
          ),
        ),
        subtitle: Text(
          attendance.date != null
              ? DateFormat('EEEE, MMMM d, yyyy').format(attendance.date!)
              : 'No date',
        ),
        trailing: attendance.remarks != null
            ? Icon(Icons.info_outline, color: Colors.grey[400])
            : null,
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

  IconData _getStatusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check_circle;
      case AttendanceStatus.absent:
        return Icons.cancel;
      case AttendanceStatus.halfDay:
        return Icons.access_time;
      case AttendanceStatus.leave:
        return Icons.event_busy;
    }
  }
}
