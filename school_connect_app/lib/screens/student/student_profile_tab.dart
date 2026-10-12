import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../services/assistant/assistant_context.dart';
import '../../state/auth_provider.dart';
import '../../state/school_provider.dart';
import '../../state/student_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';
import '../auth/login_screen.dart';
import 'attendance_detail_screen.dart';
import 'student_grades_screen.dart';

/// Student profile: identity first, live academics second, settings last.
class StudentProfileTab extends ConsumerWidget {
  const StudentProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final student = ref.watch(studentProvider);
    final school = ref.watch(schoolProvider).profile;

    final ctx = AssistantContext(
      userName: user?.fullName ?? 'Student',
      role: UserRole.student,
      schoolName: school?.schoolName ?? user?.schoolName,
      classNames: user?.studentGroups ?? const [],
      attendance: student.attendanceSummary,
      assignments: student.assignments,
      now: DateTime.now(),
    );

    final initials = InitialsAvatar.initialsOf(ctx.userName);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GradientHeader(
              role: AppRoleStyle.student,
              eyebrow: 'Student account',
              title: ctx.userName,
              subtitle: user?.email ?? '',
              leading: InitialsAvatar(
                name: ctx.userName,
                size: 48,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.34),
                    Colors.white.withValues(alpha: 0.16),
                  ],
                ),
              ),
              actions: [
                HeaderIconButton(
                  icon: Icons.verified_user_outlined,
                  tooltip: 'Account',
                  onTap: () => _showAccountSheet(context, ref, user, initials),
                ),
              ],
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (ctx.classNames.isNotEmpty)
                    for (final c in ctx.classNames.take(3))
                      StatusPill(
                        label: c,
                        tone: PillTone.inverse,
                        icon: Icons.groups_rounded,
                        accentOverride: Colors.white,
                      ),
                  StatusPill(
                    label: school?.schoolName ?? 'School',
                    tone: PillTone.inverse,
                    icon: Icons.school_rounded,
                    accentOverride: Colors.white,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _stats(ctx),
                  const SizedBox(height: AppSpace.xl),
                  _group(
                    context,
                    ref,
                    title: 'Academics',
                    tiles: [
                      _Tile(
                        icon: Icons.insights_rounded,
                        color: AppColors.tertiary,
                        title: 'My results',
                        subtitle: ctx.gradedAssignments.isEmpty
                            ? 'No grades yet'
                            : 'Average ${ctx.averageGrade.toStringAsFixed(1)} across '
                                '${ctx.gradedAssignments.length} graded',
                        onTap: () => _push(context, const StudentGradesScreen()),
                      ),
                      _Tile(
                        icon: Icons.event_available_rounded,
                        color: AppColors.success,
                        title: 'Attendance history',
                        subtitle:
                            '${ctx.overallAttendance.toStringAsFixed(0)}% overall · '
                            '${ctx.attendanceCounts.present} present',
                        onTap: () => _push(context, const AttendanceDetailScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  _group(
                    context,
                    ref,
                    title: 'Account',
                    tiles: [
                      _Tile(
                        icon: Icons.person_outline_rounded,
                        color: AppColors.studentAccent,
                        title: 'Personal information',
                        subtitle: user?.email ?? '—',
                        onTap: () => _showAccountSheet(context, ref, user, initials),
                      ),
                      _Tile(
                        icon: Icons.lock_outline_rounded,
                        color: AppColors.secondary,
                        title: 'Change password',
                        subtitle: 'Keep your account secure',
                        onTap: () => Navigator.pushNamed(context, '/ChangePasswordModal'),
                      ),
                      _Tile(
                        icon: Icons.notifications_none_rounded,
                        color: AppColors.warning,
                        title: 'Notifications',
                        subtitle: 'Deadline and attendance alerts',
                        onTap: () => _toast(context, 'Notification settings are coming soon'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  _group(
                    context,
                    ref,
                    title: 'Support',
                    tiles: [
                      _Tile(
                        icon: Icons.help_outline_rounded,
                        color: AppColors.info,
                        title: 'Help & support',
                        subtitle: 'How to use School Connect',
                        onTap: () => _showHelpSheet(context),
                      ),
                      _Tile(
                        icon: Icons.info_outline_rounded,
                        color: AppColors.inkSoft,
                        title: 'About School Connect',
                        subtitle: 'Version 1.0.0',
                        onTap: () => _showAboutSheet(context, school?.schoolName),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  _logoutButton(context, ref),
                  const SizedBox(height: AppSpace.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stats ───────────────────────────────────────────────────────────────

  Widget _stats(AssistantContext ctx) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Attendance',
                value: ctx.overallAttendance.toStringAsFixed(0),
                icon: Icons.event_available_rounded,
                accent: ctx.overallAttendance >= 75
                    ? AppColors.success
                    : AppColors.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Average grade',
                value: ctx.gradedAssignments.isEmpty
                    ? '—'
                    : ctx.averageGrade.toStringAsFixed(1),
                icon: Icons.insights_rounded,
                accent: AppColors.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Submitted',
                value: '${ctx.gradedAssignments.length + ctx.awaitingGrade.length}',
                icon: Icons.task_alt_rounded,
                accent: AppColors.studentAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Outstanding',
                value: '${ctx.todoAssignments.length + ctx.overdueAssignments.length}',
                icon: Icons.pending_actions_rounded,
                accent: ctx.todoAssignments.isEmpty && ctx.overdueAssignments.isEmpty
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Menu ────────────────────────────────────────────────────────────────

  Widget _group(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<_Tile> tiles,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: AppSpace.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            children: [
              for (int i = 0; i < tiles.length; i++)
                _tileRow(tiles[i], isLast: i == tiles.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tileRow(_Tile t, {required bool isLast}) {
    return Pressable(
      onTap: t.onTap,
      borderRadius: AppRadius.brSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.hairlineBorder)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: t.color.withValues(alpha: 0.12),
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(t.icon, size: 18, color: t.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: AppText.cardTitle.copyWith(fontSize: 14)),
                  if (t.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      t.subtitle!,
                      style: AppText.caption.copyWith(fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton(BuildContext context, WidgetRef ref) {
    return Pressable(
      onTap: () => _confirmLogout(context, ref),
      borderRadius: AppRadius.brMd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: AppRadius.brMd,
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.24)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, size: 18, color: AppColors.dangerDark),
            const SizedBox(width: 8),
            Text(
              'Log out',
              style: AppText.cardTitle.copyWith(
                color: AppColors.dangerDark,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to see your classes and assignments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ─── Sheets ──────────────────────────────────────────────────────────────

  void _showAccountSheet(
    BuildContext context,
    WidgetRef ref,
    UserModel? user,
    String initials,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Personal information'),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                InitialsAvatar(name: user?.fullName ?? 'Student', size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? '—', style: AppText.title.copyWith(fontSize: 18)),
                      const SizedBox(height: 3),
                      Text(user?.email ?? '—', style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            _readOnlyField('Student ID', user?.studentId ?? user?.id ?? '—'),
            const SizedBox(height: 10),
            _readOnlyField('Role', 'Student'),
            const SizedBox(height: 10),
            _readOnlyField(
              'Classes',
              (user?.studentGroups ?? const []).join(', ').isEmpty
                  ? 'Not assigned'
                  : user!.studentGroups.join(', '),
            ),
            const SizedBox(height: AppSpace.lg),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/ChangePasswordModal');
              },
              icon: const Icon(Icons.lock_outline_rounded, size: 17),
              label: const Text('Change password'),
            ),
            const SizedBox(height: 8),
            Text(
              'Contact your school office to correct your name, class or roll number.',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    const faqs = [
      ('How is my attendance calculated?', 'Your school marks each class period. The percentage is the share of periods marked present.'),
      ('Can I submit an assignment late?', 'You can upload after the deadline, but it is flagged as late for your teacher.'),
      ('Where do my grades come from?', 'Teachers grade your submitted work; results appear in My results as soon as they are saved.'),
      ('Who do I contact for a problem?', 'Your class teacher first, then the school office.'),
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Help & support'),
            const SizedBox(height: AppSpace.md),
            for (final f in faqs) ...[
              Text(f.$1, style: AppText.cardTitle.copyWith(fontSize: 13.5)),
              const SizedBox(height: 3),
              Text(f.$2, style: AppText.body.copyWith(fontSize: 12.5)),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  void _showAboutSheet(BuildContext context, String? schoolName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'About School Connect'),
            const SizedBox(height: AppSpace.md),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: AppGradients.brand,
                      borderRadius: AppRadius.brLg,
                      boxShadow: AppShadows.glow(AppColors.primary, strength: 0.32),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text('School Connect', style: AppText.title.copyWith(fontSize: 18)),
                  const SizedBox(height: 3),
                  Text(
                    schoolName == null ? 'Version 1.0.0' : '$schoolName · v1.0.0',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              'Attendance, assignments, results and timetable in one place — with an '
              'AI study assistant that reads your real school data.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.hairlineBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.eyebrow.copyWith(fontSize: 9.5)),
          const SizedBox(height: 3),
          Text(value, style: AppText.cardTitle.copyWith(fontSize: 13.5)),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _Tile {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}
