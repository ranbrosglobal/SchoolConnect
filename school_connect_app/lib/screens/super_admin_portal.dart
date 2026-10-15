import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/super_school_model.dart';
import '../state/auth_provider.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../widgets/kit/kit.dart';
import 'admin/executive_reports.dart';

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
  final _search = TextEditingController();
  /// Executive reports are the main view; the school list is one tap away.
  bool _showReports = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final schools = await ref.read(sheetsServiceProvider).getSuperSchools();
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

  List<SuperSchoolModel> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _schools;
    return _schools
        .where((s) =>
            s.schoolName.toLowerCase().contains(q) ||
            s.site.toLowerCase().contains(q) ||
            (s.adminEmail ?? '').toLowerCase().contains(q))
        .toList();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? AppColors.danger : AppColors.ink,
        ),
      );
  }

  // ─── Add / edit ───────────────────────────────────────────────────────────

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
      builder: (sheetCtx) => _schoolForm(
        sheetCtx,
        title: 'Register new school',
        subtitle: 'Each school gets its own database. The admin account is '
            'created on that school\u2019s site with these credentials.',
        icon: Icons.add_business_rounded,
        fields: [
          _field(nameCtrl, 'School name', Icons.school_outlined, required: true),
          _field(siteCtrl, 'Site (e.g. myschool.localhost)', Icons.dns_outlined,
              required: true),
          _field(portCtrl, 'Port (dev: 8000/8001/…)', Icons.router_outlined,
              keyboardType: TextInputType.number),
          _field(mottoCtrl, 'Motto / tagline', Icons.flag_outlined),
          _field(emailCtrl, 'Contact email', Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
          _field(phoneCtrl, 'Contact number', Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          _field(addressCtrl, 'Address', Icons.location_on_outlined),
          const _FormDivider(label: 'School admin account'),
          _field(adminNameCtrl, 'Admin name', Icons.person_outline),
          _field(adminEmailCtrl, 'Admin email', Icons.alternate_email,
              keyboardType: TextInputType.emailAddress),
          _field(adminPassCtrl, 'Admin password', Icons.lock_outline, obscure: true),
        ],
        submitLabel: 'Register school',
        onSubmit: () async {
          try {
            final port = int.tryParse(portCtrl.text.trim()) ?? 8000;
            await ref.read(sheetsServiceProvider).createSuperSchool(
                  schoolName: nameCtrl.text.trim(),
                  site: siteCtrl.text.trim(),
                  port: port,
                  motto:
                      mottoCtrl.text.trim().isEmpty ? null : mottoCtrl.text.trim(),
                  contactEmail:
                      emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  contactNumber:
                      phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  address:
                      addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  adminName:
                      adminNameCtrl.text.trim().isEmpty ? null : adminNameCtrl.text.trim(),
                  adminEmail:
                      adminEmailCtrl.text.trim().isEmpty ? null : adminEmailCtrl.text.trim(),
                  adminPassword:
                      adminPassCtrl.text.isEmpty ? null : adminPassCtrl.text,
                );
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            await _load();
            messenger.showSnackBar(
              const SnackBar(
                content: Text('School registered — admin account provisioned ✓'),
              ),
            );
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
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
      builder: (sheetCtx) => _schoolForm(
        sheetCtx,
        title: 'Edit school',
        subtitle: school.site,
        icon: Icons.edit_outlined,
        fields: [
          _field(nameCtrl, 'School name', Icons.school_outlined, required: true),
          _field(siteCtrl, 'Site', Icons.dns_outlined, required: true),
          _field(portCtrl, 'Port', Icons.router_outlined,
              keyboardType: TextInputType.number),
          _field(mottoCtrl, 'Motto', Icons.flag_outlined),
          _field(emailCtrl, 'Contact email', Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
          _field(phoneCtrl, 'Contact number', Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          _field(addressCtrl, 'Address', Icons.location_on_outlined),
          const _FormDivider(label: 'School admin account'),
          _field(adminNameCtrl, 'Admin name', Icons.person_outline),
          _field(adminEmailCtrl, 'Admin email', Icons.alternate_email,
              keyboardType: TextInputType.emailAddress),
        ],
        submitLabel: 'Save changes',
        onSubmit: () async {
          try {
            await ref.read(sheetsServiceProvider).updateSuperSchool(
                  name: school.name,
                  schoolName: nameCtrl.text.trim(),
                  site: siteCtrl.text.trim(),
                  port: int.tryParse(portCtrl.text.trim()) ?? school.port,
                  motto:
                      mottoCtrl.text.trim().isEmpty ? null : mottoCtrl.text.trim(),
                  contactEmail:
                      emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  contactNumber:
                      phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  address:
                      addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                  adminName:
                      adminNameCtrl.text.trim().isEmpty ? null : adminNameCtrl.text.trim(),
                  adminEmail:
                      adminEmailCtrl.text.trim().isEmpty ? null : adminEmailCtrl.text.trim(),
                );
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            await _load();
            messenger.showSnackBar(const SnackBar(content: Text('School updated ✓')));
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
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
        title: Text('Reset admin password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              school.adminEmail != null
                  ? 'New password for ${school.adminEmail} on ${school.site}.'
                  : 'No admin email is set for this school yet.',
              style: AppText.body.copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: AppSpace.md),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                prefixIcon: Icon(Icons.lock_outline, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_reset, size: 18),
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
                messenger.showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters.')),
                );
                return;
              }
              if (passCtrl.text != confirmCtrl.text) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Passwords do not match.')),
                );
                return;
              }
              try {
                await ref.read(sheetsServiceProvider).resetSuperAdminPassword(
                      name: school.name,
                      newPassword: passCtrl.text,
                    );
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                await _load();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Admin password reset on the school site ✓')),
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            },
            child: const Text('Reset password'),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(sheetsServiceProvider).deleteSuperSchool(school.name);
      await _load();
      _snack('School removed from the registry.');
    } catch (e) {
      _snack('Failed: $e', error: true);
    }
  }

  // ─── Form pieces ─────────────────────────────────────────────────────────

  Widget _viewToggle() {
    Widget segment(bool reports, String label, IconData icon) {
      final selected = _showReports == reports;
      return Expanded(
        child: Pressable(
          onTap: () => setState(() => _showReports = reports),
          borderRadius: AppRadius.brPill,
          child: AnimatedContainer(
            duration: AppMotion.base,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.superAccent : Colors.transparent,
              borderRadius: AppRadius.brPill,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16,
                    color: selected ? Colors.white : AppColors.inkSoft),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppText.cardTitle.copyWith(
                    fontSize: 13,
                    color: selected ? Colors.white : AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: AppColors.hairlineBorder),
      ),
      child: Row(
        children: [
          segment(true, 'Reports', Icons.insights_rounded),
          segment(false, 'Schools', Icons.apartment_rounded),
        ],
      ),
    );
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
          prefixIcon: Icon(icon, size: 18),
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
    required IconData icon,
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
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppGradients.superAdmin,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.title.copyWith(fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppText.caption.copyWith(fontSize: 11.5, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            ...fields,
            const SizedBox(height: AppSpace.sm),
            ElevatedButton.icon(
              onPressed: () => onSubmit(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.superAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(submitLabel),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final schools = _filtered;
    final active = _schools.where((s) => s.status.toLowerCase() == 'active').length;
    final withAdmin = _schools.where((s) => (s.adminEmail ?? '').isNotEmpty).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.superAccent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: GradientHeader(
                role: AppRoleStyle.superAdmin,
                eyebrow: 'Network registry',
                title: 'Super Admin',
                subtitle: _schools.isEmpty
                    ? 'No schools registered yet'
                    : '${_schools.length} school${_schools.length == 1 ? '' : 's'} · '
                        'each on its own database',
                actions: [
                  HeaderIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Reload registry',
                    onTap: _load,
                  ),
                  HeaderIconButton(
                    icon: Icons.logout_rounded,
                    tooltip: 'Log out',
                    onTap: () {
                      ref.read(authProvider.notifier).logout();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/LoginScreen',
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_loading && _schools.isEmpty)
                    ...const [
                      SkeletonCard(lines: 2),
                      SizedBox(height: 12),
                      SkeletonCard(lines: 3),
                    ]
                  else if (_error != null)
                    ErrorState(
                      message: _error!,
                      onRetry: _load,
                      icon: Icons.dns_outlined,
                    )
                  else ...[
                    _viewToggle(),
                    const SizedBox(height: AppSpace.lg),
                    if (_showReports)
                      SuperExecutiveReports(schools: _schools)
                    else ...[
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'Schools',
                            value: '${_schools.length}',
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
                            label: 'Sites',
                            value: '${_schools.map((s) => s.site).toSet().length}',
                            icon: Icons.dns_outlined,
                            accent: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search schools, sites or admin emails…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Pressable(
                      onTap: _addSchool,
                      borderRadius: AppRadius.brMd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: AppGradients.superAdmin,
                          borderRadius: AppRadius.brMd,
                          boxShadow: AppShadows.glow(AppColors.superAccent, strength: 0.34),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_business_rounded,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Register new school',
                              style: AppText.cardTitle.copyWith(
                                color: Colors.white,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    SectionHeader(
                      eyebrow: 'Registry',
                      title: schools.length == _schools.length
                          ? 'Schools'
                          : '${schools.length} of ${_schools.length} schools',
                    ),
                    const SizedBox(height: AppSpace.md),
                    if (schools.isEmpty)
                      EmptyState(
                        icon: _schools.isEmpty
                            ? Icons.domain_add_outlined
                            : Icons.search_off_rounded,
                        accent: AppColors.superAccent,
                        title: _schools.isEmpty
                            ? 'No schools registered'
                            : 'No matches',
                        message: _schools.isEmpty
                            ? 'Register the first school to provision its site, database '
                                'and admin account in one step.'
                            : 'Try a different name, site or admin email.',
                      )
                    else
                      StaggeredList(
                        count: schools.length,
                        builder: (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _schoolCard(schools[i]),
                        ),
                      ),
                    ],
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _schoolCard(SuperSchoolModel school) {
    final isActive = school.status.toLowerCase() == 'active';
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppLinear.superTile,
                  borderRadius: AppRadius.brMd,
                ),
                child: const Icon(Icons.apartment_rounded,
                    color: AppColors.superAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      school.schoolName,
                      style: AppText.cardTitle.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${school.site} · port ${school.port}',
                      style: AppText.caption.copyWith(fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: school.status,
                tone: isActive ? PillTone.success : PillTone.warning,
                dense: true,
              ),
            ],
          ),
          if ((school.adminEmail ?? '').isNotEmpty ||
              (school.motto ?? '').isNotEmpty ||
              (school.contactEmail ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((school.adminEmail ?? '').isNotEmpty)
                  StatusPill(
                    label: school.adminName ?? school.adminEmail!,
                    icon: Icons.person_outline_rounded,
                    tone: PillTone.accent,
                    accentOverride: AppColors.superAccent,
                    dense: true,
                  ),
                if ((school.motto ?? '').isNotEmpty)
                  StatusPill(
                    label: school.motto!,
                    icon: Icons.flag_outlined,
                    dense: true,
                  ),
                if ((school.contactEmail ?? '').isNotEmpty)
                  StatusPill(
                    label: school.contactEmail!,
                    icon: Icons.email_outlined,
                    dense: true,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editSchool(school),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _resetAdminPassword(school),
                  icon: const Icon(Icons.password_rounded, size: 16),
                  label: const Text('Password'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Pressable(
                onTap: () => _deleteSchool(school),
                borderRadius: AppRadius.brSm,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: AppRadius.brSm,
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.22)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.dangerDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormDivider extends StatelessWidget {
  final String label;
  const _FormDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.hairlineBorder)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label, style: AppText.eyebrow.copyWith(fontSize: 10)),
          ),
          Expanded(child: Container(height: 1, color: AppColors.hairlineBorder)),
        ],
      ),
    );
  }
}

/// Super-admin specific gradients.
class AppLinear {
  static const superTile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEDEFF9), Color(0xFFDDE1F5)],
  );
}
