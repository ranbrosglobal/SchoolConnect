import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../state/teacher_provider.dart';
import '../../models/course_schedule_model.dart';
import '../../models/student_model.dart';
import '../../models/attendance_model.dart';
import '../../services/google_sheets_service.dart';
import '../../services/export_service.dart';
import '../../widgets/export_sheet.dart';

/// How far back a teacher may go to view or correct attendance.
const _maxHistoryDays = 730;

/// Mark / edit attendance for one class on one specific day.
///
/// Attendance is per-day: each day starts from an unmarked roster (defaulting
/// to present), and teachers can navigate back to any past day to review or
/// correct what was recorded. Saving always writes the full roster for the
/// selected date — re-marking a day overwrites it.
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

class _AttendanceMarkingScreenState
    extends ConsumerState<AttendanceMarkingScreen> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, AttendanceStatus> _attendanceMap = {};
  bool _isSubmitting = false;
  /// The date the local [_attendanceMap] was last initialized for, so a date
  /// switch re-seeds the map from that day's saved records.
  DateTime? _initializedForDate;

  bool get _isToday => _dateKey(_selectedDate) == _dateKey(DateTime.now());
  bool get _isFuture => _dateKey(_selectedDate).isAfter(_dateKey(DateTime.now()));

  static DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _dateKeyStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherProvider.notifier).selectClass(
            widget.courseSchedule,
            date: _selectedDate,
          );
    });
  }

  // ------------------------------------------------------------------
  // Data plumbing
  // ------------------------------------------------------------------

  /// Seed the local status map for [_selectedDate]: statuses already saved on
  /// the server for that date, or "present" for an unmarked day.
  void _syncMapForDate(TeacherState state) {
    if (state.isLoadingAttendance) return;
    if (state.currentClassStudents.isEmpty) return;
    if (_initializedForDate != null &&
        _dateKey(_initializedForDate!) == _dateKey(state.attendanceDate ?? _selectedDate)) {
      return;
    }
    _attendanceMap.clear();
    for (final student in state.currentClassStudents) {
      final saved = state.currentAttendance.where((a) => a.student == student.id);
      _attendanceMap[student.id] =
          saved.isNotEmpty ? saved.first.status : AttendanceStatus.present;
    }
    _initializedForDate = state.attendanceDate ?? _selectedDate;
  }

  Future<void> _changeDate(DateTime date) async {
    final newDate = _dateKey(date);
    if (_dateKey(_selectedDate) == newDate) return;
    setState(() {
      _selectedDate = newDate;
      _initializedForDate = null;
      _attendanceMap.clear();
    });
    await ref.read(teacherProvider.notifier).loadAttendanceForDate(
          widget.courseSchedule,
          date: newDate,
          students: ref.read(teacherProvider).currentClassStudents,
        );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: _maxHistoryDays)),
      lastDate: DateTime.now(),
      helpText: 'Select attendance date',
    );
    if (picked != null && mounted) await _changeDate(picked);
  }

  void _shiftDay(int delta) {
    final target = _selectedDate.add(Duration(days: delta));
    if (_isFutureKey(target)) return;
    _changeDate(target);
  }

  bool _isFutureKey(DateTime d) => _dateKey(d).isAfter(_dateKey(DateTime.now()));

  // ------------------------------------------------------------------
  // Save
  // ------------------------------------------------------------------

  int _changedCount(TeacherState state) {
    var changed = 0;
    for (final student in state.currentClassStudents) {
      final saved = state.currentAttendance.where((a) => a.student == student.id);
      final serverStatus =
          saved.isNotEmpty ? saved.first.status : AttendanceStatus.present;
      if (_attendanceMap[student.id] != serverStatus) changed++;
    }
    return changed;
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
      final records = _attendanceMap.entries
          .map((entry) => AttendanceRecord(
                studentId: entry.key,
                status: entry.value,
              ))
          .toList();

      final success = await ref.read(teacherProvider.notifier).markAttendance(
        studentGroup: widget.courseSchedule.studentGroup ?? '',
        date: _selectedDate,
        records: records,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isToday
                        ? 'Attendance saved for today'
                        : 'Attendance saved for ${DateFormat('d MMM yyyy').format(_selectedDate)}',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      } else if (mounted) {
        final error = ref.read(teacherProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(error ?? 'Could not save attendance. Try again.'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Error saving attendance: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ------------------------------------------------------------------
  // Export (PDF / CSV / Excel → download, share, print)
  // ------------------------------------------------------------------

  AttendanceExportData _buildExportData(TeacherState state) {
    final students = state.currentClassStudents;
    return AttendanceExportData(
      className: widget.courseSchedule.studentGroupName ??
          widget.courseSchedule.studentGroup ??
          'Class',
      subject:
          widget.courseSchedule.courseName ?? widget.courseSchedule.course ?? 'Subject',
      teacher: widget.courseSchedule.instructorName ?? 'Teacher',
      room: widget.courseSchedule.room ?? '',
      date: _selectedDate,
      rows: [
        for (var i = 0; i < students.length; i++)
          AttendanceExportRow(
            roll: students[i].rollNumber ?? '${i + 1}',
            name: students[i].name,
            status: _statusLabel(_attendanceMap[students[i].id] ??
                AttendanceStatus.present),
          ),
      ],
    );
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

  Future<void> _showExportSheet() async {
    final state = ref.read(teacherProvider);
    if (state.currentClassStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students loaded yet to export')),
      );
      return;
    }
    await showExportSheet(context, _buildExportData(state));
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final teacherState = ref.watch(teacherProvider);
    _syncMapForDate(teacherState);

    final marked = teacherState.currentAttendance;
    final dayMarked = marked.isNotEmpty;
    final changed = _changedCount(teacherState);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Mark Attendance', style: TextStyle(fontSize: 17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _showExportSheet,
              icon: const Icon(Icons.ios_share, size: 16, color: Color(0xFF1E3A8A)),
              label: const Text('Export',
                  style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildClassHeader()
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: -0.15),
          _buildDateBar(dayMarked: dayMarked)
              .animate()
              .fadeIn(delay: 100.ms),
          Expanded(
            child: _buildBody(teacherState),
          ),
          _buildSaveBar(teacherState, changed),
        ],
      ),
    );
  }

  Widget _buildClassHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
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
                const SizedBox(height: 2),
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
          if ((widget.courseSchedule.room ?? '').isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.room, size: 14, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 4),
                  Text(
                    widget.courseSchedule.room!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Date navigation: ◀ [Mon, 23 Sep ▾] ▶ + "today" badge.
  Widget _buildDateBar({required bool dayMarked}) {
    final fmt = DateFormat('EEE, d MMM yyyy');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => _shiftDay(-1),
              icon: const Icon(Icons.chevron_left, size: 22),
              tooltip: 'Previous day',
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available_outlined,
                              size: 17, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              fmt.format(_selectedDate),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: Colors.grey.shade500),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isToday
                            ? (dayMarked ? 'Today · marked' : 'Today · not marked yet')
                            : (_isFuture
                                ? 'Future date'
                                : (dayMarked ? 'Past day · saved' : 'Past day · not marked')),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: dayMarked
                              ? const Color(0xFF16A34A)
                              : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _isToday || _isFuture ? null : () => _shiftDay(1),
              icon: Icon(
                Icons.chevron_right,
                size: 22,
                color: _isToday || _isFuture ? Colors.grey.shade300 : null,
              ),
              tooltip: 'Next day',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(TeacherState state) {
    if (state.isLoading && state.currentClassStudents.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.currentClassStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Students Found',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This class has no students enrolled.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _changeDate(_selectedDate),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          if (state.isLoadingAttendance) _buildLoadingStrip(),
          _buildSummaryChips(state),
          const SizedBox(height: 10),
          if (!_isToday && !_isFuture)
            _buildPastEditBanner()
          else if (_isFuture)
            _buildFutureBanner(),
          const SizedBox(height: 10),
          _buildQuickActions(state),
          const SizedBox(height: 12),
          ...state.currentClassStudents.asMap().entries.map(
                (e) => _buildStudentCard(
                  e.value,
                  index: e.key,
                  state: state,
                ),
              ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLoadingStrip() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading records for ${DateFormat('d MMM').format(_selectedDate)}…',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildPastEditBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          Icon(Icons.history_edu_outlined,
              size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are editing a past day (${DateFormat('d MMM yyyy').format(_selectedDate)}). '
              'Saving updates that day\u2019s records.',
              style: TextStyle(
                  fontSize: 12.5, color: Colors.orange.shade900, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFutureBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, size: 18, color: Colors.blue.shade800),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Attendance can only be marked once the class has happened. '
              'Saving is disabled for future dates.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChips(TeacherState state) {
    int count(AttendanceStatus s) =>
        _attendanceMap.values.where((v) => v == s).length;
    final present = count(AttendanceStatus.present);
    final absent = count(AttendanceStatus.absent);
    final half = count(AttendanceStatus.halfDay);
    final leave = count(AttendanceStatus.leave);

    return Row(
      children: [
        _summaryCard('Present', present, const Color(0xFF16A34A),
            Icons.check_circle_outline),
        const SizedBox(width: 8),
        _summaryCard('Absent', absent, const Color(0xFFDC2626),
            Icons.cancel_outlined),
        const SizedBox(width: 8),
        _summaryCard('Half', half, const Color(0xFFEA580C),
            Icons.wb_twighlight),
        const SizedBox(width: 8),
        _summaryCard('Leave', leave, const Color(0xFF2563EB),
            Icons.airline_seat_individual_suite_outlined),
      ],
    );
  }

  Widget _summaryCard(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text('$value',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(TeacherState state) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _attendanceMap
                .updateAll((_, __) => AttendanceStatus.present)),
            icon: const Icon(Icons.done_all, size: 17),
            label: const Text('All Present'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF16A34A),
              side: BorderSide(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _attendanceMap
                .updateAll((_, __) => AttendanceStatus.absent)),
            icon: const Icon(Icons.remove_done, size: 17),
            label: const Text('All Absent'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: BorderSide(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(
    StudentModel student, {
    required int index,
    required TeacherState state,
  }) {
    final currentStatus =
        _attendanceMap[student.id] ?? AttendanceStatus.present;
    final statusColor = _getStatusColor(currentStatus);
    final isUnsaved =
        _changedCount(state) > 0 && _isModified(student, state);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnsaved
              ? statusColor.withValues(alpha: 0.55)
              : const Color(0xFFE2E8F0),
          width: isUnsaved ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: statusColor.withValues(alpha: 0.13),
            child: Text(
              student.name.isNotEmpty
                  ? student.name.substring(0, 1).toUpperCase()
                  : '?',
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  (student.rollNumber?.isNotEmpty ?? false)
                      ? 'Roll ${student.rollNumber}'
                      : student.id,
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusChips(student.id, currentStatus),
        ],
      ),
    ).animate().fadeIn(
        duration: 250.ms,
        delay: Duration(milliseconds: (30 * index).clamp(0, 400)));
  }

  bool _isModified(StudentModel student, TeacherState state) {
    final saved = state.currentAttendance.where((a) => a.student == student.id);
    final serverStatus =
        saved.isNotEmpty ? saved.first.status : AttendanceStatus.present;
    return _attendanceMap[student.id] != serverStatus;
  }

  Widget _buildStatusChips(String studentId, AttendanceStatus currentStatus) {
    Widget chip(AttendanceStatus status, String label, Color color) {
      final selected = currentStatus == status;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _attendanceMap[studentId] = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(AttendanceStatus.present, 'P', const Color(0xFF16A34A)),
        const SizedBox(width: 5),
        chip(AttendanceStatus.absent, 'A', const Color(0xFFDC2626)),
        const SizedBox(width: 5),
        chip(AttendanceStatus.halfDay, 'H', const Color(0xFFEA580C)),
        const SizedBox(width: 5),
        chip(AttendanceStatus.leave, 'L', const Color(0xFF2563EB)),
      ],
    );
  }

  Widget _buildSaveBar(TeacherState state, int changed) {
    final canSave = !_isFuture &&
        state.currentClassStudents.isNotEmpty &&
        !_isSubmitting &&
        !state.isLoadingAttendance;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom * 0.4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_attendanceMap.length} students · ${DateFormat('d MMM yyyy').format(_selectedDate)}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155)),
                ),
                const SizedBox(height: 2),
                Text(
                  _isFuture
                      ? 'Future date — saving disabled'
                      : (changed > 0
                          ? '$changed unsaved change${changed == 1 ? '' : 's'}'
                          : (state.currentAttendance.isNotEmpty
                              ? 'All changes saved'
                              : 'Not marked yet — defaults to Present')),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: changed > 0
                        ? const Color(0xFFEA580C)
                        : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: canSave ? _submitAttendance : null,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSubmitting ? 'Saving…' : 'Save'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return const Color(0xFF16A34A);
      case AttendanceStatus.absent:
        return const Color(0xFFDC2626);
      case AttendanceStatus.halfDay:
        return const Color(0xFFEA580C);
      case AttendanceStatus.leave:
        return const Color(0xFF2563EB);
    }
  }
}
