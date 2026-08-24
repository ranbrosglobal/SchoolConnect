import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/student_group_model.dart';
import '../../models/course_schedule_model.dart';
import '../../state/auth_provider.dart';

/// Teacher's class & subject editor — add new classes, edit their details,
/// remove them, and manage the subjects (course schedules) within each class.
class TeacherManageClassesScreen extends ConsumerStatefulWidget {
  const TeacherManageClassesScreen({super.key});

  @override
  ConsumerState<TeacherManageClassesScreen> createState() =>
      _TeacherManageClassesScreenState();
}

class _TeacherManageClassesScreenState
    extends ConsumerState<TeacherManageClassesScreen> {
  List<StudentGroupModel> _groups = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

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
      final service = ref.read(sheetsServiceProvider);
      final groups = await service.getStudentGroups();
      if (!mounted) return;
      setState(() {
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
          'Manage Classes',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1976D2)),
            tooltip: 'Add class',
            onPressed: _busy ? null : _addClass,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addClass,
        backgroundColor: const Color(0xFF1976D2),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Class',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: _buildBody(),
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
            const Text('Could not load classes.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.class_outlined, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No classes yet. Tap "Add Class" to create one.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      itemCount: _groups.length,
      itemBuilder: (context, index) => _buildClassCard(_groups[index]),
    );
  }

  Widget _buildClassCard(StudentGroupModel group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.class_outlined,
                    color: Color(0xFF388E3C),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      if (group.program != null && group.program!.isNotEmpty)
                        Text(
                          group.program!,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF1976D2)),
                  tooltip: 'Edit class',
                  onPressed: _busy ? null : () => _editClass(group),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  tooltip: 'Remove class',
                  onPressed: _busy ? null : () => _removeClass(group),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _manageSubjects(group),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text(
                  'Manage Subjects',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1976D2),
                  side: const BorderSide(color: Color(0xFF1976D2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Class mutations
  // ------------------------------------------------------------------
  Future<void> _addClass() async {
    final data = await showDialog<_ClassFormData>(
      context: context,
      builder: (_) => const _ClassFormDialog(),
    );
    if (data == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(sheetsServiceProvider).createStudentGroup(
            name: data.name,
            program: data.program,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${data.name} created.'),
          backgroundColor: const Color(0xFF388E3C),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create class: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editClass(StudentGroupModel group) async {
    final data = await showDialog<_ClassFormData>(
      context: context,
      builder: (_) => _ClassFormDialog(group: group),
    );
    if (data == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(sheetsServiceProvider).updateStudentGroup(
            groupId: group.id,
            name: data.name,
            program: data.program,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class updated.'),
          backgroundColor: Color(0xFF1976D2),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update class: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeClass(StudentGroupModel group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove class?'),
        content: Text(
          '"${group.name}" will be permanently removed along with its schedules, '
          'assignments and attendance records. Students in this class will be '
          'unassigned. This cannot be undone.',
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
      await ref.read(sheetsServiceProvider).deleteStudentGroup(group.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${group.name} removed.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove class: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------------
  // Navigate to subject management for a specific class
  // ------------------------------------------------------------------
  void _manageSubjects(StudentGroupModel group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SubjectManagementScreen(group: group),
      ),
    );
  }
}

// ======================================================================
// Class form data
// ======================================================================
class _ClassFormData {
  final String name;
  final String? program;
  _ClassFormData({required this.name, this.program});
}

class _ClassFormDialog extends StatefulWidget {
  final StudentGroupModel? group;
  const _ClassFormDialog({this.group});

  @override
  State<_ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends State<_ClassFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _program;

  bool get _isEdit => widget.group != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.group?.name ?? '');
    _program = TextEditingController(text: widget.group?.program ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _program.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_ClassFormData(
      name: _name.text.trim(),
      program: _program.text.trim().isEmpty ? null : _program.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit ? 'Edit Class' : 'Add Class',
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
                decoration: InputDecoration(
                  hintText: 'Class name (e.g. Grade 10 - A)',
                  hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.class_outlined, color: Color(0xFF388E3C), size: 20),
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
                    borderSide: const BorderSide(color: Color(0xFF388E3C), width: 1.5),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Class name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _program,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Program / Grade (optional)',
                  hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.school_outlined, color: Color(0xFF388E3C), size: 20),
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
                    borderSide: const BorderSide(color: Color(0xFF388E3C), width: 1.5),
                  ),
                ),
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
            backgroundColor: const Color(0xFF388E3C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(_isEdit ? 'Save Changes' : 'Add Class'),
        ),
      ],
    );
  }
}

// ======================================================================
// Subject management for a single class
// ======================================================================
class _SubjectManagementScreen extends ConsumerStatefulWidget {
  final StudentGroupModel group;
  const _SubjectManagementScreen({required this.group});

  @override
  ConsumerState<_SubjectManagementScreen> createState() =>
      _SubjectManagementScreenState();
}

class _SubjectManagementScreenState
    extends ConsumerState<_SubjectManagementScreen> {
  List<CourseScheduleModel> _schedules = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

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
      final service = ref.read(sheetsServiceProvider);
      final schedules = await service.getCourseSchedulesForGroup(widget.group.id);
      if (!mounted) return;
      setState(() {
        _schedules = schedules;
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

  /// Deduplicate subjects by course name for display (each subject = unique course in this class)
  List<CourseScheduleModel> get _uniqueSubjects {
    final seen = <String>{};
    final result = <CourseScheduleModel>[];
    for (final s in _schedules) {
      final key = s.course ?? s.courseName ?? '';
      if (seen.add(key)) result.add(s);
    }
    return result;
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
        title: Text(
          '${widget.group.name} — Subjects',
          style: const TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1976D2)),
            tooltip: 'Add subject',
            onPressed: _busy ? null : _addSubject,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addSubject,
        backgroundColor: const Color(0xFF1976D2),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Subject',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: _buildBody(),
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
            const Text('Could not load subjects.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final subjects = _uniqueSubjects;
    if (subjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No subjects yet. Tap "Add Subject" to add one.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      itemCount: subjects.length,
      itemBuilder: (context, index) => _buildSubjectRow(subjects[index]),
    );
  }

  Widget _buildSubjectRow(CourseScheduleModel sched) {
    final timeInfo = [
      if (sched.startTime != null) sched.startTime!,
      if (sched.endTime != null) sched.endTime!,
    ].join(' – ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_outlined, color: Color(0xFF1976D2), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sched.courseName ?? sched.course ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (sched.instructorName != null && sched.instructorName!.isNotEmpty)
                    Text(
                      sched.instructorName!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  if (timeInfo.isNotEmpty)
                    Text(
                      timeInfo,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  if (sched.room != null && sched.room!.isNotEmpty)
                    Text(
                      sched.room!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF1976D2)),
              tooltip: 'Edit subject',
              onPressed: _busy ? null : () => _editSubject(sched),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              tooltip: 'Remove subject',
              onPressed: _busy ? null : () => _removeSubject(sched),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Subject mutations
  // ------------------------------------------------------------------
  Future<void> _addSubject() async {
    final data = await showDialog<_SubjectFormData>(
      context: context,
      builder: (_) => const _SubjectFormDialog(),
    );
    if (data == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(sheetsServiceProvider).createCourseSchedule(
            course: data.course,
            courseName: data.courseName,
            groupId: widget.group.id,
            room: data.room,
            fromTime: data.fromTime,
            toTime: data.toTime,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${data.courseName} added to ${widget.group.name}.'),
          backgroundColor: const Color(0xFF1976D2),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add subject: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editSubject(CourseScheduleModel sched) async {
    // Find all schedules for this course so we can update them all
    final data = await showDialog<_SubjectFormData>(
      context: context,
      builder: (_) => _SubjectFormDialog(
        course: sched.courseName ?? sched.course,
        room: sched.room,
        fromTime: sched.startTime,
        toTime: sched.endTime,
      ),
    );
    if (data == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final service = ref.read(sheetsServiceProvider);
      // Update all schedule rows for this course in this group
      final allSchedules = await service.getCourseSchedulesForGroup(widget.group.id);
      final sameCourse = allSchedules.where((s) => s.course == sched.course);
      for (final s in sameCourse) {
        await service.updateCourseSchedule(
          scheduleId: s.id,
          course: data.course,
          courseName: data.courseName,
          room: data.room,
          fromTime: data.fromTime,
          toTime: data.toTime,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subject updated.'),
          backgroundColor: Color(0xFF1976D2),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update subject: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeSubject(CourseScheduleModel sched) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove subject?'),
        content: Text(
          '"${sched.courseName ?? sched.course}" will be removed from ${widget.group.name}. '
          'All attendance records for this subject will also be deleted. This cannot be undone.',
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
      final service = ref.read(sheetsServiceProvider);
      // Delete all schedule rows for this course in this group
      final allSchedules = await service.getCourseSchedulesForGroup(widget.group.id);
      final sameCourse = allSchedules.where((s) => s.course == sched.course);
      for (final s in sameCourse) {
        await service.deleteCourseSchedule(s.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${sched.courseName ?? sched.course} removed.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove subject: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ======================================================================
// Subject form data
// ======================================================================
class _SubjectFormData {
  final String course;
  final String courseName;
  final String? room;
  final String? fromTime;
  final String? toTime;

  _SubjectFormData({
    required this.course,
    required this.courseName,
    this.room,
    this.fromTime,
    this.toTime,
  });
}

class _SubjectFormDialog extends StatefulWidget {
  final String? course;
  final String? room;
  final String? fromTime;
  final String? toTime;

  const _SubjectFormDialog({this.course, this.room, this.fromTime, this.toTime});

  @override
  State<_SubjectFormDialog> createState() => _SubjectFormDialogState();
}

class _SubjectFormDialogState extends State<_SubjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _course;
  late final TextEditingController _room;
  late final TextEditingController _fromTime;
  late final TextEditingController _toTime;

  bool get _isEdit => widget.course != null;

  @override
  void initState() {
    super.initState();
    _course = TextEditingController(text: widget.course ?? '');
    _room = TextEditingController(text: widget.room ?? '');
    _fromTime = TextEditingController(text: widget.fromTime ?? '09:00');
    _toTime = TextEditingController(text: widget.toTime ?? '10:00');
  }

  @override
  void dispose() {
    _course.dispose();
    _room.dispose();
    _fromTime.dispose();
    _toTime.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final name = _course.text.trim();
    Navigator.of(context).pop(_SubjectFormData(
      course: name,
      courseName: name,
      room: _room.text.trim().isEmpty ? null : _room.text.trim(),
      fromTime: _fromTime.text.trim().isEmpty ? null : _fromTime.text.trim(),
      toTime: _toTime.text.trim().isEmpty ? null : _toTime.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit ? 'Edit Subject' : 'Add Subject',
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
                controller: _course,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Subject name (e.g. Mathematics)',
                  hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.menu_book_outlined, color: Color(0xFF1976D2), size: 20),
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
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Subject name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _room,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Room (optional)',
                  hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.room_outlined, color: Color(0xFF1976D2), size: 20),
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
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fromTime,
                      decoration: InputDecoration(
                        hintText: 'Start (e.g. 09:00)',
                        hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.access_time, color: Color(0xFF1976D2), size: 20),
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
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _toTime,
                      decoration: InputDecoration(
                        hintText: 'End (e.g. 10:00)',
                        hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.access_time_filled, color: Color(0xFF1976D2), size: 20),
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
                      ),
                    ),
                  ),
                ],
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(_isEdit ? 'Save Changes' : 'Add Subject'),
        ),
      ],
    );
  }
}
