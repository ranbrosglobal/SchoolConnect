import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/auth_provider.dart';
import '../../state/teacher_provider.dart';
import '../auth/login_screen.dart';
import 'teacher_settings_screen.dart';

class TeacherProfileTab extends ConsumerStatefulWidget {
  const TeacherProfileTab({super.key});

  @override
  ConsumerState<TeacherProfileTab> createState() => _TeacherProfileTabState();
}

class _TeacherProfileTabState extends ConsumerState<TeacherProfileTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherProvider.notifier).loadTeacherProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final teacherState = ref.watch(teacherProvider);
    final profile = teacherState.teacherProfile;

    final displayName = profile?.name ?? user?.fullName ?? 'Mr. Arjun Sharma';
    final displayEmail = profile?.email ?? user?.email ?? 'arjun.sharma@school.com';
    final displaySchool = profile?.schoolName ?? user?.schoolName ?? 'Springfield Elementary';
    final displayDept = profile?.department ?? 'Mathematics';
    final displayAddress = profile?.address ?? '';
    final displaySchoolNumber = profile?.schoolNumber ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF1E3A8A)),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildProfileHeader(context, displayName, displayEmail, displayDept),
            if (displaySchool.isNotEmpty) _buildInfoRow(Icons.school_outlined, 'School', displaySchool),
            if (displaySchoolNumber.isNotEmpty) _buildInfoRow(Icons.numbers, 'School Number', displaySchoolNumber),
            if (displayAddress.isNotEmpty) _buildInfoRow(Icons.location_on_outlined, 'Address', displayAddress),
            const SizedBox(height: 32),
            _buildMenuItems(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, String name, String email, String department) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blue.shade50,
            backgroundImage: const AssetImage('assets/images/teacher_avatar.png'),
            onBackgroundImageError: (_, __) {},
            child: const Icon(Icons.person, size: 40, color: Colors.grey),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$department Teacher',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _openSettings(context),
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, size: 20, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TeacherSettingsScreen()),
    );
  }

  Widget _buildMenuItems(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildMenuItem(
          icon: Icons.person_outline,
          title: 'Personal Information',
        ),
        _buildMenuItem(
          icon: Icons.book_outlined,
          title: 'Subjects',
          subtitle: 'Mathematics',
        ),
        _buildMenuItem(
          icon: Icons.class_outlined,
          title: 'Classes',
          subtitle: '4 Classes',
        ),
        const Divider(height: 32, thickness: 1, indent: 24, endIndent: 24),
        _buildMenuItem(
          icon: Icons.notifications_none,
          title: 'Notification Settings',
        ),
        _buildMenuItem(
          icon: Icons.lock_outline,
          title: 'Privacy & Security',
        ),
        _buildMenuItem(
          icon: Icons.help_outline,
          title: 'Help & Support',
        ),
        const Divider(height: 32, thickness: 1, indent: 24, endIndent: 24),
        _buildMenuItem(
          icon: Icons.logout,
          title: 'Logout',
          isDestructive: true,
          onTap: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final color = isDestructive ? Colors.red : const Color(0xFF1E3A8A);
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: isDestructive ? Colors.red : Colors.grey.shade700, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            )
          : null,
      trailing: isDestructive
          ? null
          : Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: onTap ?? () {},
    );
  }
}
