import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../state/auth_provider.dart';
import '../change_password_modal.dart';
import '../student_timetable.dart';
import '../../widgets/info_sheets.dart';

/// Teacher settings — read-only account controls. Class structure (classes,
/// subjects, timetables) is owned by the school admin, so it is intentionally
/// NOT editable from the teacher app: only viewing, password, notifications
/// and help live here.
class TeacherSettingsScreen extends ConsumerWidget {
  const TeacherSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E3A8A), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _profileCard(context, user?.fullName ?? 'Teacher',
              user?.email ?? '', user?.schoolName),
          const SizedBox(height: 20),
          _sectionLabel('Account'),
          const SizedBox(height: 10),
          _settingsGroup(
            [
              _SettingsTile(
                icon: Icons.calendar_month_outlined,
                color: const Color(0xFF2563EB),
                title: 'My Timetable',
                subtitle: 'Your weekly schedule, uploaded by the school admin',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StudentTimetable()),
                ),
              ),
              _SettingsTile(
                icon: Icons.lock_reset_outlined,
                color: const Color(0xFF7C3AED),
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => Navigator.pushNamed(context, '/ChangePasswordModal'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('General'),
          const SizedBox(height: 10),
          _settingsGroup(
            [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                color: const Color(0xFFEA580C),
                title: 'Notifications',
                subtitle: 'Announcements and updates from your school',
                onTap: () => showNotificationsSheet(context),
              ),
              _SettingsTile(
                icon: Icons.support_agent_outlined,
                color: const Color(0xFF16A34A),
                title: 'Help & Support',
                subtitle: 'FAQs and how to reach your school admin',
                onTap: () => showHelpSupportSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Classes, subjects and timetables are managed by your '
                    'school admin. View them under My Classes and Timetable.',
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xFF1E40AF)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _logoutTile(context, ref),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _profileCard(BuildContext context, String name, String email, String? schoolName) {
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'T',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(email,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5)),
                if (schoolName != null && schoolName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(schoolName,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06);
  }

  Widget _sectionLabel(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Colors.grey.shade500,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _settingsGroup(List<_SettingsTile> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1)
              Divider(height: 1, indent: 62, color: Colors.grey.shade100),
          ],
        ],
      ),
    );
  }

  Widget _logoutTile(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Log out?'),
              content: const Text('You will need to sign in again.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Log out')),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          await ref.read(authProvider.notifier).logout();
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true)
                .pushNamedAndRemoveUntil('/LoginScreen', (route) => false);
          }
        },
        icon: const Icon(Icons.logout, size: 19),
        label: const Text('Log Out',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          side: BorderSide(color: const Color(0xFFDC2626).withValues(alpha: 0.35)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
