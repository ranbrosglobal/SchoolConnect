import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../models/assignment_material.dart';
import '../../models/assignment_model.dart';
import '../../models/course_schedule_model.dart';
import '../../state/teacher_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/assignment_material_tile.dart';
import '../../widgets/kit/kit.dart';

/// Create or edit an assignment and attach its materials.
///
/// Works from the class hub (course and class are locked to that class) and
/// from the assignments tab (the teacher picks the class). Files can be PDFs,
/// images, video clips, voice notes, documents or anything else the OS picker
/// returns — up to [kMaxMaterialsPerAssignment], [kMaxMaterialBytes] each.
class CreateAssignmentScreen extends ConsumerStatefulWidget {
  /// When provided, the course and class are fixed to this scheduled class.
  final CourseScheduleModel? courseSchedule;

  /// When provided, the screen edits this existing assignment.
  final AssignmentModel? assignment;

  const CreateAssignmentScreen({
    super.key,
    this.courseSchedule,
    this.assignment,
  });

  @override
  ConsumerState<CreateAssignmentScreen> createState() =>
      _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState
    extends ConsumerState<CreateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCourse;
  String? _selectedGroup;
  DateTime? _dueDate;
  late List<AssignmentMaterial> _existing;
  final List<AssignmentMaterialUpload> _newFiles = [];
  final Set<String> _removeIds = {};
  bool _isSubmitting = false;

  bool get _isEditing => widget.assignment != null;

  /// Creating from a class screen locks course + class so the upload cannot
  /// accidentally land in another class.
  bool get _lockedToClass => widget.courseSchedule != null && !_isEditing;

  @override
  void initState() {
    super.initState();
    final assignment = widget.assignment;
    final schedule = widget.courseSchedule;
    _existing = [...?assignment?.materials];

    if (assignment != null) {
      _titleController.text = assignment.title;
      _descriptionController.text = assignment.description ?? '';
      _selectedCourse = assignment.course;
      _selectedGroup = assignment.studentGroup;
      _dueDate = assignment.dueDate;
    } else if (schedule != null) {
      _selectedCourse = _courseValue(schedule);
      _selectedGroup = schedule.classKey;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(teacherProvider).classes.isEmpty) {
        ref.read(teacherProvider.notifier).loadClasses();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// The teacher-classes endpoint only sends `course_name` (the programme) for
  /// some classes, so fall back to it instead of offering an empty dropdown.
  String _courseValue(CourseScheduleModel c) {
    final course = c.course?.trim() ?? '';
    return course.isNotEmpty ? course : (c.courseName?.trim() ?? '');
  }

  /// Unique courses from the teacher's classes, plus the scheduled class when
  /// the screen was opened from a class that isn't in the loaded list yet.
  List<CourseScheduleModel> get _courses {
    final seen = <String>{};
    final result = <CourseScheduleModel>[];
    final all = [...ref.watch(teacherProvider).classes];
    final schedule = widget.courseSchedule;
    if (schedule != null) all.add(schedule);
    for (final c in all) {
      final courseId = _courseValue(c);
      if (courseId.isNotEmpty && seen.add(courseId)) result.add(c);
    }
    return result;
  }

  List<CourseScheduleModel> get _groups {
    final all = [...ref.watch(teacherProvider).classes];
    final schedule = widget.courseSchedule;
    if (schedule != null && !all.any((c) => c.classKey == schedule.classKey)) {
      all.add(schedule);
    }
    if (_selectedCourse == null) return all;
    return all.where((c) => _courseValue(c) == _selectedCourse).toList();
  }

  int get _materialCount =>
      _existing.where((m) => !_removeIds.contains(m.id)).length +
      _newFiles.length;

  Future<void> _pickMaterials() async {
    final remaining = kMaxMaterialsPerAssignment - _materialCount;
    if (remaining <= 0) {
      _toast(
        'You can attach up to $kMaxMaterialsPerAssignment files.',
        error: true,
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final oversized = <String>[];
    final unreadable = <String>[];
    var added = 0;

    for (final file in result.files) {
      if (_materialCount >= kMaxMaterialsPerAssignment) break;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        unreadable.add(file.name);
        continue;
      }
      if (bytes.length > kMaxMaterialBytes) {
        oversized.add(file.name);
        continue;
      }
      setState(() {
        _newFiles.add(AssignmentMaterialUpload(name: file.name, bytes: bytes));
      });
      added++;
    }

    if (!mounted) return;
    if (oversized.isNotEmpty) {
      _toast(
        '${oversized.first} is larger than 20 MB. Pick a smaller file.',
        error: true,
      );
    } else if (unreadable.isNotEmpty) {
      _toast('Could not read ${unreadable.first}.', error: true);
    } else if (added < result.files.length) {
      _toast(
        'Added $added file${added == 1 ? '' : 's'} — limit is $kMaxMaterialsPerAssignment.',
      );
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final firstDate = _dueDate != null && _dueDate!.isBefore(now)
        ? _dueDate!
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select due date',
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      _toast('Pick a due date for the assignment.', error: true);
      return;
    }
    if (!_lockedToClass &&
        (_selectedCourse == null || _selectedGroup == null)) {
      _toast('Select the course and class for this assignment.', error: true);
      return;
    }
    final classKey = _selectedGroup ?? widget.courseSchedule?.classKey;
    if (classKey == null || classKey.isEmpty) {
      _toast('Select the class for this assignment.', error: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final notifier = ref.read(teacherProvider.notifier);
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final course =
        _selectedCourse ??
        widget.courseSchedule?.course ??
        widget.courseSchedule?.courseName ??
        '';
    final clearAll =
        _isEditing &&
        _existing.isEmpty &&
        _newFiles.isEmpty &&
        (widget.assignment?.hasMaterials ?? false);

    final success = _isEditing
        ? await notifier.updateAssignment(
            assignmentId: widget.assignment!.id,
            title: _titleController.text.trim(),
            course: course,
            studentGroup: classKey,
            dueDate: _dueDate!,
            description: description,
            newFiles: _newFiles,
            removeFileIds: _removeIds.toList(),
            clearAttachments: clearAll,
          )
        : await notifier.createAssignment(
            title: _titleController.text.trim(),
            course: course,
            studentGroup: classKey,
            dueDate: _dueDate!,
            description: description,
            files: _newFiles,
          );

    if (!mounted) return;

    if (success) {
      _toast(_isEditing ? 'Assignment updated.' : 'Assignment uploaded.');
      Navigator.of(context).pop(true);
    } else {
      setState(() => _isSubmitting = false);
      _toast(
        ref.read(teacherProvider).error ?? 'Could not save the assignment.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(teacherProvider).classes;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Assignment' : 'Upload Assignment',
          style: AppText.cardTitle.copyWith(fontSize: 17),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            if (_lockedToClass)
              _classBanner()
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedCourse,
                decoration: const InputDecoration(
                  labelText: 'Course / Subject',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                items: _courses
                    .map(
                      (c) => DropdownMenuItem(
                        value: _courseValue(c),
                        child: Text(c.courseName ?? c.course ?? 'Unknown'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedCourse = value;
                  _selectedGroup = null;
                }),
                validator: (v) => v == null ? 'Select a course' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('group_$_selectedCourse'),
                initialValue: _selectedGroup,
                decoration: const InputDecoration(
                  labelText: 'Class / Student Group',
                  prefixIcon: Icon(Icons.class_),
                ),
                items: _groups
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.studentGroup,
                        child: Text(
                          c.studentGroupName ?? c.studentGroup ?? 'Unknown',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedGroup = value),
                validator: (v) => v == null ? 'Select a class' : null,
              ),
              if (classes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Loading your classes…',
                    style: AppText.caption.copyWith(fontSize: 11.5),
                  ),
                ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Assignment title',
                hintText: 'e.g. Chapter 3 worksheet',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDueDate,
              borderRadius: AppRadius.brMd,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Due date',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                child: Text(
                  _dueDate != null
                      ? DateFormat('EEEE, d MMMM yyyy').format(_dueDate!)
                      : 'Select due date',
                  style: TextStyle(
                    fontSize: 15,
                    color: _dueDate == null
                        ? AppColors.inkFaint
                        : AppColors.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Instructions (optional)',
                hintText: 'What should students do with this material?',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 20),
            _materialsSection(),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isEditing
                            ? Icons.save_rounded
                            : Icons.cloud_upload_rounded,
                      ),
                label: Text(
                  _isSubmitting
                      ? 'Uploading…'
                      : _isEditing
                      ? 'Save changes'
                      : 'Upload assignment',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teacherAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classBanner() {
    final schedule = widget.courseSchedule!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppRoleStyle.teacher.gradient,
        borderRadius: AppRadius.brLg,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: AppRadius.brSm,
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.studentGroupName ?? 'This class',
                  style: AppText.cardTitle.copyWith(
                    color: Colors.white,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  schedule.courseName ?? schedule.course ?? 'Class upload',
                  style: AppText.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialsSection() {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.attach_file_rounded,
                size: 18,
                color: AppColors.teacherAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Materials',
                  style: AppText.cardTitle.copyWith(fontSize: 14),
                ),
              ),
              Text(
                '$_materialCount/$kMaxMaterialsPerAssignment',
                style: AppText.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _materialCount >= kMaxMaterialsPerAssignment
                      ? AppColors.warningDark
                      : AppColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'PDF, documents, images, video and voice notes. '
            'Up to $kMaxMaterialsPerAssignment files, 20 MB each.',
            style: AppText.caption.copyWith(fontSize: 11, height: 1.4),
          ),
          if (_existing.isNotEmpty || _newFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final material in _existing)
              if (!_removeIds.contains(material.id))
                AssignmentMaterialTile(
                  material: material,
                  compact: true,
                  onRemove: () => setState(() {
                    _removeIds.add(material.id);
                  }),
                ),
            for (var i = 0; i < _newFiles.length; i++)
              AssignmentMaterialTile(
                material: AssignmentMaterial(
                  id: 'new-$i',
                  name: _newFiles[i].name,
                  kind: _newFiles[i].kind,
                  size: _newFiles[i].size,
                ),
                compact: true,
                onRemove: () => setState(() {
                  _newFiles.removeAt(i);
                }),
              ),
          ],
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _pickMaterials,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add files'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.teacherAccent,
              side: BorderSide(
                color: AppColors.teacherAccent.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
