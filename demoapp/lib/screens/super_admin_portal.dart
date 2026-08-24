import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../state/auth_provider.dart';
import '../models/super_school_model.dart';

/// Super Admin portal — runs against the dedicated super-admin site (its own
/// database). Lets the super admin register schools (each school lives on its
/// own Frappe site/database), manage each school's admin account, and reset
/// admin passwords. Changes apply on the school's own site immediately.
class SuperAdminPortal extends ConsumerStatefulWidget {
  const SuperAdminPortal({super.key});

  @override
  ConsumerState<SuperAdminPortal> createState() => _SuperAdminPortalState();
}

class _SuperAdminPortalState extends ConsumerState<SuperAdminPortal> {
  bool _loading = true;
  String? _error;
  List<SuperSchoolModel> _schools = [];

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
      final schools = await ref.read(demoApiServiceProvider).getSuperSchools();
      if (!mounted) return;
      setState(() {
        _schools = schools;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : Colors.green,
      ),
    );
  }

  Future<void> _addSchool() async {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final siteCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '8000');
    final mottoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final adminNameCtrl = TextEditingController();
    final adminEmailCtrl = TextEditingController();
    final adminPassCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => _schoolForm(
        sheetCtx,
        title: 'Register New School',
        subtitle: 'Each school gets its own database. The admin account is '
            'created on the school\u2019s site with these credentials.',
        fields: [
          _field(nameCtrl, 'School Name', Icons.school_outlined, required: true),
          _field(siteCtrl, 'Site (e.g. myschool.localhost)', Icons.dns_outlined, required: true),
          _field(portCtrl, 'Port (dev: 8000/8001/…)', Icons.router_outlined, keyboardType: TextInputType.number),
          _field(mottoCtrl, 'Motto / Tagline', Icons.flag_outlined),
          _field(emailCtrl, 'Contact Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
          _field(phoneCtrl, 'Contact Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
          _field(addressCtrl, 'Address', Icons.location_on_outlined),
          const Divider(height: 24),
          _field(adminNameCtrl, 'School Admin Name', Icons.person_outline),
          _field(adminEmailCtrl, 'School Admin Email', Icons.alternate_email, keyboardType: TextInputType.emailAddress),
          _field(adminPassCtrl, 'Admin Password', Icons.lock_outline, obscure: true),
        ],
        submitLabel: 'Register School',
        onSubmit: () async {
          try {
            final port = int.tryParse(portCtrl.text.trim()) ?? 8000;
            await ref.read(demoApiServiceProvider).createSuperSchool(
              schoolName: nameCtrl.text.trim(),
              site: siteCtrl.text.trim(),
              port: port,
              motto: mottoCtrl.text.trim().isEmpty ? null : mottoCtrl.text.trim(),
              contactEmail: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
              contactNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
              address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
              adminName: adminNameCtrl.text.trim().isEmpty ? null : adminNameCtrl.text.trim(),
              adminEmail: adminEmailCtrl.text.trim().isEmpty ? null : adminEmailCtrl.text.trim(),
              adminPassword: adminPassCtrl.text.isEmpty ? null : adminPassCtrl.text,
            );
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            await _load();
            messenger.showSnackBar(
              const SnackBar(
                content: Text('School registered — admin account provisioned ✓'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
          }
        },
      ),
    );
  }

  Future<void> _editSchool(SuperSchoolModel school) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController(text: school.schoolName);
    final siteCtrl = TextEditingController(text: school.site);
    final portCtrl = TextEditingController(text: '${school.port}');
    final mottoCtrl = TextEditingController(text: school.motto ?? '');
    final emailCtrl = TextEditingController(text: school.contactEmail ?? '');
    final phoneCtrl = TextEditingController(text: school.contactNumber ?? '');
    final addressCtrl = TextEditingController(text: school.address ?? '');
    final adminNameCtrl = TextEditingController(text: school.adminName ?? '');
    final adminEmailCtrl = TextEditingController(text: school.adminEmail ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => _schoolForm(
        sheetCtx,
        title: 'Edit School',
        subtitle: school.site,
        fields: [
          _field(nameCtrl, 'School Name', Icons.school_outlined, required: true),
          _field(siteCtrl, 'Site', Icons.dns_outlined, required: true),
          _field(portCtrl, 'Port', Icons.router_outlined, keyboardType: TextInputType.number),
          _field(mottoCtrl, 'Motto', Icons.flag_outlined),
          _field(emailCtrl, 'Contact Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
          _field(phoneCtrl, 'Contact Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
          _field(addressCtrl, 'Address', Icons.location_on_outlined),
          const Divider(height: 24),
          _field(adminNameCtrl, 'School Admin Name', Icons.person_outline),
          _field(adminEmailCtrl, 'School Admin Email', Icons.alternate_email, keyboardType: TextInputType.emailAddress),
        ],
        submitLabel: 'Save Changes',
        onSubmit: () async {
          try {
            await ref.read(demoApiServiceProvider).updateSuperSchool(
              name: school.name,
              schoolName: nameCtrl.text.trim(),
              site: siteCtrl.text.trim(),
              port: int.tryParse(portCtrl.text.trim()) ?? school.port,
              motto: mottoCtrl.text.trim().isEmpty ? null : mottoCtrl.text.trim(),
              contactEmail: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
              contactNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
              address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
              adminName: adminNameCtrl.text.trim().isEmpty ? null : adminNameCtrl.text.trim(),
              adminEmail: adminEmailCtrl.text.trim().isEmpty ? null : adminEmailCtrl.text.trim(),
            );
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            await _load();
            messenger.showSnackBar(const SnackBar(content: Text('School updated ✓'), backgroundColor: Colors.green));
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
          }
        },
      ),
    );
  }

  Future<void> _resetAdminPassword(SuperSchoolModel school) async {
    final messenger = ScaffoldMessenger.of(context);
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Reset Admin Password — ${school.schoolName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              school.adminEmail != null
                  ? 'New password for ${school.adminEmail}'
                  : 'No admin email set on this school yet.',
              style: const TextStyle(fontSize: 13, color: AppColors.outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_reset, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (passCtrl.text.length < 6) {
                messenger.showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters.')));
                return;
              }
              if (passCtrl.text != confirmCtrl.text) {
                messenger.showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
                return;
              }
              try {
                await ref.read(demoApiServiceProvider).resetSuperAdminPassword(
                      name: school.name,
                      newPassword: passCtrl.text,
                    );
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                await _load();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Admin password reset on the school site ✓'), backgroundColor: Colors.green),
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSchool(SuperSchoolModel school) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove school?'),
        content: Text(
          'Unregister ${school.schoolName} (${school.site})? The school\u2019s own '
          'site and database are NOT touched — only the registry entry is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(demoApiServiceProvider).deleteSuperSchool(school.name);
      await _load();
      _snack('School removed from registry.');
    } catch (e) {
      _snack('Failed: $e', error: true);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
      ),
    );
  }

  Widget _schoolForm(
    BuildContext sheetCtx, {
    required String title,
    required String subtitle,
    required List<Widget> fields,
    required String submitLabel,
    required Future<void> Function() onSubmit,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.outline)),
            const SizedBox(height: 16),
            ...fields,
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => onSubmit(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.save_outlined),
              label: Text(submitLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Super Admin Portal', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/LoginScreen',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        const Text('Could not load the school registry.',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('$_error',
                            style: const TextStyle(fontSize: 12, color: AppColors.outline),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.hairlineBorder),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.admin_panel_settings, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${_schools.length} school(s) registered',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const Text(
                                      'Each school runs on its own database.',
                                      style: TextStyle(fontSize: 12, color: AppColors.outline),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _addSchool,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        icon: const Icon(Icons.add_business_outlined),
                        label: const Text('Register New School'),
                      ),
                      const SizedBox(height: 16),
                      if (_schools.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text('No schools registered yet.',
                                style: TextStyle(color: AppColors.outline)),
                          ),
                        ),
                      for (final school in _schools) _schoolCard(school),
                    ],
                  ),
                ),
    );
  }

  Widget _schoolCard(SuperSchoolModel school) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.hairlineBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(school.schoolName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        '${school.site} · port ${school.port}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.outline),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: school.status == 'Active'
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    school.status,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: school.status == 'Active' ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (school.adminEmail != null || school.motto != null || school.contactEmail != null) ...[
              _chipRow(Icons.person_outline,
                  school.adminName != null ? '${school.adminName} <${school.adminEmail}>' : (school.adminEmail ?? '')),
              if (school.motto != null && school.motto!.isNotEmpty)
                _chipRow(Icons.flag_outlined, school.motto!),
              if (school.contactEmail != null && school.contactEmail!.isNotEmpty)
                _chipRow(Icons.email_outlined, school.contactEmail!),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _editSchool(school),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _resetAdminPassword(school),
                  icon: const Icon(Icons.password_rounded, size: 16),
                  label: const Text('Admin Password'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _deleteSchool(school),
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                  tooltip: 'Remove from registry',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipRow(IconData icon, String? text) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.outline),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
