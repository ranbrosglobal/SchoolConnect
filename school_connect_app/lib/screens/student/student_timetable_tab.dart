import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/timetable_model.dart';
import '../../state/assistant_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/student_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';
import '../assistant/assistant_screen.dart';

/// Weekly timetable built from the real schedule grid.
class StudentTimetableTab extends ConsumerStatefulWidget {
  const StudentTimetableTab({super.key});

  @override
  ConsumerState<StudentTimetableTab> createState() => _StudentTimetableTabState();
}

class _StudentTimetableTabState extends ConsumerState<StudentTimetableTab> {
  TimetableModel? _timetable;
  DateTime _selected = DateTime.now();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      final timetable = await ref.read(apiServiceProvider).getMyTimetable();
      _timetable = timetable;
      await ref.read(assistantProvider.notifier).syncData(fetchTimetable: true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Monday of the displayed week.
  DateTime get _weekStart {
    final base = _timetable?.weekStart;
    if (base != null) {
      final d = DateTime(base.year, base.month, base.day);
      if (_sameWeek(d, _selected)) return d;
    }
    final wd = _selected.weekday;
    return DateTime(_selected.year, _selected.month, _selected.day - (wd - 1));
  }

  bool _sameWeek(DateTime a, DateTime b) {
    final aw = DateTime(a.year, a.month, a.day - (a.weekday - 1));
    final bw = DateTime(b.year, b.month, b.day - (b.weekday - 1));
    return aw == bw;
  }

  List<ScheduleRow> get _dayRows {
    final rows = _timetable?.timetable ?? const [];
    return rows.where((r) => _isSameDay(r.date, _selected)).toList()
      ..sort((a, b) => (a.fromTime ?? '').compareTo(b.fromTime ?? ''));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isNow(ScheduleRow r) {
    final now = DateTime.now();
    if (!_isSameDay(r.date, now)) return false;
    final start = _parse(r.fromTime);
    final end = _parse(r.toTime);
    if (start == null || end == null) return false;
    return !now.isBefore(start) && now.isBefore(end);
  }

  DateTime? _parse(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return null;
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first);
    if (h == null) return null;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, h, m);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _dayRows;
    final weekStart = _weekStart;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.studentAccent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: GradientHeader(
                role: AppRoleStyle.student,
                eyebrow: 'Week of ${DateFormat('d MMMM').format(weekStart)}',
                title: 'Timetable',
                subtitle: rows.isEmpty
                    ? 'Nothing scheduled for '
                        '${DateFormat('EEEE').format(_selected)}'
                    : '${rows.length} class${rows.length == 1 ? '' : 'es'} on '
                        '${DateFormat('EEEE').format(_selected)}',
                actions: [
                  HeaderIconButton(
                    icon: Icons.auto_awesome_rounded,
                    tooltip: 'Ask about my schedule',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AssistantScreen()),
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(child: _weekStrip(weekStart)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading && _timetable == null)
                    ...const [
                      SkeletonCard(lines: 2),
                      SizedBox(height: 12),
                      SkeletonCard(lines: 2),
                    ]
                  else if (_error != null)
                    ErrorState(message: _error!, onRetry: _load)
                  else if (rows.isEmpty)
                    EmptyState(
                      icon: Icons.event_busy_rounded,
                      title: 'No classes ${DateFormat('EEEE').format(_selected)}',
                      message: 'Pick another day above, or use the free time to get ahead.',
                      actionLabel: 'Open study assistant',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AssistantScreen()),
                      ),
                    )
                  else
                    StaggeredList(
                      count: rows.length,
                      builder: (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _classCard(rows[i], i, rows.length),
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Week strip ──────────────────────────────────────────────────────────

  Widget _weekStrip(DateTime weekStart) {
    final today = DateTime.now();
    final days = List.generate(5, (i) => weekStart.add(Duration(days: i)));
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.hairlineBorder),
        boxShadow: AppShadows.card(),
      ),
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: _dayNode(
                day: d,
                selected: _isSameDay(d, _selected),
                isToday: _isSameDay(d, today),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayNode({
    required DateTime day,
    required bool selected,
    required bool isToday,
  }) {
    return Pressable(
      onTap: () => setState(() => _selected = day),
      borderRadius: AppRadius.brMd,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(vertical: 9),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.student : null,
          color: selected ? null : Colors.transparent,
          borderRadius: AppRadius.brMd,
          boxShadow: selected
              ? AppShadows.glow(AppColors.studentAccent, strength: 0.26)
              : null,
        ),
        child: Column(
          children: [
            Text(
              DateFormat('E').format(day).substring(0, 2),
              style: AppText.caption.copyWith(
                fontSize: 10.5,
                color: selected ? Colors.white.withValues(alpha: 0.9) : AppColors.inkFaint,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: AppText.cardTitle.copyWith(
                fontSize: 15,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday
                    ? (selected ? Colors.white : AppColors.studentAccent)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Class cards ─────────────────────────────────────────────────────────

  Widget _classCard(ScheduleRow row, int index, int total) {
    final isNow = _isNow(row);
    final palette = [
      AppColors.studentAccent,
      AppColors.tertiary,
      AppColors.secondary,
      AppColors.adminAccent,
      AppColors.warning,
    ];
    final accent = palette[index % palette.length];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 16),
                Text(
                  row.fromTime ?? '—',
                  style: AppText.cardTitle.copyWith(
                    fontSize: 12.5,
                    color: isNow ? AppColors.success : AppColors.ink,
                  ),
                ),
                if (row.toTime != null) ...[
                  const SizedBox(height: 2),
                  Text(row.toTime!, style: AppText.caption.copyWith(fontSize: 10.5)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 18),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNow ? AppColors.success : AppColors.surface,
                  border: Border.all(
                    color: isNow ? AppColors.success : accent,
                    width: 2,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: index == total - 1
                      ? Colors.transparent
                      : AppColors.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                color: isNow ? AppColors.successSoft : null,
                borderColor: isNow
                    ? AppColors.success.withValues(alpha: 0.35)
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.13),
                            borderRadius: AppRadius.brSm,
                          ),
                          child: Icon(Icons.menu_book_rounded, size: 17, color: accent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.courseName,
                                style: AppText.cardTitle.copyWith(fontSize: 14.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                row.studentGroupName ?? 'Your class',
                                style: AppText.caption.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (isNow)
                          const StatusPill(label: 'NOW', tone: PillTone.success, dense: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (row.instructorName != null)
                          StatusPill(
                            label: row.instructorName!,
                            icon: Icons.person_outline_rounded,
                            dense: true,
                            accentOverride: accent,
                            tone: PillTone.accent,
                          ),
                        if (row.room != null)
                          StatusPill(
                            label: 'Room ${row.room}',
                            icon: Icons.meeting_room_outlined,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
