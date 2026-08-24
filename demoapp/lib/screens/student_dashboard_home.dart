import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';
import '../state/student_provider.dart';
import '../state/auth_provider.dart';
import '../models/assignment_model.dart';
import '../utils/responsive.dart';
import '../utils/time_format.dart';
import '../widgets/school_header.dart';

class StudentDashboardHome extends ConsumerStatefulWidget {
  const StudentDashboardHome({super.key});

  @override
  ConsumerState<StudentDashboardHome> createState() => _StudentDashboardHomeState();
}

class _StudentDashboardHomeState extends ConsumerState<StudentDashboardHome> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _hasLoaded = false;
  int _loadAttempts = 0;

  // Per-month calendar data (fetched from the backend so month navigation
  // works — the dashboard summary only carries the current month).
  Map<int, String> _monthStatus = {}; // day -> status
  bool _monthLoading = false;
  String? _monthError;
  DateTime? _fetchedMonth;

  @override
  void initState() {
    super.initState();
    // Load the dashboard once the session is ready (a session-restore race
    // could otherwise fire requests before the JWT is loaded, leaving the
    // dashboard empty until the tab is re-opened).
    // The dashboard load AND the calendar's month fetch both happen via
    // _loadWhenReady(), which waits for the session to be ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWhenReady();
    });
  }

  /// Loads the dashboard exactly once per mount, but only once the session
  /// is ready. If the first attempt fails (transient error, e.g. the dev
  /// server's module reloader), retries a couple of times instead of leaving
  /// the dashboard empty until the widget is recreated.
  void _loadWhenReady() {
    final auth = ref.read(authProvider);
    if (auth.isLoading || !auth.isAuthenticated) return;
    final st = ref.read(studentProvider);
    final needsLoad = !_hasLoaded ||
        (st.attendanceSummary == null && !st.isLoading && _loadAttempts < 3);
    if (needsLoad) {
      _hasLoaded = true;
      _loadAttempts++;
      ref.read(studentProvider.notifier).loadDashboard();
    }
    // The calendar fetches its month once the session is ready (if the
    // widget mounted before restore finished, the first fetch may have
    // 401'd — re-fire it now).
    if (_fetchedMonth == null && !_monthLoading) {
      _fetchMonth(_visibleMonth);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
    _fetchMonth(_visibleMonth);
  }

  Future<void> _fetchMonth(DateTime month) async {
    if (_monthLoading) return;
    // Already loaded this month successfully — don't refetch on every build.
    if (_fetchedMonth != null &&
        _fetchedMonth!.year == month.year &&
        _fetchedMonth!.month == month.month &&
        _monthError == null) {
      return;
    }
    setState(() {
      _monthLoading = true;
      _monthError = null;
    });
    try {
      final records =
          await ref.read(demoApiServiceProvider).getMyAttendanceForMonth(month.year, month.month);
      if (!mounted) return;
      setState(() {
        _monthStatus = {
          for (final r in records)
            if (r['date'] != null) DateTime.parse(r['date'] as String).day: (r['status'] as String?) ?? 'Present',
        };
        _fetchedMonth = month;
        _monthLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchedMonth = month; // don't auto-loop; the retry row re-fetches
        _monthLoading = false;
        _monthError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentState = ref.watch(studentProvider);
    final user = ref.watch(authProvider).user;
    final userName = user?.fullName.split(' ').first ?? 'Student';

    // Keep (re)trying until data arrives: fires after every build while the
    // session is ready and the dashboard has no data (bounded by attempts).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWhenReady();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: studentState.isLoading && studentState.attendanceSummary == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your dashboard...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                _hasLoaded = false;
                await ref.read(studentProvider.notifier).loadDashboard();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildHeader(context, userName),
                  SliverToBoxAdapter(
                    child: ResponsiveCenter(
                      maxWidth: 760,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildQuickStats(context, studentState),
                            const SizedBox(height: 20),
                            _buildOverallAttendance(context, studentState),
                            const SizedBox(height: 20),
                            _buildSectionTitle(context, 'Subject-wise Attendance'),
                            const SizedBox(height: 12),
                            _buildSubjectScroll(studentState),
                            const SizedBox(height: 20),
                            _buildSectionTitle(context, 'This Month'),
                            const SizedBox(height: 12),
                            _buildCalendar(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context, String userName) {
    return SliverAppBar(
      expandedHeight: 160.0,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Color(0xFF192A88)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white24,
                          child: Text(
                            userName.isNotEmpty ? userName[0] : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Hi, $userName 👋',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.auto_awesome,
                                  color: AppColors.secondaryContainer,
                                  size: 18,
                                ).animate(
                                  onPlay: (controller) => controller.repeat(reverse: true),
                                ).scale(
                                  begin: const Offset(0.8, 0.8),
                                  end: const Offset(1.2, 1.2),
                                  duration: 1000.ms,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ready to learn today?',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.notifications_outlined, color: Colors.white, size: 18),
                            const SizedBox(width: 4),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.secondaryContainer,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // School identity (name + logo) — always visible on the dashboard.
                  SchoolHeader(compact: true, textColor: Colors.white, showMotto: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, StudentState state) {
    final assignments = state.assignments;
    final dueSoon = assignments.where((a) => 
      a.dueDate != null && 
      a.dueDate!.isAfter(DateTime.now()) && 
      a.dueDate!.isBefore(DateTime.now().add(const Duration(days: 7)))
    ).length;

    return Row(
      children: [
        _buildStatCard(
          icon: Icons.assignment_outlined,
          value: assignments.length.toString(),
          label: 'Assignments',
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.pending_actions_outlined,
          value: dueSoon.toString(),
          label: 'Due Soon',
          color: AppColors.secondaryContainer,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          icon: Icons.check_circle_outline,
          value: '${(state.attendanceSummary?.overallPercentage ?? 0).toInt()}%',
          label: 'Attendance',
          color: AppColors.tertiary,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairlineBorder),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallAttendance(BuildContext context, StudentState state) {
    final double attendancePercentage = state.attendanceSummary?.overallPercentage ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.9),
            AppColors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You are doing great! Keep it up.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: AppColors.secondaryContainer,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '5-day streak!',
                      style: TextStyle(
                        color: AppColors.secondaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ).animate().shake(hz: 4, curve: Curves.easeInOutCubic, duration: 800.ms),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 90,
            width: 90,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: attendancePercentage / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  color: Colors.white,
                  strokeCap: StrokeCap.round,
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${attendancePercentage.toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Present',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectScroll(StudentState state) {
    final courseWise = state.attendanceSummary?.courseWisePercentage ?? {};
    
    if (courseWise.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairlineBorder),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.school_outlined, size: 40, color: AppColors.outline),
              SizedBox(height: 8),
              Text(
                'No subject attendance available',
                style: TextStyle(color: AppColors.outline),
              ),
            ],
          ),
        ),
      );
    }
    
    final courses = courseWise.keys.toList();
    
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: courses.length,
        itemBuilder: (context, index) {
          final subject = courses[index];
          final percentage = courseWise[subject] ?? 0.0;
          
          Color color = AppColors.tertiary;
          if (percentage < 50) {
            color = AppColors.error;
          } else if (percentage < 75) {
            color = AppColors.secondaryContainer;
          }
          
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildSubjectCard(subject, percentage.toInt(), color),
          );
        },
      ),
    );
  }

  Widget _buildSubjectCard(String subject, int percentage, Color color) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairlineBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.analytics_outlined, size: 12, color: color),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$percentage%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: AppColors.hairlineBorder,
                color: color,
                borderRadius: BorderRadius.circular(3),
                minHeight: 4,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: 100));
  }

  Widget _buildCalendar() {
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final now = DateTime.now();
    final isCurrentMonth = _visibleMonth.year == now.year && _visibleMonth.month == now.month;
    final today = now.day;

    Color? colorFor(String? status) {
      switch (status) {
        case 'Present':
          return AppColors.tertiary.withValues(alpha: 0.25);
        case 'Absent':
          return AppColors.error.withValues(alpha: 0.25);
        case 'Half Day':
          return AppColors.secondaryContainer.withValues(alpha: 0.3);
        case 'Leave':
          return AppColors.info.withValues(alpha: 0.25);
        default:
          return null;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairlineBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () => _changeMonth(-1),
              ),
              Row(
                children: [
                  Text(
                    '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  if (_monthLoading) ...[const SizedBox(width: 8), const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a day to see its assignments',
            style: TextStyle(fontSize: 10, color: AppColors.outline.withValues(alpha: 0.8)),
          ),
          if (_monthError != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _fetchMonth(_visibleMonth),
              child: Text(
                "Couldn't load this month — tap to retry",
                style: TextStyle(fontSize: 10, color: AppColors.error),
              ),
            ),
          ],
          const SizedBox(height: 8),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final day = index + 1;
              final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
              // Future days stay neutral — attendance can't exist ahead of today.
              final isFuture = date.isAfter(now);
              final hasRecord = !isFuture && _monthStatus.containsKey(day);
              final bgColor = hasRecord ? colorFor(_monthStatus[day]) : Colors.transparent;
              final isToday = isCurrentMonth && day == today;

              return GestureDetector(
                onTap: () => _showDaySheet(date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.primary : bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(color: AppColors.primary, width: 2)
                        : hasRecord
                            ? Border.all(color: _monthStatus[day] == 'Leave' ? AppColors.info : Colors.transparent, width: 0.5)
                            : null,
                    boxShadow: isToday ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      color: isToday ? Colors.white : AppColors.onSurface,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LegendDot(color: AppColors.tertiary, label: 'Present'),
              _LegendDot(color: AppColors.error, label: 'Absent'),
              _LegendDot(color: AppColors.secondaryContainer, label: 'Half Day'),
              _LegendDot(color: AppColors.info, label: 'Leave'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// Bottom sheet for one calendar day: attendance status + assignments
  /// scheduled on that date.
  Future<void> _showDaySheet(DateTime date) async {
    final status = _monthStatus[date.day];
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DaySheet(date: date, status: status),
    );
  }

  String _monthName(int month) => _monthNameOf(month);
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.outline)),
      ],
    );
  }
}

/// Bottom sheet shown when a calendar day is tapped: that day's attendance
/// status plus every assignment scheduled on it.
class _DaySheet extends ConsumerStatefulWidget {
  final DateTime date;
  final String? status;

  const _DaySheet({required this.date, this.status});

  @override
  ConsumerState<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends ConsumerState<_DaySheet> {
  List<AssignmentModel>? _assignments;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(demoApiServiceProvider)
          .getAssignmentsOnDate(widget.date);
      if (!mounted) return;
      setState(() {
        _assignments = list;
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

  Color? _statusColor(String? status) {
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
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = _monthNameOf(widget.date.month);
    final dayLabel = '${weekdayName(widget.date.weekday)}, $monthName ${widget.date.day}';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairlineBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  dayLabel,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (widget.status != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_statusColor(widget.status) ?? AppColors.outline).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.status!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(widget.status) ?? AppColors.outline,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Assignments on this day',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.outline),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, color: AppColors.outline, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    'Could not load assignments',
                    style: TextStyle(fontSize: 12, color: AppColors.outline),
                  ),
                ],
              ),
            )
          else if (_assignments!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.event_available_outlined, color: AppColors.outline, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    'No assignments on this day',
                    style: TextStyle(fontSize: 12, color: AppColors.outline),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _assignments!.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final a = _assignments![index];
                  final status = a.submissionStatus;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 20),
                    ),
                    title: Text(
                      a.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text(
                      [
                        if (a.courseName != null) a.courseName!,
                        if (a.studentGroupName != null) a.studentGroupName!,
                        if (a.fromTime != null)
                          formatTime12h(a.fromTime),
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: status != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.tertiary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.tertiary,
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

String _monthNameOf(int month) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return names[month - 1];
}

String weekdayName(int weekday) {
  const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return names[weekday - 1];
}
