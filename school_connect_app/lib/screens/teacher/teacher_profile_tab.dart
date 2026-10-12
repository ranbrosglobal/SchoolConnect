import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../services/assistant/assistant_context.dart';
import '../../state/auth_provider.dart';
import '../../state/school_provider.dart';
import '../../state/teacher_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/info_sheets.dart';
import '../../widgets/kit/kit.dart';
import '../auth/login_screen.dart';
import 'teacher_settings_screen.dart';

/// Teacher profile: identity, teaching workload, then settings.
class TeacherProfileTab extends ConsumerWidget {
  const TeacherProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final teacher = ref.watch(teacherProvider);
    final school = ref.watch(schoolProvider).profile;

    final ctx = AssistantContext(
      userName: user?.fullName ?? 'Teacher',
      role: user?.role ?? UserRole.instructor,
      schoolName: school?.schoolName ?? user?.schoolName,
      classNames: teacher.classes
          .map((c) => c.studentGroupName ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList(),
      assignments: teacher.assignments,
      classes: teacher.classes,
      now: DateTime.now(),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GradientHeader(
              role: AppRoleStyle.teacher,
              eyebrow: 'Staff account',
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
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  onTap: () => _push(context, const TeacherSettingsScreen()),
                ),
              ],
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(
                    label: '${ctx.classes.length} classes',
                    tone: PillTone.inverse,
                    icon: Icons.groups_2_rounded,
                    accentOverride: Colors.white,
                  ),
                  if (ctx.totalStudentsTaught > 0)
                    StatusPill(
                      label: '${ctx.totalStudentsTaught} students',
                      tone: PillTone.inverse,
                      icon: Icons.people_alt_rounded,
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
                    title: 'Teaching',
                    tiles: [
                      _Tile(
                        icon: Icons.fact_check_outlined,
                        color: AppColors.warning,
                        title: 'Grading workload',
                        subtitle: ctx.assignmentsNeedingGrades.isEmpty
                            ? 'Everything is graded'
                            : '${ctx.assignmentsNeedingGrades.length} assignment(s) awaiting grades',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showWorkloadSheet(context, ctx);
                        },
                      ),
                      _Tile(
                        icon: Icons.assignment_outlined,
                        color: AppColors.teacherAccent,
                        title: 'My assignments',
                        subtitle: '${ctx.assignments.length} set in total',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showWorkloadSheet(context, ctx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  _group(
                    title: 'Account',
                    tiles: [
                      _Tile(
                        icon: Icons.lock_outline_rounded,
                        color: AppColors.secondary,
                        title: 'Change password',
                        subtitle: 'Keep your account secure',
                        onTap: () => Navigator.pushNamed(context, '/ChangePasswordModal'),
                      ),
                      _Tile(
                        icon: Icons.notifications_none_rounded,
                        color: AppColors.info,
                        title: 'Notifications',
                        subtitle: 'Submission and grading alerts',
                        onTap: () => showNotificationsSheet(context),
                      ),
                      _Tile(
                        icon: Icons.settings_outlined,
                        color: AppColors.inkSoft,
                        title: 'Settings',
                        subtitle: 'Account and preferences',
                        onTap: () => _push(context, const TeacherSettingsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  _group(
                    title: 'Support',
                    tiles: [
                      _Tile(
                        icon: Icons.help_outline_rounded,
                        color: AppColors.tertiary,
                        title: 'Help & support',
                        subtitle: 'Guides for marking and grading',
                        onTap: () => showHelpSupportSheet(context),
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

  Widget _stats(AssistantContext ctx) {
    final submitted =
        ctx.assignments.fold<int>(0, (s, a) => s + a.submittedCount);
    final graded = ctx.assignments.fold<int>(0, (s, a) => s + a.gradedCount);
    final rate = submitted == 0 ? 0.0 : graded / submitted * 100;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Classes',
                value: '${ctx.classes.length}',
                icon: Icons.groups_2_outlined,
                accent: AppColors.teacherAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'To grade',
                value: '${ctx.assignmentsNeedingGrades.length}',
                icon: Icons.fact_check_outlined,
                accent: ctx.assignmentsNeedingGrades.isEmpty
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Marking done',
                value: submitted == 0 ? '—' : '${rate.toStringAsFixed(0)}%',
                icon: Icons.done_all_rounded,
                accent: AppColors.adminAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Assignments',
                value: '${ctx.assignments.length}',
                icon: Icons.assignment_outlined,
                accent: AppColors.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _group({required String title, required List<_Tile> tiles}) {
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
        content: const Text('You will need to sign in again to see your classes.'),
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

  void _showWorkloadSheet(BuildContext context, AssistantContext ctx) {
    final backlog = ctx.gradingBacklog.where((r) => r.pending > 0).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Grading workload'),
            const SizedBox(height: AppSpace.md),
            if (backlog.isEmpty)
              const EmptyState(
                icon: Icons.done_all_rounded,
                accent: AppColors.success,
                title: 'Everything is graded',
                message: 'No submissions are waiting on you right now.',
              )
            else
              for (final r in backlog.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.assignment.title,
                              style: AppText.cardTitle.copyWith(fontSize: 13.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r.assignment.studentGroupName ?? 'Class'} · '
                              '${r.assignment.submittedCount}/${r.assignment.totalStudents} submitted',
                              style: AppText.caption.copyWith(fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        label: '${r.pending} to grade',
                        tone: r.pending > 10 ? PillTone.danger : PillTone.warning,
                        dense: true,
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
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
