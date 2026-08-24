import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../theme/colors.dart';
import '../state/auth_provider.dart';
import '../state/school_provider.dart';
import '../models/user_model.dart';
import 'teacher/teacher_manage_students_screen.dart';
import 'teacher/teacher_manage_classes_screen.dart';

class StudentProfile extends ConsumerWidget {
  const StudentProfile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final schoolState = ref.watch(schoolProvider);
    final school = schoolState.profile;
    if (school == null && !schoolState.isLoading) {
      Future.microtask(() => ref.read(schoolProvider.notifier).load());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      user != null && user.fullName.isNotEmpty ? user.fullName[0] : 'S',
                      style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.fullName ?? 'Student Name',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? 'student@school.com',
              style: const TextStyle(color: AppColors.outline),
            ),
            const SizedBox(height: 32),
            _buildProfileSection(
              context,
              title: 'Account Information',
              children: [
                _buildListTile(
                  context,
                  Icons.school_outlined,
                  'School',
                  school?.schoolName ?? user?.schoolName ?? '—',
                ),
                _buildListTile(context, Icons.badge_outlined, 'Role', _roleLabel(user?.role)),
              ],
            ),
            const SizedBox(height: 24),
            _buildProfileSection(
              context,
              title: 'School Information',
              children: [
                if (school != null) ...[
                  if (school.logoUrlFor(ApiConfig.activeBaseUrl) != null)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          school.logoUrlFor(ApiConfig.activeBaseUrl)!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 40,
                            height: 40,
                            color: AppColors.primaryContainer,
                            child: const Icon(Icons.school, color: Colors.white),
                          ),
                        ),
                      ),
                      title: Text(school.schoolName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('School Logo', style: TextStyle(fontSize: 12)),
                    ),
                  if (school.contactEmail != null && school.contactEmail!.isNotEmpty)
                    _buildListTile(context, Icons.email_outlined, 'Contact Email', school.contactEmail!),
                  if (school.contactNumber != null && school.contactNumber!.isNotEmpty)
                    _buildListTile(context, Icons.phone_outlined, 'Phone Number', school.contactNumber!),
                  if (school.address != null && school.address!.isNotEmpty)
                    _buildListTile(context, Icons.location_on_outlined, 'Address', school.address!),
                  if (school.website != null && school.website!.isNotEmpty)
                    _buildListTile(context, Icons.language_outlined, 'Website', school.website!),
                ] else if (schoolState.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('School info unavailable.')),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProfileSection(
              context,
              title: 'Settings',
              children: [
                if (user?.role == UserRole.instructor) ...[
                  _buildActionTile(context, Icons.people_outline, 'Edit Students', () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TeacherManageStudentsScreen()),
                    );
                  }),
                  _buildActionTile(context, Icons.class_outlined, 'Edit Classes & Subjects', () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TeacherManageClassesScreen()),
                    );
                  }),
                ],
                _buildActionTile(context, Icons.calendar_month_outlined, 'My Timetable', () {
                  Navigator.pushNamed(context, '/MyTimetable');
                }),
                _buildActionTile(context, Icons.lock_outline, 'Change Password', () {
                  Navigator.pushNamed(context, '/ChangePasswordModal');
                }),
                _buildActionTile(context, Icons.notifications_outlined, 'Notifications', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new notifications. You are all caught up!')),
                  );
                }),
                _buildActionTile(context, Icons.help_outline, 'Help & Support', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reach out to your school admin for assistance.')),
                  );
                }),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                  '/LoginScreen',
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorContainer,
                foregroundColor: AppColors.onErrorContainer,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  String _roleLabel(UserRole? role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.instructor:
        return 'Teacher';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.schoolAdmin:
        return 'School Admin';
      case UserRole.student:
      case null:
        return 'Student';
    }
  }

  Widget _buildProfileSection(BuildContext context, {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.outline,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairlineBorder),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, color: AppColors.outline)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.onSurface),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
    );
  }
}
