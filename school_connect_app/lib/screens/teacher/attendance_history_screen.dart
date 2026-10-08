import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../models/course_schedule_model.dart';
import '../../models/attendance_model.dart';
import '../../models/school_profile_model.dart';
import '../../services/export_service.dart';
import '../../services/google_sheets_service.dart';
import '../../state/school_provider.dart';
import '../../state/teacher_provider.dart';
import '../../widgets/export_sheet.dart';
import 'attendance_marking_screen.dart';

/// Attendance history for one class across a selectable date range:
/// This Week / This Month / This Quarter / This Year / Custom.
///
/// Shows a summary card, a day-by-day timeline, a per-student breakdown
/// and the raw record list — everything a teacher needs to review past
/// attendance without exporting a spreadsheet.
class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  final CourseScheduleModel courseSchedule;

  const AttendanceHistoryScreen({super.key, required this.courseSchedule});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

enum _RangePreset { week, month, quarter, year, custom }

/// Builds the export payload for a date-range attendance report.
///
/// Shared by this screen and the attendance marking screen's "which period?"
/// export, so one report layout serves every caller. Days nobody marked are
/// carried only by [AttendanceHistoryExportData.from]/[to] — the PDF lists
/// them blank rather than inventing a status.
AttendanceHistoryExportData buildHistoryExportData({
  required AttendanceHistory history,
  required CourseScheduleModel courseSchedule,
  SchoolProfileModel? profile,
  DateTime? from,
  DateTime? to,
}) {
  return AttendanceHistoryExportData(
    className: courseSchedule.studentGroupName ??
        courseSchedule.studentGroup ??
        history.className,
    subject:
        courseSchedule.courseName ?? courseSchedule.course ?? 'Subject',
    teacher: courseSchedule.instructorName ?? 'Teacher',
    room: courseSchedule.room ?? '',
    from: from ?? history.from,
    to: to ?? history.to,
    totalRecords: history.summary.totalRecords,
    markedDays: history.summary.markedDays,
    presentCount: history.summary.present,
    absentCount: history.summary.absent,
    lateCount: history.summary.late,
    leaveCount: history.summary.leave,
    halfDayCount: history.summary.halfDay,
    percentage: history.summary.percentage,
    days: [
      for (final d in history.days)
        AttendanceHistoryExportDay(
          date: d.date,
          marked: d.marked,
          present: d.present,
          absent: d.absent,
          percentage: d.percentage,
        ),
    ],
    students: [
      for (final s in history.students)
        AttendanceHistoryExportStudent(
          roll: s.rollNumber ?? '—',
          name: s.studentName,
          total: s.total,
          present: s.present,
          absent: s.absent,
          percentage: s.percentage,
        ),
    ],
    records: [
      for (final r in history.records)
        AttendanceHistoryExportRecord(
          date: r.date ?? DateTime.now(),
          name: r.studentName ?? 'Unknown',
          status: r.statusString,
        ),
    ],
    schoolName: profile?.schoolName ?? '',
    schoolMotto: profile?.motto ?? '',
    schoolEmail: profile?.contactEmail ?? '',
    schoolPhone: profile?.contactNumber ?? '',
    schoolWebsite: profile?.website ?? '',
    schoolAddress: profile?.address ?? '',
  );
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  _RangePreset _preset = _RangePreset.month;
  late DateTime _from;
  late DateTime _to;
  String? _error;
  bool _loading = false;
  bool _isExporting = false;

  final DateFormat _df = DateFormat('d MMM yyyy');
  int _tabIndex = 0; // 0 days · 1 students · 2 records

  @override
  void initState() {
    super.initState();
    final range = _rangeFor(_preset);
    _from = range.$1;
    _to = range.$2;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  (DateTime, DateTime) _rangeFor(_RangePreset preset) {
    final now = DateTime.now();
    switch (preset) {
      case _RangePreset.week:
        final monday = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - DateTime.monday));
        return (monday, now);
      case _RangePreset.month:
        return (DateTime(now.year, now.month, 1), now);
      case _RangePreset.quarter:
        final qMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return (DateTime(now.year, qMonth, 1), now);
      case _RangePreset.year:
        return (DateTime(now.year, 1, 1), now);
      case _RangePreset.custom:
        return (_from, _to);
    }
  }

  String get _presetLabel {
    switch (_preset) {
      case _RangePreset.week:
        return 'This Week';
      case _RangePreset.month:
        return 'This Month';
      case _RangePreset.quarter:
        return 'This Quarter';
      case _RangePreset.year:
        return 'This Year';
      case _RangePreset.custom:
        return 'Custom Range';
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });        final ok = await ref.read(teacherProvider.notifier).loadAttendanceHistory(
      courseSchedule: widget.courseSchedule,
      from: _from,
      to: _to,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!ok) _error = ref.read(teacherProvider).error ?? 'Failed to load history';
    });
  }

  Future<void> _pickPreset() async {
    final picked = await showModalBottomSheet<_RangePreset>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose date range',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            _presetTile('This Week', 'From Monday to today', Icons.view_week_outlined,
                _RangePreset.week),
            _presetTile('This Month', 'From the 1st to today',
                Icons.calendar_month_outlined, _RangePreset.month),
            _presetTile('This Quarter', 'Last three months to today',
                Icons.calendar_view_month_outlined, _RangePreset.quarter),
            _presetTile('This Year', 'From January 1st to today',
                Icons.calendar_today_outlined, _RangePreset.year),
            _presetTile('Custom Range', 'Pick any start and end date',
                Icons.date_range_outlined, _RangePreset.custom),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked == _RangePreset.custom) {
      final ok = await _pickCustomRange();
      if (!ok) return;
    }
    setState(() => _preset = picked);
    final range = _rangeFor(picked);
    setState(() {
      _from = range.$1;
      _to = range.$2;
    });
    _load();
  }

  Future<bool> _pickCustomRange() async {
    final now = DateTime.now();
    DateTime from = _from;
    DateTime? to;
    final first = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now,
      helpText: 'Start of range',
    );
    if (first == null || !mounted) return false;
    from = first;
    final second = await showDatePicker(
      context: context,
      initialDate: _to.isBefore(first) ? now : _to,
      firstDate: first,
      lastDate: now,
      helpText: 'End of range',
    );
    if (second == null) return false;
    to = second;
    setState(() {
      _from = from;
      _to = to!;
    });
    return true;
  }

  // ------------------------------------------------------------------
  // Export (range PDF → download, share, print)
  // ------------------------------------------------------------------

  Future<void> _showExportSheet() async {
    final history = ref.read(teacherProvider).attendanceHistory;
    if (history == null) return;
    setState(() => _isExporting = true);
    try {
      // Best-effort school branding for the report header.
      SchoolProfileModel? profile;
      try {
        profile = await ref.read(schoolProvider.notifier).load();
      } catch (_) {}
      final data = buildHistoryExportData(
        history: history,
        courseSchedule: widget.courseSchedule,
        profile: profile,
      );
      await ExportService.instance.applySchoolBranding(data, profile);
      if (!mounted) return;
      await showHistoryExportSheet(context, data);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherProvider);
    final history = state.attendanceHistory;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Attendance History', style: TextStyle(fontSize: 17)),
        actions: [
          if (history != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: _isExporting ? null : _showExportSheet,
                icon: const Icon(Icons.ios_share,
                    size: 16, color: Color(0xFF1E3A8A)),
                label: const Text('Export',
                    style:
                        TextStyle(color: Color(0xFF1E3A8A), fontSize: 13)),
              ),
            ),
        ],
      ),
      body: _loading && history == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && history == null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      _buildRangeSelector(),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(14),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          ),
                        ),
                      if (history != null) ...[
                        _buildSummaryCard(history),
                        const SizedBox(height: 14),
                        _buildTabs(),
                        const SizedBox(height: 10),
                        if (_tabIndex == 0) _buildDays(history),
                        if (_tabIndex == 1) _buildStudents(history),
                        if (_tabIndex == 2) _buildRecords(history),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          const Text('Couldn\u2019t load attendance history'),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _pickPreset,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.filter_alt_outlined,
                    size: 18, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_presetLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 1),
                    Text(
                      '${_df.format(_from)} — ${_df.format(_to)}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF4F46E5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetTile(String title, String subtitle, IconData icon, _RangePreset preset) {
    final selected = _preset == preset;
    return ListTile(
      leading: Icon(icon, color: selected ? const Color(0xFF4F46E5) : Colors.grey.shade600),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? const Color(0xFF4F46E5) : null)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
      trailing:
          selected ? const Icon(Icons.check_rounded, color: Color(0xFF4F46E5)) : null,
      onTap: () => Navigator.pop(context, preset),
    );
  }

  Widget _buildSummaryCard(AttendanceHistory history) {
    final s = history.summary;
    final pct = s.percentage;
    final pctColor =
        pct >= 75 ? const Color(0xFF16A34A) : pct >= 50 ? const Color(0xFFEA580C) : const Color(0xFFDC2626);

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(history.className,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text('$pct% attendance',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      '${s.totalRecords} records over ${s.markedDays} marked day${s.markedDays == 1 ? '' : 's'}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 62,
                height: 62,
                child: Stack(
                  children: [
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            pct >= 75 ? const Color(0xFF4ADE80) : const Color(0xFFFDE047)),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Center(
                      child: Icon(
                        pct >= 75 ? Icons.emoji_events_outlined : Icons.flag_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _pill('Present', s.present, const Color(0xFF4ADE80)),
              const SizedBox(width: 8),
              _pill('Absent', s.absent, const Color(0xFFFCA5A5)),
              const SizedBox(width: 8),
              _pill('Late', s.late, const Color(0xFFFCD34D)),
              const SizedBox(width: 8),
              _pill('Leave', s.leave, const Color(0xFF93C5FD)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08);
  }

  Widget _pill(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    Widget tab(int index, String label, IconData icon) {
      final selected = _tabIndex == index;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _tabIndex = index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF1E3A8A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 15,
                    color: selected ? Colors.white : Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : Colors.grey.shade700)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(0, 'Days', Icons.calendar_view_day_outlined),
        const SizedBox(width: 6),
        tab(1, 'Students', Icons.groups_outlined),
        const SizedBox(width: 6),
        tab(2, 'Records', Icons.receipt_long_outlined),
      ],
    );
  }

  // ── Tab 1: days ──────────────────────────────────────────────────────

  /// Open the marking screen on one specific day to view or fix it up;
  /// reload the history when the teacher comes back.
  Future<void> _openDay(DateTime date) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceMarkingScreen(
          courseSchedule: widget.courseSchedule,
          initialDate: date,
        ),
      ),
    );
    if (mounted) _load();
  }

  Widget _buildDays(AttendanceHistory history) {
    if (history.days.isEmpty) {
      return _empty('No attendance was marked in this range',
          'Pick a different range from the selector above.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Tap a day to view or edit its attendance',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
        ),
        ...history.days.asMap().entries.map((e) {
          final day = e.value;
          final weekday = DateFormat('EEEE').format(day.date);
        final color = day.percentage >= 75
            ? const Color(0xFF16A34A)
            : day.percentage >= 50
                ? const Color(0xFFEA580C)
                : const Color(0xFFDC2626);
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDay(day.date),
          child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(DateFormat('d').format(day.date),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(DateFormat('MMM').format(day.date),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(weekday,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      '${day.present} present · ${day.absent} absent · ${day.marked} marked',
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Text('${day.percentage}%',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: color)),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
        )
            .animate()
            .fadeIn(
                duration: 220.ms,
                delay: Duration(milliseconds: (30 * e.key).clamp(0, 400)));
        }),
      ],
    );
  }

  // ── Tab 2: students ──────────────────────────────────────────────────

  Widget _buildStudents(AttendanceHistory history) {
    final withData = history.students
        .where((s) => (s.percentage ?? -1) >= 0)
        .toList()
      ..sort((a, b) => (a.percentage ?? 0).compareTo(b.percentage ?? 0));
    if (withData.isEmpty) {
      return _empty('No student attendance in this range',
          'Students appear here after you mark attendance.');
    }
    return Column(
      children: withData.asMap().entries.map((e) {
        final s = e.value;
        final pct = s.percentage ?? 0;
        final color = pct >= 75
            ? const Color(0xFF16A34A)
            : pct >= 50
                ? const Color(0xFFEA580C)
                : const Color(0xFFDC2626);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: color.withValues(alpha: 0.13),
                child: Text(
                  s.studentName.isNotEmpty
                      ? s.studentName.substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.studentName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      '$pct% · ${s.present}/${s.total} present'
                      '${s.absent > 0 ? ' · ${s.absent} absent' : ''}',
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFEEF2F7),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(
                duration: 220.ms,
                delay: Duration(milliseconds: (30 * e.key).clamp(0, 500)));
      }).toList(),
    );
  }

  // ── Tab 3: records ───────────────────────────────────────────────────

  Widget _buildRecords(AttendanceHistory history) {
    if (history.records.isEmpty) {
      return _empty('No attendance records in this range', '');
    }
    return Column(
      children: history.records.asMap().entries.map((e) {
        final r = e.value;
        final status = r.status;
        final color = _statusColor(status);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEDF1F7)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon(status), size: 17, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.studentName ?? 'Unknown student',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 1),
                    Text(
                      r.date != null
                          ? DateFormat('EEEE, d MMM yyyy').format(r.date!)
                          : '',
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status == AttendanceStatus.present ? 'Present' : r.statusString,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _statusColor(AttendanceStatus status) {
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

  IconData _statusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check_circle_outline;
      case AttendanceStatus.absent:
        return Icons.cancel_outlined;
      case AttendanceStatus.halfDay:
        return Icons.wb_twilight_outlined;
      case AttendanceStatus.leave:
        return Icons.airline_seat_individual_suite_outlined;
    }
  }

  Widget _empty(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.event_note_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }
}
