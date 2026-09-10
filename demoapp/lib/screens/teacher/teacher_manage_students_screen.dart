import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/student_group_model.dart';
import '../../models/student_model.dart';
import '../../state/auth_provider.dart';

/// Teacher's student editor — add new students, edit their details, or
/// remove them. Changes are written straight to the local database so they
/// show up everywhere (class rosters, attendance marking, assignment counts).
class TeacherManageStudentsScreen extends ConsumerStatefulWidget {
  const TeacherManageStudentsScreen({super.key});

  @override
  ConsumerState<TeacherManageStudentsScreen> createState() =>
      _TeacherManageStudentsScreenState();
}

class _TeacherManageStudentsScreenState
    extends ConsumerState<TeacherManageStudentsScreen> {
  List<StudentModel> _students = [];
  List<StudentGroupModel> _groups = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _query = '';
  String? _groupFilter; // null = All classes
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(demoApiServiceProvider);
      final students = await service.getAllStudents();
      final groups = await service.getStudentGroups();
      if (!mounted) return;
      setState(() {
        _students = students;
        _groups = groups;
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

  List<StudentModel> get _filtered {
    final q = _query.trim().toLowerCase();
    return _students.where((s) {
      if (_groupFilter != null && s.studentGroup != _groupFilter) return false;
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          (s.email ?? '').toLowerCase().contains(q) ||
          (s.rollNumber ?? '').contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E3A8A), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Students',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt, color: Color(0xFF1976D2)),
            tooltip: 'Add student',
            onPressed: _busy ? null : _addStudent,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addStudent,
        backgroundColor: const Color(0xFF1976D2),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Student',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildClassFilter(),
          const Divider(height: 1, color: Colors.grey),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Search by name, email or roll no.',
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 22),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildClassFilter() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _filterChip(label: 'All', value: null),
          for (final g in _groups)
            _filterChip(label: g.name, value: g.id),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required String? value}) {
    final selected = _groupFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _groupFilter = value),
        showCheckmark: false,
        selectedColor: const Color(0xFF1976D2),
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.grey.shade700,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: Colors.red.shade300),
            const SizedBox(height: 12),
            const Text('Could not load students.',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty && _groupFilter == null
                  ? 'No students yet. Tap “Add Student” to add one.'
                  : 'No students match your search.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group the filtered list by class; if a class filter is active there is
    // exactly one section.
    final sections = <String, List<StudentModel>>{};
    for (final s in filtered) {
      sections.putIfAbsent(s.studentGroup ?? '', () => []).add(s);
    }
    final orderedGroups = _groups
        .where((g) => sections.containsKey(g.id))
        .map((g) => g)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      children: [
        for (final g in orderedGroups) ...[
          _buildClassHeader(g.name, sections[g.id]!.length),
          const SizedBox(height: 8),
          for (final s in sections[g.id]!) _buildStudentRow(s),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildClassHeader(String name, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1976D2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(StudentModel student) {
    final info = [
      if (student.gender != null && student.gender!.isNotEmpty) student.gender!,
      if (student.age != null) '${student.age} yrs',
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE3F2FD),
              child: Text(
                student.rollNumber ?? '-',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info.isEmpty
                        ? (student.email ?? 'No email')
                        : info + (student.email != null && student.email!.isNotEmpty ? ' • ${student.email}' : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF1976D2)),
              tooltip: 'Edit student',
              onPressed: _busy ? null : () => _editStudent(student),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              tooltip: 'Remove student',
              onPressed: _busy ? null : () => _removeStudent(student),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Mutations
  // ------------------------------------------------------------------
  Future<void> _addStudent() async {
    final data = await showDialog<_StudentFormData>(
      context: context,
      builder: (_) => _StudentFormDialog(
        groups: _groups,
        defaultGroupId: _groupFilter,
      ),
    );
    if (data == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(demoApiServiceProvider).createStudent(
            name: data.name,
            email: data.email,
            groupId: data.groupId,
            rollNumber: data.rollNumber,
            age: data.age,
            gender: data.gender,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${data.name} added to the class.'),
          backgroundColor: const Color(0xFF1976D2),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add student: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editStudent(StudentModel student) async {
    final data = await showDialog<_StudentFormData>(
      context: context,
      builder: (_) => _StudentFormDialog(groups: _groups, student: student),
    );
    if (data == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(demoApiServiceProvider).updateStudent(
            studentId: student.id,
            name: data.name,
            email: data.email,
            groupId: data.groupId,
            rollNumber: data.rollNumber,
            age: data.age,
            gender: data.gender,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student details updated.'),
          backgroundColor: Color(0xFF1976D2),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update student: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeStudent(StudentModel student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text(
          '“${student.name}” will be removed from the class along with their '
          'attendance and assignment records. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(demoApiServiceProvider).deleteStudent(student.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student.name} removed.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove student: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Result of the add/edit student form.
class _StudentFormData {
  final String name;
  final String? email;
  final String groupId;
  final int? rollNumber;
  final int? age;
  final String? gender;

  _StudentFormData({
    required this.name,
    required this.email,
    required this.groupId,
    required this.rollNumber,
    required this.age,
    required this.gender,
  });
}

/// Modal form for adding a new student or editing an existing one.
class _StudentFormDialog extends StatefulWidget {
  final List<StudentGroupModel> groups;
  final StudentModel? student;
  final String? defaultGroupId;

  const _StudentFormDialog({
    required this.groups,
    this.student,
    this.defaultGroupId,
  });

  @override
  State<_StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<_StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _roll;
  late final TextEditingController _age;
  String? _groupId;
  String? _gender;

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _name = TextEditingController(text: s?.name ?? '');
    _email = TextEditingController(text: s?.email ?? '');
    _roll = TextEditingController(text: s?.rollNumber ?? '');
    _age = TextEditingController(text: s?.age?.toString() ?? '');
    _groupId = s?.studentGroup ??
        widget.defaultGroupId ??
        (widget.groups.isNotEmpty ? widget.groups.first.id : null);
    _gender = s?.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _roll.dispose();
    _age.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final data = _StudentFormData(
      name: _name.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      groupId: _groupId ?? '',
      rollNumber: int.tryParse(_roll.text.trim()),
      age: int.tryParse(_age.text.trim()),
      gender: _gender,
    );
    if (data.groupId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a class.')),
      );
      return;
    }
    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit ? 'Edit Student' : 'Add Student',
        style: const TextStyle(
          color: Color(0xFF1E3A8A),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: _deco('Full name', Icons.person_outline),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _deco('Email (optional)', Icons.email_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _groupId,
                decoration: _deco('Class', Icons.class_outlined),
                items: [
                  for (final g in widget.groups)
                    DropdownMenuItem(value: g.id, child: Text(g.name)),
                ],
                onChanged: (v) => setState(() => _groupId = v),
                validator: (v) => v == null ? 'Choose a class' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _roll,
                      keyboardType: TextInputType.number,
                      decoration: _deco('Roll no. (optional)', Icons.numbers),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (int.tryParse(v.trim()) == null) {
                          return 'Numbers only';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      decoration: _deco('Age (optional)', Icons.cake_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final age = int.tryParse(v.trim());
                        if (age == null) return 'Numbers only';
                        if (age < 3 || age > 25) return 'Enter a valid age';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _gender,
                decoration: _deco('Gender (optional)', Icons.wc_outlined),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(_isEdit ? 'Save Changes' : 'Add Student'),
        ),
      ],
    );
  }

  InputDecoration _deco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: const Color(0xFF1976D2), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
      ),
    );
  }
}
