import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/super_school_model.dart';
import '../../services/google_sheets_service.dart' show AdminDashboardData;
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';

/// Shared chart palette. Colors cycle when a chart has more slices than entries.
const List<Color> _palette = <Color>[
  AppColors.adminAccent,
  AppColors.primary,
  AppColors.tertiary,
  AppColors.warning,
  AppColors.danger,
  AppColors.secondary,
  AppColors.info,
];

// ─────────────────────────────────────────────────────────────────────────────
// School admin: executive reports built from the school's own records.
// ─────────────────────────────────────────────────────────────────────────────

class SchoolExecutiveReports extends StatelessWidget {
  final AdminDashboardData? data;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  const SchoolExecutiveReports({
    super.key,
    required this.data,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final d = data;
    final List<Widget> children;
    if (d == null) {
      children = [
        if (error != null)
          ErrorState(message: error!, onRetry: onRefresh)
        else if (loading)
          const SkeletonCard(lines: 4)
        else
          const EmptyState(
            icon: Icons.insights_rounded,
            title: 'No reports yet',
            message: 'Reports appear once your school has teachers, students or classes.',
          ),
      ];
    } else {
      children = _schoolSections(d);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.adminAccent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: AppSpace.pageScroll,
        children: children,
      ),
    );
  }

  List<Widget> _schoolSections(AdminDashboardData d) {
    final teachers = d.teachers;
    final students = d.students;
    final classes = d.classes;

    final enabledTeachers = teachers.where((t) => t.isEnabled).length;
    final enabledStudents = students.where((s) => s.isEnabled).length;
    final unassigned = students.where((s) => (s.studentGroup ?? '').isEmpty).length;
    final totalSeats = classes.fold<int>(0, (sum, c) => sum + (c.groupSize ?? 0));
    final avgSize = classes.isEmpty ? 0.0 : totalSeats / classes.length;

    // Gender split.
    final genderCounts = <String, int>{};
    for (final s in students) {
      final g = (s.gender ?? '').trim();
      final key = g.isEmpty ? 'Not set' : g;
      genderCounts[key] = (genderCounts[key] ?? 0) + 1;
    }
    final genders = genderCounts.entries.toList();
    final genderSlices = [
      for (var i = 0; i < genders.length; i++)
        _Slice(genders[i].key, genders[i].value.toDouble(), _palette[i % _palette.length]),
    ];

    // Largest classes first.
    final sized = [...classes]
      ..sort((a, b) => (b.groupSize ?? 0).compareTo(a.groupSize ?? 0));
    final classBars = [
      for (var i = 0; i < math.min(8, sized.length); i++)
        _Bar(sized[i].name, (sized[i].groupSize ?? 0).toDouble(), _palette[i % _palette.length]),
    ];

    // Class size spread.
    var small = 0, medium = 0, large = 0, xlarge = 0;
    for (final c in classes) {
      final size = c.groupSize ?? 0;
      if (size <= 10) {
        small++;
      } else if (size <= 20) {
        medium++;
      } else if (size <= 30) {
        large++;
      } else {
        xlarge++;
      }
    }
    final spread = [
      _Bar('1–10', small.toDouble(), AppColors.tertiary),
      _Bar('11–20', medium.toDouble(), AppColors.primary),
      _Bar('21–30', large.toDouble(), AppColors.warning),
      _Bar('31+', xlarge.toDouble(), AppColors.danger),
    ];

    // Students by program.
    final programCounts = <String, int>{};
    for (final s in students) {
      final key = (s.programName ?? s.program ?? '').trim();
      final name = key.isEmpty ? 'Unassigned' : key;
      programCounts[name] = (programCounts[name] ?? 0) + 1;
    }
    final programs = programCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final programBars = [
      for (var i = 0; i < math.min(6, programs.length); i++)
        _Bar(programs[i].key, programs[i].value.toDouble(), _palette[i % _palette.length]),
    ];

    final insights = <_Insight>[
      if (sized.isNotEmpty)
        _Insight(
          'Largest class is ${sized.first.name} with ${sized.first.groupSize ?? 0} students.',
          AppColors.tertiary,
        ),
      if (sized.isNotEmpty && sized.last.name != sized.first.name)
        _Insight(
          'Smallest class is ${sized.last.name} with ${sized.last.groupSize ?? 0} students.',
          AppColors.primary,
        ),
      if (unassigned > 0)
        _Insight(
          '$unassigned student${unassigned == 1 ? '' : 's'} not in a class yet.',
          AppColors.warning,
        ),
      if (teachers.length - enabledTeachers > 0)
        _Insight(
          '${teachers.length - enabledTeachers} teacher account${teachers.length - enabledTeachers == 1 ? '' : 's'} disabled.',
          AppColors.danger,
        ),
      if (students.isEmpty && teachers.isEmpty && classes.isEmpty)
        const _Insight(
          'No records yet. Add teachers, classes and students to see reports.',
          AppColors.inkFaint,
        ),
    ];

    return [
      Row(
        children: [
          Expanded(
            child: StatTile(
              label: 'Teachers',
              value: '${teachers.length}',
              icon: Icons.badge_outlined,
              accent: AppColors.adminAccent,
              delta: '$enabledTeachers active',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              label: 'Students',
              value: '${students.length}',
              icon: Icons.school_outlined,
              accent: AppColors.primary,
              delta: '$enabledStudents active',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: StatTile(
              label: 'Classes',
              value: '${classes.length}',
              icon: Icons.class_outlined,
              accent: AppColors.tertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              label: 'Avg class size',
              value: _fmt(avgSize),
              icon: Icons.groups_2_outlined,
              accent: AppColors.warning,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpace.lg),
      _Panel(
        title: 'Students by gender',
        subtitle: '${students.length} students on the roster',
        icon: Icons.pie_chart_rounded,
        child: students.isEmpty
            ? const _NoData()
            : _Donut(
                slices: genderSlices,
                center: '${students.length}',
                centerLabel: 'students',
              ),
      ),
      const SizedBox(height: AppSpace.md),
      _Panel(
        title: 'Biggest classes',
        subtitle: 'Students enrolled per class',
        icon: Icons.bar_chart_rounded,
        child: classBars.isEmpty ? const _NoData() : _HBars(bars: classBars),
      ),
      const SizedBox(height: AppSpace.md),
      _Panel(
        title: 'Class size spread',
        subtitle: 'How many classes fall in each size band',
        icon: Icons.stacked_bar_chart_rounded,
        child: classes.isEmpty ? const _NoData() : _Columns(bars: spread),
      ),
      const SizedBox(height: AppSpace.md),
      _Panel(
        title: 'Students by program',
        subtitle: 'Where the student body is enrolled',
        icon: Icons.menu_book_rounded,
        child: programBars.isEmpty ? const _NoData() : _HBars(bars: programBars),
      ),
      const SizedBox(height: AppSpace.md),
      _Panel(
        title: 'Setup health',
        subtitle: 'How complete your school records are',
        icon: Icons.fact_check_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Check(
              label: 'Teacher accounts active',
              done: enabledTeachers,
              total: teachers.length,
              color: AppColors.adminAccent,
            ),
            _Check(
              label: 'Student accounts active',
              done: enabledStudents,
              total: students.length,
              color: AppColors.primary,
            ),
            _Check(
              label: 'Students placed in a class',
              done: students.length - unassigned,
              total: students.length,
              color: AppColors.tertiary,
            ),
            _Check(
              label: 'Classes with students',
              done: classes.where((c) => (c.groupSize ?? 0) > 0).length,
              total: classes.length,
              color: AppColors.warning,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpace.md),
      _Panel(
        title: 'Key insights',
        subtitle: 'Generated from your live records',
        icon: Icons.auto_awesome_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: insights.isEmpty
              ? const [_Insight('Everything looks on track.', AppColors.success)]
              : insights,
        ),
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Super admin: network-wide reports across every registered school.
// ─────────────────────────────────────────────────────────────────────────────

class SuperExecutiveReports extends StatelessWidget {
  final List<SuperSchoolModel> schools;

  const SuperExecutiveReports({super.key, required this.schools});

  /// The fields a school record should have. Used for the completeness score.
  static const _fieldLabels = <String>[
    'Admin assigned',
    'Admin password set',
    'Contact email',
    'Contact number',
    'Address',
    'Motto',
    'Logo',
  ];

  static List<bool> _fields(SuperSchoolModel s) => [
        (s.adminEmail ?? '').isNotEmpty,
        s.hasPassword,
        (s.contactEmail ?? '').isNotEmpty,
        (s.contactNumber ?? '').isNotEmpty,
        (s.address ?? '').isNotEmpty,
        (s.motto ?? '').isNotEmpty,
        (s.logoUrl ?? '').isNotEmpty,
      ];

  static double _score(SuperSchoolModel s) {
    final f = _fields(s);
    return f.where((x) => x).length / f.length;
  }

  @override
  Widget build(BuildContext context) {
    final total = schools.length;
    final active = schools.where((s) => s.status.toLowerCase() == 'active').length;
    final withAdmin = schools.where((s) => (s.adminEmail ?? '').isNotEmpty).length;
    final withPassword = schools.where((s) => s.hasPassword).length;
    final avgScore = total == 0
        ? 0.0
        : schools.map(_score).reduce((a, b) => a + b) / total;

    // Status split.
    final statusCounts = <String, int>{};
    for (final s in schools) {
      final key = s.status.trim().isEmpty ? 'Unknown' : s.status.trim();
      statusCounts[key] = (statusCounts[key] ?? 0) + 1;
    }
    final statuses = statusCounts.entries.toList();
    final statusSlices = [
      for (var i = 0; i < statuses.length; i++)
        _Slice(
          statuses[i].key,
          statuses[i].value.toDouble(),
          statuses[i].key.toLowerCase() == 'active'
              ? AppColors.success
              : _palette[i % _palette.length],
        ),
    ];

    // Setup checklist across all schools.
    final checklist = <_Check>[
      for (var i = 0; i < _fieldLabels.length; i++)
        _Check(
          label: _fieldLabels[i],
          done: schools.where((s) => _fields(s)[i]).length,
          total: total,
          color: AppColors.superAccent,
        ),
    ];

    // Most complete schools first.
    final ranked = [...schools]..sort((a, b) => _score(b).compareTo(_score(a)));
    final rankBars = [
      for (var i = 0; i < math.min(8, ranked.length); i++)
        _Bar(
          ranked[i].schoolName,
          _score(ranked[i]) * 100,
          _palette[i % _palette.length],
        ),
    ];

    final withoutAdmin = total - withAdmin;
    final withoutPassword = total - withPassword;
    final inactive = total - active;

    final insights = <_Insight>[
      if (withoutAdmin > 0)
        _Insight(
          '$withoutAdmin school${withoutAdmin == 1 ? '' : 's'} without an admin account.',
          AppColors.danger,
        ),
      if (withoutPassword > 0 && withAdmin > 0)
        _Insight(
          '$withoutPassword school${withoutPassword == 1 ? '' : 's'} without a set admin password.',
          AppColors.warning,
        ),
      if (inactive > 0)
        _Insight(
          '$inactive school${inactive == 1 ? '' : 's'} not currently active.',
          AppColors.warning,
        ),
      if (ranked.isNotEmpty && ranked.last.schoolName != ranked.first.schoolName)
        _Insight(
          '${ranked.last.schoolName} has the least complete setup (${(_score(ranked.last) * 100).round()}%).',
          AppColors.primary,
        ),
      if (total == 0)
        const _Insight(
          'No schools registered yet. Register one to start reporting.',
          AppColors.inkFaint,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Schools',
                value: '$total',
                icon: Icons.apartment_rounded,
                accent: AppColors.superAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Active',
                value: '$active',
                icon: Icons.check_circle_outline_rounded,
                accent: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'With admin',
                value: '$withAdmin',
                icon: Icons.verified_user_outlined,
                accent: AppColors.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Setup score',
                value: '${(avgScore * 100).round()}%',
                icon: Icons.speed_rounded,
                accent: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        _Panel(
          title: 'School status',
          subtitle: '$total registered across the network',
          icon: Icons.pie_chart_rounded,
          accent: AppColors.superAccent,
          child: total == 0
              ? const _NoData()
              : _Donut(
                  slices: statusSlices,
                  center: '$total',
                  centerLabel: 'schools',
                ),
        ),
        const SizedBox(height: AppSpace.md),
        _Panel(
          title: 'Setup checklist',
          subtitle: 'Share of schools with each record filled in',
          icon: Icons.fact_check_outlined,
          accent: AppColors.superAccent,
          child: total == 0
              ? const _NoData()
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: checklist),
        ),
        const SizedBox(height: AppSpace.md),
        _Panel(
          title: 'Most complete schools',
          subtitle: 'Setup score per school',
          icon: Icons.bar_chart_rounded,
          accent: AppColors.superAccent,
          child: rankBars.isEmpty ? const _NoData() : _HBars(bars: rankBars, unit: '%'),
        ),
        const SizedBox(height: AppSpace.md),
        _Panel(
          title: 'Key insights',
          subtitle: 'Generated from the school registry',
          icon: Icons.auto_awesome_rounded,
          accent: AppColors.superAccent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: insights.isEmpty
                ? const [_Insight('Every school is fully set up.', AppColors.success)]
                : insights,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared chart pieces
// ─────────────────────────────────────────────────────────────────────────────

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class _Slice {
  final String label;
  final double value;
  final Color color;
  const _Slice(this.label, this.value, this.color);
}

class _Bar {
  final String label;
  final double value;
  final Color color;
  const _Bar(this.label, this.value, this.color);
}

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final Color accent;

  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.accent = AppColors.adminAccent,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: AppRadius.brMd,
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.cardTitle),
                    if (subtitle != null)
                      Text(subtitle!, style: AppText.caption.copyWith(fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          child,
        ],
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'No data to chart yet.',
        style: AppText.caption.copyWith(fontSize: 12.5),
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  final List<_Slice> slices;
  final String center;
  final String centerLabel;

  const _Donut({
    required this.slices,
    required this.center,
    required this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, x) => s + x.value);
    return Row(
      children: [
        SizedBox(
          width: 128,
          height: 128,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: AppMotion.slow,
            curve: AppMotion.emphasized,
            builder: (_, t, __) => CustomPaint(
              painter: _DonutPainter(slices: slices, progress: t),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(center, style: AppText.metric.copyWith(fontSize: 20)),
                    Text(centerLabel, style: AppText.caption.copyWith(fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.label,
                          style: AppText.body.copyWith(fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        total == 0 ? '0%' : '${(s.value / total * 100).round()}%',
                        style: AppText.cardTitle.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
  final double progress;

  const _DonutPainter({required this.slices, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = AppColors.surfaceContainerHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final total = slices.fold<double>(0, (s, x) => s + x.value);
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * math.pi * 2 * progress;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, math.max(0, sweep - 0.06), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.slices != slices;
}

class _HBars extends StatelessWidget {
  final List<_Bar> bars;
  final String unit;

  const _HBars({required this.bars, this.unit = ''});

  @override
  Widget build(BuildContext context) {
    final max = bars.fold<double>(0, (m, b) => math.max(m, b.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in bars)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.label,
                        style: AppText.body.copyWith(
                          fontSize: 12.5,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${_fmt(b.value)}$unit',
                      style: AppText.cardTitle.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                _Track(
                  fraction: max == 0 ? 0 : b.value / max,
                  color: b.color,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Track extends StatelessWidget {
  final double fraction;
  final Color color;

  const _Track({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    final target = fraction.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: AppRadius.brPill,
      child: Stack(
        children: [
          Container(height: 9, color: AppColors.surfaceContainerHigh),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: target),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                height: 9,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, Color.lerp(color, Colors.white, 0.25)!],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Columns extends StatelessWidget {
  final List<_Bar> bars;
  final double height;

  const _Columns({required this.bars}) : height = 160;

  @override
  Widget build(BuildContext context) {
    final max = bars.fold<double>(0, (m, b) => math.max(m, b.value));
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(_fmt(b.value), style: AppText.cardTitle.copyWith(fontSize: 12)),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: max == 0 ? 0.0 : b.value / max,
                      ),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Container(
                        height: math.max(4, v * (height - 58)),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [b.color, b.color.withValues(alpha: 0.55)],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b.label,
                      style: AppText.caption.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final String label;
  final int done;
  final int total;
  final Color color;

  const _Check({
    required this.label,
    required this.done,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total * 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.body.copyWith(fontSize: 12.5, color: AppColors.ink),
                ),
              ),
              Text(
                total == 0 ? '—' : '$done of $total · ${pct.round()}%',
                style: AppText.caption.copyWith(fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GradientBar(
            percent: pct,
            height: 8,
            gradient: LinearGradient(
              colors: [color, Color.lerp(color, Colors.white, 0.25)!],
            ),
          ),
        ],
      ),
    );
  }
}

class _Insight extends StatelessWidget {
  final String text;
  final Color color;

  const _Insight(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DoodleIcon(
              kind: DoodleKind.star,
              color: color,
              size: 18,
              filled: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppText.body.copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
