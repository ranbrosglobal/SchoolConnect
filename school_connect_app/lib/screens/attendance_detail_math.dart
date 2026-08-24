import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';
import '../utils/time_format.dart';
import '../state/auth_provider.dart';

/// Attendance detail for a course schedule (teacher view). Reads the
/// schedule id from the route arguments and renders each student's real
/// attendance records from the live backend.
class AttendanceDetailMath extends ConsumerStatefulWidget {
  const AttendanceDetailMath({super.key});

  @override
  ConsumerState<AttendanceDetailMath> createState() => _AttendanceDetailMathState();
}

class _AttendanceDetailMathState extends ConsumerState<AttendanceDetailMath> {
  String? _scheduleId;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    String? scheduleId;
    if (args is String) {
      scheduleId = args;
    } else if (args is Map) {
      scheduleId = args['courseSchedule']?.toString();
    }
    setState(() => _scheduleId = scheduleId);
    if (scheduleId != null) {
      await _load(scheduleId);
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _load(String scheduleId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(sheetsServiceProvider)
          .getCourseAttendance(scheduleId);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  Color _statusColor(String status) {
    switch (status) {
      case 'Present':
        return AppColors.tertiary;
      case 'Absent':
        return AppColors.error;
      case 'Half Day':
        return AppColors.secondaryContainer;
      case 'Leave':
        return AppColors.info;
      default:
        return AppColors.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Attendance Detail', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.info,
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
                        Text('Could not load attendance: $_error',
                            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 12),
                        if (_scheduleId != null)
                          OutlinedButton(
                            onPressed: () => _load(_scheduleId!),
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ),
                )
          : _data == null
              ? const Center(child: Text('No course schedule selected.'))
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final data = _data!;
    final students = (data['students'] as List? ?? []).cast<Map<String, dynamic>>();
    final recordCount = students.fold<int>(
      0,
      (sum, s) => sum + ((s['records'] as List? ?? []).length),
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.hairlineBorder),
          ),
          child: ListTile(
            leading: const Icon(Icons.class_outlined, color: AppColors.info),
            title: Text(
              '${data['course_name'] ?? 'Course'} — ${data['student_group_name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              [
                if (data['instructor_name'] != null) data['instructor_name'] as String,
                if (data['room'] != null) 'Room ${data['room']}',
                if (data['from_time'] != null && data['to_time'] != null)
                  '${formatTime12h(data['from_time'] as String?)} - ${formatTime12h(data['to_time'] as String?)}',
              ].join(' · '),
            ),
            trailing: Text(
              '$recordCount records',
              style: const TextStyle(fontSize: 12, color: AppColors.outline),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Students',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (students.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No attendance records for this course.')),
          )
        else
          ...students.map((entry) {
            final records = (entry['records'] as List? ?? []).cast<Map<String, dynamic>>();
            final percent = (entry['percentage'] ?? 0.0).toDouble();
            final studentName = entry['student_name']?.toString() ?? entry['student']?.toString() ?? '?';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.hairlineBorder),
              ),
              child: ExpansionTile(
                shape: const Border(),
                leading: CircleAvatar(
                  backgroundColor: AppColors.info.withValues(alpha: 0.12),
                  child: Text(
                    studentName.isNotEmpty ? studentName[0] : '?',
                    style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  studentName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  '${percent.toStringAsFixed(1)}% attendance',
                  style: TextStyle(
                    fontSize: 12,
                    color: percent >= 75 ? AppColors.tertiary : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: records.take(30).map((r) {
                  final date = r['date'] != null ? DateTime.tryParse(r['date'].toString()) : null;
                  final status = r['status']?.toString() ?? 'Present';
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.circle, size: 10, color: _statusColor(status)),
                    title: Text(
                      date != null ? DateFormat('MMM d, yyyy').format(date) : 'No date',
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(status),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
      ],
    );
  }
}
