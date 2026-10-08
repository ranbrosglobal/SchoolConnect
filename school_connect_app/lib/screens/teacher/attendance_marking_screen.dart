import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../state/teacher_provider.dart';
import '../../models/course_schedule_model.dart';
import '../../models/school_profile_model.dart';
import '../../models/student_model.dart';
import '../../models/attendance_model.dart';
import '../../services/google_sheets_service.dart';
import '../../services/export_service.dart';
import '../../state/school_provider.dart';
import '../../widgets/export_sheet.dart';
import 'attendance_history_screen.dart';

/// How far back a teacher may go to view or correct attendance.
const _maxHistoryDays = 730;

/// Mark / edit attendance for one class on one specific day.
///
/// Core rules:
/// • Nothing is selected until the teacher explicitly taps a status — no
///   silent "everyone present" default that produced fake registers.
/// • Save writes ONLY the explicitly chosen students. If only part of the
///   class was marked, the teacher confirms (the rest stay unrecorded and
///   are auto-marked Absent at 7pm if nobody completes the day).
/// • After saving, the screen re-reads the day from the server and shows
///   what was actually persisted — "6 saved" means 6 rows in the database.
/// • Clear Attendance wipes the day back to unmarked.
class AttendanceMarkingScreen extends ConsumerStatefulWidget {
  final CourseScheduleModel courseSchedule;
  /// Day the screen opens on (defaults to today). The history screen uses
  /// this to deep-link into a past day for editing.
  final DateTime? initialDate;

  const AttendanceMarkingScreen({
    super.key,
    required this.courseSchedule,
    this.initialDate,
  });

  @override
  ConsumerState<AttendanceMarkingScreen> createState() =>
      _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState
    extends ConsumerState<AttendanceMarkingScreen> {
  /// Fixed "today" captured once, so an open screen doesn't treat yesterday
  /// as today when midnight passes mid-session.
  final DateTime _today = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  /// Only explicitly chosen students live here; everyone else is unselected.
  final Map<String, AttendanceStatus> _selected = {};
  bool _isSubmitting = false;
  bool _isClearing = false;
  /// True while an export is being prepared (period read + school branding).
  bool _isExporting = false;
  /// The day the local [_selected] map was last (re)seeded for, so a date
  /// switch re-seeds from that day's saved records.
  DateTime? _lastSeededDateKey;

  bool get _isToday => _dateKey(_selectedDate) == _dateKey(_today);
  bool get _isFuture => _dateKey(_selectedDate).isAfter(_dateKey(_today));

  static DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDate = _dateKey(widget.initialDate!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherProvider.notifier).selectClass(
            widget.courseSchedule,
            date: _selectedDate,
          );
    });
  }

  // ------------------------------------------------------------------
  // Local state sync
  // ------------------------------------------------------------------

  /// Seed the selection map for [_selectedDate] from what the server has for
  /// that day. Only students with a saved record appear selected; everyone
  /// else is unselected until the teacher taps a status.
  ///
  /// Skips unless the provider state actually belongs to the day we're
  /// showing — otherwise a load for yesterday could seed today's map. The
  /// [_lastSeededDateKey] guard then keeps rebuilds from wiping unsaved
  /// taps while staying on the same day.
  void _syncMapForDate(TeacherState state) {
    if (state.isLoading || state.isLoadingAttendance) return;
    if (state.currentClassStudents.isEmpty) return;
    final stateDate = _dateKey(state.attendanceDate ?? _selectedDate);
    if (stateDate != _dateKey(_selectedDate)) return;
    final saved = state.savedRecordsFor(_selectedDate);
    // Nothing authoritative for this day yet (the read failed or hasn't come
    // back). Leave the teacher's taps alone instead of wiping them — and do
    // NOT mark the day as seeded, or the real records would never show once
    // they arrive.
    if (!state.attendanceVerified && saved.isEmpty) return;
    if (_lastSeededDateKey != null &&
        _lastSeededDateKey == _dateKey(_selectedDate)) {
      return;
    }
    _selected.clear();
    for (final student in state.currentClassStudents) {
      final recs = saved.where((a) => a.student == student.id);
      if (recs.isNotEmpty) _selected[student.id] = recs.first.status;
    }
    _lastSeededDateKey = _dateKey(_selectedDate);
  }

  AttendanceStatus? _statusOf(String studentId, TeacherState state) {
    return _selected[studentId];
  }

  /// The student's saved record for the day being viewed, from the server's
  /// day roster or — when that read couldn't see it — the save this session
  /// just sent to the server.
  AttendanceModel? _savedRecordFor(String studentId, TeacherState state) {
    final saved = state.savedRecordsFor(_selectedDate);
    for (final rec in saved) {
      if (rec.student == studentId) return rec;
    }
    return null;
  }

  /// (Re)load the currently selected day from the server. Also the
  /// pull-to-refresh handler: the selected-date early-return that used to
  /// live here silently no-op'd refreshes. An explicit refresh re-seeds the
  /// selection map from the server afterwards, discarding unsaved local taps.
  Future<void> _changeDate(DateTime date) async {
    final newDate = _dateKey(date);
    if (_dateKey(_selectedDate) != newDate) {
      setState(() {
        _selectedDate = newDate;
        _lastSeededDateKey = null;
        _selected.clear();
      });
    } else {
      // Same day → this is a manual refresh; drop the seed guard so the map
      // re-seeds from whatever the server returns.
      setState(() => _lastSeededDateKey = null);
    }
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
      firstDate: _today.subtract(const Duration(days: _maxHistoryDays)),
      lastDate: _today,
      helpText: 'Select attendance date',
    );
    if (picked != null && mounted) await _changeDate(picked);
  }

  void _shiftDay(int delta) {
    final target = _selectedDate.add(Duration(days: delta));
    if (_dateKey(target).isAfter(_dateKey(_today))) return;
    _changeDate(target);
  }

  // ------------------------------------------------------------------
  // Save / clear
  // ------------------------------------------------------------------

  int get _selectedCount => _selected.length;

  /// Compare local selections against the day's saved records. Uses
  /// [_savedRecordFor] so a save the server accepted but hasn't echoed back
  /// doesn't count as "unsaved changes" forever.
  int _changedCount(TeacherState state) {
    var changed = 0;
    for (final student in state.currentClassStudents) {
      final savedStatus = _savedRecordFor(student.id, state)?.status;
      if (_selected[student.id] != savedStatus) changed++;
    }
    return changed;
  }

  Future<void> _submitAttendance() async {
    final state = ref.read(teacherProvider);
    final total = state.currentClassStudents.length;

    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students in this class')),
      );
      return;
    }

    // Nothing selected at all — offer "mark everyone present" instead of
    // silently writing a fake all-present register.
    if (_selectedCount == 0) {
      if (!mounted) return;
      final markAll = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No attendance selected'),
          content: Text(
              'You haven\u2019t chosen a status for any of the $total students.\n\n'
              'Mark everyone Present, or cancel and tap students individually.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Mark all Present')),
          ],
        ),
      );
      if (markAll != true || !mounted) return;
      setState(() {
        for (final s in state.currentClassStudents) {
          _selected[s.id] = AttendanceStatus.present;
        }
      });
    }

    // Partial selection — confirm so the teacher knows the rest stay
    // unrecorded (auto-absent applies at 7pm if the day is never completed).
    if (_selectedCount < total) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Save ${_selectedCount} of $total?'),
          content: Text(
              'Only the ${_selectedCount} student${_selectedCount == 1 ? '' : 's'} you selected will be recorded.\n\n'
              'The remaining ${total - _selectedCount} will stay unmarked for '
              '${_isToday ? 'today' : 'this day'} — if nobody completes the day '
              'by 7:00 PM, unmarked students are automatically marked Absent.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Go back')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save selected')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final records = _selected.entries
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

      if (!mounted) return;
      if (success) {
        // The provider re-read the day from the server — report the truth,
        // and say so when the server accepted the save but hasn't echoed it
        // back yet (rather than pretending nothing was saved).
        final after = ref.read(teacherProvider);
        final persisted = after.savedRecordsFor(_selectedDate).length;
        final confirmed = after.currentAttendance.isNotEmpty;
        final day = _isToday
            ? 'today'
            : DateFormat('d MMM yyyy').format(_selectedDate);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                Icon(confirmed ? Icons.check_circle : Icons.cloud_done_outlined,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    confirmed
                        ? 'Saved ✓ — $persisted student${persisted == 1 ? '' : 's'} recorded for $day'
                        : 'Saved $persisted student${persisted == 1 ? '' : 's'} for $day — the server accepted it but has not confirmed the day yet.',
                  ),
                ),
              ],
            ),
            backgroundColor:
                confirmed ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
          ),
        );
      } else {
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

  Future<void> _clearAttendance() async {
    final state = ref.read(teacherProvider);
    if (state.currentAttendance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing saved for this day yet')),
      );
      return;
    }
    final count = state.currentAttendance.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear attendance?'),
        content: Text(
            'This deletes the $count saved record${count == 1 ? '' : 's'} for '
            '${DateFormat('d MMM yyyy').format(_selectedDate)}. The day goes '
            'back to unmarked (and auto-absent applies at 7:00 PM if left that way).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isClearing = true);
    try {
      final ok = await ref.read(teacherProvider.notifier).clearAttendance(
        classId: widget.courseSchedule.studentGroup ?? widget.courseSchedule.id,
        date: _selectedDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(ok
              ? 'Attendance cleared for ${DateFormat('d MMM yyyy').format(_selectedDate)}'
              : (ref.read(teacherProvider).error ?? 'Could not clear attendance')),
          backgroundColor:
              ok ? const Color(0xFFEA580C) : const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _isClearing = false);
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
            status: _exportStatus(students[i].id, state),
          ),
      ],
    );
  }

  /// What goes in the report for one student: the status the teacher is about
  /// to save, otherwise what the day already has saved, otherwise blank.
  String _exportStatus(String studentId, TeacherState state) {
    final picked = _selected[studentId];
    if (picked != null) return _statusLabel(picked);
    final saved = _savedRecordFor(studentId, state);
    return saved == null ? 'Not Marked' : _statusLabel(saved.status);
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

  /// School profile for report branding; null when it can't be loaded.
  Future<SchoolProfileModel?> _loadSchoolProfile() async {
    try {
      return await ref.read(schoolProvider.notifier).load();
    } catch (_) {
      return null;
    }
  }

  /// Export flow: first ask WHICH period (this day / this week / this month /
  /// past 6 months / custom), then build that report.
  Future<void> _showExportSheet() async {
    final state = ref.read(teacherProvider);
    if (state.currentClassStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students loaded yet to export')),
      );
      return;
    }
    final choice = await showAttendanceExportPeriodSheet(
      context,
      day: _selectedDate,
    );
    if (choice == null || !mounted) return;

    if (choice.isSingleDay) {
      await _exportDay();
      return;
    }
    if (choice.period == AttendanceExportPeriod.custom) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: _today.subtract(const Duration(days: _maxHistoryDays)),
        lastDate: _today,
        initialDateRange: DateTimeRange(
          start: _today.subtract(const Duration(days: 30)),
          end: _today,
        ),
        helpText: 'Pick the export period',
        saveText: 'Export',
      );
      if (range == null || !mounted) return;
      await _exportRange(range.start, range.end);
      return;
    }
    await _exportRange(choice.from, choice.to);
  }

  /// Single-day report for the day on screen.
  Future<void> _exportDay() async {
    final data = _buildExportData(ref.read(teacherProvider));
    setState(() => _isExporting = true);
    try {
      final profile = await _loadSchoolProfile();
      await ExportService.instance.applySchoolBranding(data, profile);
      if (!mounted) return;
      await showExportSheet(context, data);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Multi-day report (week / month / past 6 months / custom range). Reads the
  /// real history for the range, so days nobody marked stay blank.
  Future<void> _exportRange(DateTime from, DateTime to) async {
    final messenger = ScaffoldMessenger.of(context);
    final first = _dateKey(from);
    final last = _dateKey(to);
    setState(() => _isExporting = true);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Loading attendance for ${DateFormat('d MMM').format(first)} '
            '– ${DateFormat('d MMM yyyy').format(last)}…'),
        duration: const Duration(seconds: 30),
      ),
    );
    try {
      final notifier = ref.read(teacherProvider.notifier);
      final ok = await notifier.loadAttendanceHistory(
        courseSchedule: widget.courseSchedule,
        from: first,
        to: last,
      );
      if (!mounted) return;
      final history = ref.read(teacherProvider).attendanceHistory;
      if (!ok || history == null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(ref.read(teacherProvider).error ??
                'Could not load attendance for that period'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        return;
      }
      final profile = await _loadSchoolProfile();
      final data = buildHistoryExportData(
        history: history,
        courseSchedule: widget.courseSchedule,
        profile: profile,
        from: first,
        to: last,
      );
      await ExportService.instance.applySchoolBranding(data, profile);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      await showHistoryExportSheet(context, data);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final teacherState = ref.watch(teacherProvider);
    _syncMapForDate(teacherState);

    // "Marked" means records exist for this day — from the server, or from the
    // save this session sent when the confirmation read couldn't see it.
    final saved = teacherState.savedRecordsFor(_selectedDate);
    final dayMarked = saved.isNotEmpty;
    final changed = _changedCount(teacherState);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Mark Attendance', style: TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Attendance history',
            icon: const Icon(Icons.history_rounded, color: Color(0xFF1E3A8A)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AttendanceHistoryScreen(courseSchedule: widget.courseSchedule),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: _isSubmitting || _isExporting ? null : _showExportSheet,
              icon: const Icon(Icons.ios_share, size: 16, color: Color(0xFF1E3A8A)),
              label: const Text('Export',
                  style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 13)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildClassHeader()
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(begin: -0.15),
          _buildDateBar(
            dayMarked: dayMarked,
            loadFailed: teacherState.attendanceLoadError != null,
          ).animate().fadeIn(delay: 100.ms),
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

  /// Date navigation: ◀ [Mon, 23 Sep ▾] ▶ + day-status line.
  Widget _buildDateBar({required bool dayMarked, bool loadFailed = false}) {
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
                        !dayMarked && loadFailed
                            ? 'Saved records could not be loaded'
                            : (_isToday
                                ? (dayMarked
                                    ? 'Today · marked'
                                    : 'Today · not marked yet')
                                : (_isFuture
                                    ? 'Future date'
                                    : (dayMarked
                                        ? 'Past day · saved'
                                        : 'Past day · not marked'))),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: !dayMarked && loadFailed
                              ? const Color(0xFFDC2626)
                              : (dayMarked
                                  ? const Color(0xFF16A34A)
                                  : Colors.orange.shade700),
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
            Icon(Icons.group_off_outlined, size: 64, color: Colors.grey.shade400),
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
          _buildSummaryCards(state),
          const SizedBox(height: 10),
          if (_isFuture)
            _buildFutureBanner()
          else if (!_isToday)
            _buildPastEditBanner()
          else if (!state.isLoadingAttendance &&
              state.attendanceVerified &&
              state.savedRecordsFor(_selectedDate).isEmpty)
            _buildUnmarkedBanner(),
          const SizedBox(height: 10),
          _buildQuickActions(),
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
          Icon(Icons.history_edu_outlined, size: 18, color: Colors.orange.shade800),
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

  Widget _buildUnmarkedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBCFE8)),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 18, color: Colors.pink.shade700),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Tap P, A, H or L next to each student. Nothing is selected by '
              'default — only what you choose gets saved.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF9D174D), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  /// Status counters for the day: what the teacher has picked, falling back to
  /// what is already saved so the numbers are right the moment the day loads.
  Widget _buildSummaryCards(TeacherState state) {
    int count(AttendanceStatus s) => state.currentClassStudents
        .where((student) =>
            (_selected[student.id] ?? _savedRecordFor(student.id, state)?.status) ==
            s)
        .length;

    return Row(
      children: [
        _summaryCard('Present', count(AttendanceStatus.present),
            const Color(0xFF16A34A), Icons.check_circle_outline),
        const SizedBox(width: 8),
        _summaryCard('Absent', count(AttendanceStatus.absent),
            const Color(0xFFDC2626), Icons.cancel_outlined),
        const SizedBox(width: 8),
        _summaryCard('Half', count(AttendanceStatus.halfDay),
            const Color(0xFFEA580C), Icons.wb_twilight_outlined),
        const SizedBox(width: 8),
        _summaryCard('Leave', count(AttendanceStatus.leave),
            const Color(0xFF2563EB), Icons.airline_seat_individual_suite_outlined),
      ],
    );
  }

  Widget _summaryCard(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 3),
            Text('$value',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                for (final s in ref
                    .read(teacherProvider)
                    .currentClassStudents) {
                  _selected[s.id] = AttendanceStatus.present;
                }
              });
            },
            icon: const Icon(Icons.done_all, size: 17),
            label: const Text('All Present'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF16A34A),
              side: BorderSide(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                for (final s in ref
                    .read(teacherProvider)
                    .currentClassStudents) {
                  _selected[s.id] = AttendanceStatus.absent;
                }
              });
            },
            icon: const Icon(Icons.remove_done, size: 17),
            label: const Text('All Absent'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: BorderSide(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() => _selected.clear());
            },
            icon: const Icon(Icons.clear_all, size: 17),
            label: const Text('Reset'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: BorderSide(
                  color: const Color(0xFF64748B).withValues(alpha: 0.4)),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final currentStatus = _statusOf(student.id, state);
    final savedRecord = _savedRecordFor(student.id, state);
    final hasSaved = savedRecord != null;
    final isModified =
        currentStatus != null && hasSaved && currentStatus != savedRecord.status;
    final subtitle = _studentSubtitle(
      current: currentStatus,
      saved: savedRecord,
      verified: state.attendanceVerified,
    );
    final accent = currentStatus != null
        ? _getStatusColor(currentStatus)
        : (hasSaved ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isModified
              ? accent.withValues(alpha: 0.6)
              : const Color(0xFFE2E8F0),
          width: isModified ? 1.4 : 1,
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
            backgroundColor: currentStatus != null
                ? accent.withValues(alpha: 0.13)
                : const Color(0xFFF1F5F9),
            child: currentStatus != null
                ? Text(
                    student.name.isNotEmpty
                        ? student.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 15))
                : Icon(Icons.person_outline, size: 20, color: accent),
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
                  subtitle,
                  style: TextStyle(
                    color: isModified
                        ? const Color(0xFFEA580C)
                        : (hasSaved
                            ? const Color(0xFF16A34A)
                            : Colors.grey.shade500),
                    fontSize: 11.5,
                    fontWeight:
                        isModified || hasSaved ? FontWeight.w600 : FontWeight.w500,
                  ),
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

  /// One line of truth per student: what is on the server, what the teacher
  /// has changed since, and whether the server has confirmed the last save.
  String _studentSubtitle({
    required AttendanceStatus? current,
    required AttendanceModel? saved,
    required bool verified,
  }) {
    if (saved == null) {
      return current != null ? 'Not saved yet — tap Save' : 'Not selected';
    }
    if (current != null && current != saved.status) {
      return 'Saved: ${saved.statusString} → unsaved change';
    }
    return verified
        ? 'Saved: ${saved.statusString}'
        : 'Saved: ${saved.statusString} · accepted by server';
  }

  /// Four status chips; all appear unselected until the teacher picks one.
  Widget _buildStatusChips(String studentId, AttendanceStatus? currentStatus) {
    Widget chip(AttendanceStatus status, String label, Color color) {
      final selected = currentStatus == status;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            if (selected) {
              _selected.remove(studentId); // tap again to unselect
            } else {
              _selected[studentId] = status;
            }
          });
        },
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
        !_isClearing &&
        !state.isLoadingAttendance;

    // What the teacher needs to know about this day: unsaved edits, what the
    // server confirmed, a save the server accepted but hasn't echoed back, or
    // a read that failed (which used to look exactly like "nothing saved").
    final saved = state.savedRecordsFor(_selectedDate);
    final loadError = state.attendanceLoadError;
    final String status;
    final Color statusColor;
    if (_isFuture) {
      status = 'Future date — saving disabled';
      statusColor = Colors.grey.shade600;
    } else if (changed > 0) {
      status = '$changed unsaved change${changed == 1 ? '' : 's'}';
      statusColor = const Color(0xFFEA580C);
    } else if (state.currentAttendance.isNotEmpty) {
      status = 'Saved on the server: ${state.currentAttendance.length} '
          'record${state.currentAttendance.length == 1 ? '' : 's'}';
      statusColor = const Color(0xFF16A34A);
    } else if (saved.isNotEmpty) {
      status = 'Saved: ${saved.length} record${saved.length == 1 ? '' : 's'} '
          '· server confirmation pending';
      statusColor = const Color(0xFFEA580C);
    } else if (loadError != null) {
      status = 'Could not load saved records — pull down to retry';
      statusColor = const Color(0xFFDC2626);
    } else if (state.isLoadingAttendance) {
      status = 'Checking what is saved…';
      statusColor = Colors.grey.shade600;
    } else if (!state.attendanceVerified) {
      status = 'Nothing saved yet — pull down to check the server again';
      statusColor = Colors.grey.shade600;
    } else {
      status = 'Nothing saved yet for this day';
      statusColor = Colors.grey.shade600;
    }

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_selectedCount}/${state.currentClassStudents.length} selected · '
                      '${DateFormat('d MMM yyyy').format(_selectedDate)}',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          if (state.currentAttendance.isNotEmpty && !_isFuture) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                onPressed: _isClearing || _isSubmitting ? null : _clearAttendance,
                icon: _isClearing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_sweep_outlined, size: 17),
                label: Text(
                  _isClearing
                      ? 'Clearing…'
                      : 'Clear Attendance (${state.currentAttendance.length} saved)',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: BorderSide(
                      color:
                          const Color(0xFFDC2626).withValues(alpha: 0.35)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
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
