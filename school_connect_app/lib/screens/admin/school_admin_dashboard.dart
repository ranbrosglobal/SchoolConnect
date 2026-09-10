import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/colors.dart';
import '../../state/auth_provider.dart';
import '../../models/user_model.dart';

/// Full School Admin dashboard — replaces the old "go to web" redirect.
/// Provides overview stats, teacher/student/class management, and school
/// settings — all powered by Google Sheets (same backend as teacher/student).
class SchoolAdminDashboard extends ConsumerStatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  ConsumerState<SchoolAdminDashboard> createState() =>
      _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends ConsumerState<SchoolAdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Stats
  bool _loading = true;
  int _teacherCount = 0;
  int _studentCount = 0;
  int _classCount = 0;
  int _assignmentCount = 0;
  String _schoolName = 'School';
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(sheetsServiceProvider);
      final user = ref.read(authProvider).user;
      _schoolName = user?.schoolName ?? 'School';

      final teachers = await service.getAdminTeachers();
      final students = await service.getAdminStudents();
      final classes = await service.getAdminClasses();
      final assignments = await service.getMyTeacherAssignments();

      if (!mounted) return;
      setState(() {
        _teacherCount = teachers.length;
        _studentCount = students.length;
        _classCount = classes.length;
        _assignmentCount = assignments.length;
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(user),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(
                    loading: _loading,
                    teacherCount: _teacherCount,
                    studentCount: _studentCount,
                    classCount: _classCount,
                    assignmentCount: _assignmentCount,
                    schoolName: _schoolName,
                    onRefresh: _loadStats,
                  ),
                  _TeachersTab(),
                  _StudentsTab(),
                  _SchoolSettingsTab(schoolName: _schoolName),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel? user) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Log Out',
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/LoginScreen',
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome, ${user?.fullName ?? 'Admin'}',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _schoolName,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.outline,
        indicatorColor: AppColors.primary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(icon: Icon(Icons.dashboard_outlined, size: 20), text: 'Overview'),
          Tab(icon: Icon(Icons.people_outline, size: 20), text: 'Teachers'),
          Tab(icon: Icon(Icons.school_outlined, size: 20), text: 'Students'),
          Tab(icon: Icon(Icons.settings_outlined, size: 20), text: 'Settings'),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final bool loading;
  final int teacherCount;
  final int studentCount;
  final int classCount;
  final int assignmentCount;
  final String schoolName;
  final VoidCallback onRefresh;

  const _OverviewTab({
    required this.loading,
    required this.teacherCount,
    required this.studentCount,
    required this.classCount,
    required this.assignmentCount,
    required this.schoolName,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 20),
          _buildQuickActions(context),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.5,
      children: [
        _statCard('Teachers', '$teacherCount', Icons.people_outline, const Color(0xFF1976D2), const Color(0xFFE3F2FD)),
        _statCard('Students', '$studentCount', Icons.school_outlined, const Color(0xFF4CAF50), const Color(0xFFE8F5E9)),
        _statCard('Classes', '$classCount', Icons.class_outlined, const Color(0xFF9C27B0), const Color(0xFFF3E5F5)),
        _statCard('Assignments', '$assignmentCount', Icons.assignment_outlined, const Color(0xFFFF9800), const Color(0xFFFFF3E0)),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A))),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _actionCard(Icons.person_add_outlined, 'Add\nTeacher', const Color(0xFF1976D2), () {})),
            const SizedBox(width: 12),
            Expanded(child: _actionCard(Icons.person_add_outlined, 'Add\nStudent', const Color(0xFF4CAF50), () {})),
            const SizedBox(width: 12),
            Expanded(child: _actionCard(Icons.class_outlined, 'Manage\nClasses', const Color(0xFF9C27B0), () {})),
          ],
        ),
      ],
    );
  }

  Widget _actionCard(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

// ─── Teachers Tab ─────────────────────────────────────────────────────
class _TeachersTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends ConsumerState<_TeachersTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _teachers = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final teachers = await ref.read(sheetsServiceProvider).getAdminTeachers();
      if (!mounted) return;
      setState(() {
        _teachers = teachers.map((t) => {
          'name': t.name,
          'email': t.email ?? '',
          'status': t.isEnabled ? 'Active' : 'Disabled',
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _teachers.where((t) {
      if (_query.isEmpty) return true;
      return t['name'].toLowerCase().contains(_query.toLowerCase()) ||
          t['email'].toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search teachers...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(child: Text('No teachers found.', style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final t = filtered[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFE3F2FD),
                                child: Text(
                                  (t['name'] as String).substring(0, 1).toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1976D2)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Text(t['email'], style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: t['status'] == 'Active' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(t['status'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: t['status'] == 'Active' ? Colors.green.shade700 : Colors.orange.shade700)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─── Students Tab ─────────────────────────────────────────────────────
class _StudentsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends ConsumerState<_StudentsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _students = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final students = await ref.read(sheetsServiceProvider).getAdminStudents();
      if (!mounted) return;
      setState(() {
        _students = students.map((s) => {
          'name': s.name,
          'email': s.email ?? '',
          'group': s.studentGroup ?? '',
          'status': s.isEnabled ? 'Active' : 'Disabled',
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _students.where((s) {
      if (_query.isEmpty) return true;
      return s['name'].toLowerCase().contains(_query.toLowerCase()) ||
          s['email'].toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search students...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(child: Text('No students found.', style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFE8F5E9),
                                child: Text(
                                  (s['name'] as String).substring(0, 1).toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4CAF50)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Text(
                                      [s['email'], if ((s['group'] as String).isNotEmpty) s['group']].where((e) => (e as String).isNotEmpty).join(' • '),
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: s['status'] == 'Active' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(s['status'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: s['status'] == 'Active' ? Colors.green.shade700 : Colors.orange.shade700)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─── School Settings Tab ──────────────────────────────────────────────
class _SchoolSettingsTab extends ConsumerStatefulWidget {
  final String schoolName;
  const _SchoolSettingsTab({required this.schoolName});

  @override
  ConsumerState<_SchoolSettingsTab> createState() => _SchoolSettingsTabState();
}

class _SchoolSettingsTabState extends ConsumerState<_SchoolSettingsTab> {
  bool _loading = true;
  String _motto = '';
  String _contactEmail = '';
  String _contactNumber = '';
  String _website = '';
  String _address = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await ref.read(sheetsServiceProvider).getSchoolProfile();
      if (!mounted) return;
      setState(() {
        _motto = profile.motto ?? '';
        _contactEmail = profile.contactEmail ?? '';
        _contactNumber = profile.contactNumber ?? '';
        _website = profile.website ?? '';
        _address = profile.address ?? '';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _infoCard('School Name', widget.schoolName, Icons.school_outlined),
        const SizedBox(height: 12),
        _infoCard('Motto', _motto.isEmpty ? 'Not set' : _motto, Icons.flag_outlined),
        const SizedBox(height: 12),
        _infoCard('Contact Email', _contactEmail.isEmpty ? 'Not set' : _contactEmail, Icons.email_outlined),
        const SizedBox(height: 12),
        _infoCard('Phone', _contactNumber.isEmpty ? 'Not set' : _contactNumber, Icons.phone_outlined),
        const SizedBox(height: 12),
        _infoCard('Website', _website.isEmpty ? 'Not set' : _website, Icons.language),
        const SizedBox(height: 12),
        _infoCard('Address', _address.isEmpty ? 'Not set' : _address, Icons.location_on_outlined),
        const SizedBox(height: 24),
        Text(
          'School information is managed from the spreadsheet. '
          'Edit the Schools tab to update these values.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
