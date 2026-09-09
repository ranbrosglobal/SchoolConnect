import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_model.dart';
import '../../models/student_model.dart';
import '../../state/auth_provider.dart';
import '../../services/export_service.dart';
import '../../widgets/export_sheet.dart';

/// Date range presets for attendance history filtering.
enum DateRangePreset { thisWeek, past15Days, thisMonth, past3Months, custom }

/// Screen that shows a teacher's past attendance records for a class with
/// date-range filters (This Week, Past 15 Days, This Month, Past 3 Months,
/// Custom) and export / print options.
class TeacherAttendanceHistoryScreen extends ConsumerStatefulWidget {
  final String className;
  final String subject;
  final String courseScheduleId;
  final String studentGroupId;

  const TeacherAttendanceHistoryScreen({
    super.key,
    required this.className,
    required this.subject,
    required this.courseScheduleId,
    required this.studentGroupId,
  });

  @override
  ConsumerState<TeacherAttendanceHistoryScreen> createState() =>
      _TeacherAttendanceHistoryScreenState();
}

class _TeacherAttendanceHistoryScreenState
    extends ConsumerState<TeacherAttendanceHistoryScreen> {
  DateRangePreset _selectedPreset = DateRangePreset.past15Days;
  DateTime? _customStart;
  DateTime? _customEnd;
  List<AttendanceModel> _records = [];
  List<DateTime> _dates = [];
  List<StudentModel> _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateRange _resolveRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_selectedPreset) {
      case DateRangePreset.thisWeek:
        final weekday = today.weekday; // Mon=1
        return DateRange(today.subtract(Duration(days: weekday - 1)), today);
      case DateRangePreset.past15Days:
        return DateRange(today.subtract(const Duration(days: 15)), today);
      case DateRangePreset.thisMonth:
        return DateRange(DateTime(now.year, now.month, 1), today);
      case DateRangePreset.past3Months:
        return DateRange(
            today.subtract(const Duration(days: 90)), today);
      case DateRangePreset.custom:
        return DateRange(
          _customStart ?? today.subtract(const Duration(days: 30)),
          _customEnd ?? today,
        );
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final range = _resolveRange();
    try {
      final service = ref.read(demoServiceProvider);
      _students = service.getClassStudents(widget.studentGroupId);
      _records = service.getAttendanceForCourse(
        courseSchedule: widget.courseScheduleId,
        studentGroup: widget.studentGroupId,
        startDate: range.start,
        endDate: range.end,
      );
      _dates = service.getAttendanceDates(
        courseSchedule: widget.courseScheduleId,
        studentGroup: widget.studentGroupId,
        startDate: range.start,
        endDate: range.end,
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _customStart ?? now.subtract(const Duration(days: 30)),
        end: _customEnd ?? now,
      ),
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
        _selectedPreset = DateRangePreset.custom;
      });
      _load();
    }
  }

  void _setPreset(DateRangePreset preset) {
    if (preset == DateRangePreset.custom) {
      _pickCustomRange();
      return;
    }
    setState(() => _selectedPreset = preset);
    _load();
  }

  // ---- Export helpers ----

  AttendanceExportData _buildExportData() {
    // Group records by date to build per-date rows
    final dateMap = <String, Map<String, AttendanceStatus>>{};
    for (final r in _records) {
      if (r.date == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(r.date!);
      dateMap.putIfAbsent(key, () => {});
      dateMap[key]![r.student ?? ''] = r.status;
    }

    // For export, use the latest date's attendance or all students
    final rows = <AttendanceExportRow>[];
    for (var i = 0; i < _students.length; i++) {
      final s = _students[i];
      // Find most recent status for this student
      String status = 'Present';
      for (final entry in dateMap.entries) {
        final studentStatus = entry.value[s.id];
        if (studentStatus != null) {
          status = _statusString(studentStatus);
          break;
        }
      }
      rows.add(AttendanceExportRow(
        roll: s.rollNumber ?? '${i + 1}',
        name: s.name,
        status: status,
      ));
    }

    return AttendanceExportData(
      className: widget.className,
      subject: widget.subject,
      teacher: 'Teacher',
      date: DateTime.now(),
      rows: rows,
    );
  }

  String _statusString(AttendanceStatus s) {
    switch (s) {
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

  Color _statusColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return const Color(0xFF4CAF50);
      case AttendanceStatus.absent:
        return const Color(0xFFE53935);
      case AttendanceStatus.halfDay:
        return const Color(0xFFFF9800);
      case AttendanceStatus.leave:
        return const Color(0xFF2196F3);
    }
  }

  IconData _statusIcon(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return Icons.check_circle;
      case AttendanceStatus.absent:
        return Icons.cancel;
      case AttendanceStatus.halfDay:
        return Icons.remove_circle;
      case AttendanceStatus.leave:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF1E3A8A), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Attendance History',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // Export button
          IconButton(
            icon: const Icon(Icons.ios_share, color: Color(0xFF1E3A8A)),
            onPressed: () async {
              if (_students.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No data to export.')),
                );
                return;
              }
              await showExportSheet(context, _buildExportData());
            },
          ),
          // Print button
          IconButton(
            icon: const Icon(Icons.print, color: Color(0xFF1E3A8A)),
            onPressed: () async {
              if (_students.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No data to print.')),
                );
                return;
              }
              final data = _buildExportData();
              final bytes = await ExportService.instance.buildPdf(data);
              await ExportService.instance.printBytes(bytes);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Print dialog opened.')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Class info banner
          _buildClassBanner(),
          // Filter chips
          _buildFilterChips(),
          // Stats row
          _buildStatsRow(),
          // Records list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _dates.isEmpty
                    ? _buildEmptyState()
                    : _buildRecordsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildClassBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.subject,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip('This Week', DateRangePreset.thisWeek),
            const SizedBox(width: 8),
            _buildChip('Past 15 Days', DateRangePreset.past15Days),
            const SizedBox(width: 8),
            _buildChip('This Month', DateRangePreset.thisMonth),
            const SizedBox(width: 8),
            _buildChip('Past 3 Months', DateRangePreset.past3Months),
            const SizedBox(width: 8),
            _buildChip('Custom', DateRangePreset.custom),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, DateRangePreset preset) {
    final isSelected = _selectedPreset == preset;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFF1976D2),
        ),
      ),
      selected: isSelected,
      onSelected: (_) => _setPreset(preset),
      selectedColor: const Color(0xFF1976D2),
      backgroundColor: const Color(0xFFE3F2FD),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildStatsRow() {
    final present =
        _records.where((r) => r.status == AttendanceStatus.present).length;
    final absent =
        _records.where((r) => r.status == AttendanceStatus.absent).length;
    final halfDay =
        _records.where((r) => r.status == AttendanceStatus.halfDay).length;
    final leave =
        _records.where((r) => r.status == AttendanceStatus.leave).length;
    final total = _records.length;
    final pct = total > 0 ? (present / total * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3F2FD)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('Present', '$present', const Color(0xFF4CAF50)),
          _buildMiniStat('Absent', '$absent', const Color(0xFFE53935)),
          _buildMiniStat('Half Day', '$halfDay', const Color(0xFFFF9800)),
          _buildMiniStat('Leave', '$leave', const Color(0xFF2196F3)),
          _buildMiniStat(
              '${pct.toStringAsFixed(0)}%', 'Present %', const Color(0xFF1976D2)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No attendance records found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different date range or mark attendance first.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      // One section header per unique date
      itemCount: _dates.length,
      itemBuilder: (context, index) {
        final date = _dates[index];
        final dayRecords =
            _records.where((r) => r.date != null && _isSameDay(r.date!, date)).toList();
        final present = dayRecords.where((r) => r.status == AttendanceStatus.present).length;
        final total = dayRecords.length;
        final pct = total > 0 ? (present / total * 100) : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('EEE, dd MMM yyyy').format(date),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$present/$total present (${pct.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Spacer(),
                  // Export single day
                  GestureDetector(
                    onTap: () async {
                      final dayData = AttendanceExportData(
                        className: widget.className,
                        subject: widget.subject,
                        teacher: 'Teacher',
                        date: date,
                        rows: [
                          for (var i = 0; i < dayRecords.length; i++)
                            AttendanceExportRow(
                              roll: '${i + 1}',
                              name: dayRecords[i].studentName ?? 'Student',
                              status: dayRecords[i].statusString,
                            ),
                        ],
                      );
                      await showExportSheet(context, dayData);
                    },
                    child: Icon(Icons.ios_share,
                        size: 18, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            // Student rows for this date
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < dayRecords.length; i++)
                    _buildRecordTile(dayRecords[i], i < dayRecords.length - 1),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecordTile(AttendanceModel record, bool showDivider) {
    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Icon(
            _statusIcon(record.status),
            color: _statusColor(record.status),
            size: 22,
          ),
          title: Text(
            record.studentName ?? 'Student',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            record.student ?? '',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(record.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              record.statusString,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _statusColor(record.status),
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 14, endIndent: 14, color: Colors.grey.shade100),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class DateRange {
  final DateTime start;
  final DateTime end;
  DateRange(this.start, this.end);
}
