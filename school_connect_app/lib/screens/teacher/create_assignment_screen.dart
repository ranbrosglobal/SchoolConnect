import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../state/teacher_provider.dart';
import '../../models/course_schedule_model.dart';
import '../../models/assignment_model.dart';

class CreateAssignmentScreen extends ConsumerStatefulWidget {
  /// When provided, the screen edits this existing assignment instead of
  /// creating a new one.
  final AssignmentModel? assignment;

  const CreateAssignmentScreen({super.key, this.assignment});

  @override
  ConsumerState<CreateAssignmentScreen> createState() =>
      _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends ConsumerState<CreateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCourse;
  String? _selectedGroup;
  DateTime? _dueDate;
  String? _attachmentPath;
  String? _attachmentName;
  List<int>? _attachmentBytes;
  bool _isSubmitting = false;

  bool get _isEditing => widget.assignment != null;

  @override
  void initState() {
    super.initState();
    final assignment = widget.assignment;
    if (assignment != null) {
      _titleController.text = assignment.title;
      _descriptionController.text = assignment.description ?? '';
      _selectedCourse = assignment.course;
      _selectedGroup = assignment.studentGroup;
      _dueDate = assignment.dueDate;
      _attachmentName = assignment.attachmentName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Unique courses from the teacher's assigned classes.
  List<CourseScheduleModel> get _courses {
    final seen = <String>{};
    final result = <CourseScheduleModel>[];
    for (final c in ref.read(teacherProvider).classes) {
      final courseId = c.course ?? '';
      if (courseId.isNotEmpty && seen.add(courseId)) {
        result.add(c);
      }
    }
    return result;
  }

  /// Student groups filtered by the selected course.
  List<CourseScheduleModel> get _groups {
    final all = ref.read(teacherProvider).classes;
    if (_selectedCourse == null) return all;
    return all.where((c) => c.course == _selectedCourse).toList();
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png', 'txt'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _attachmentPath = result.files.first.path;
        _attachmentName = result.files.first.name;
        _attachmentBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    // When editing an overdue assignment, keep its past due date selectable
    // so the picker never asserts on initialDate < firstDate.
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
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourse == null || _selectedGroup == null || _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a course, class and due date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final notifier = ref.read(teacherProvider.notifier);
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    // The user cleared an attachment that the assignment previously had.
    final clearedAttachment = _isEditing &&
        widget.assignment!.attachmentName != null &&
        _attachmentName == null;

    final success = _isEditing
        ? await notifier.updateAssignment(
            assignmentId: widget.assignment!.id,
            title: _titleController.text.trim(),
            course: _selectedCourse!,
            studentGroup: _selectedGroup!,
            dueDate: _dueDate!,
            description: description,
            filePath: _attachmentPath,
            fileBytes: _attachmentBytes,
            clearAttachment: clearedAttachment,
          )
        : await notifier.createAssignment(
            title: _titleController.text.trim(),
            course: _selectedCourse!,
            studentGroup: _selectedGroup!,
            dueDate: _dueDate!,
            description: description,
            filePath: _attachmentPath,
            fileBytes: _attachmentBytes,
          );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Assignment updated successfully!'
                : 'Assignment created successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      final error = ref.read(teacherProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to create assignment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Assignment' : 'Create Assignment'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Assignment Title',
                hintText: 'e.g. Algebra Problem Set',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            // Course dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCourse,
              decoration: const InputDecoration(
                labelText: 'Course / Subject',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              items: _courses
                  .map((c) => DropdownMenuItem(
                        value: c.course,
                        child: Text(c.courseName ?? c.course ?? 'Unknown'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedCourse = value;
                _selectedGroup = null;
              }),
              validator: (v) => v == null ? 'Select a course' : null,
            ),
            const SizedBox(height: 16),

            // Class dropdown
            DropdownButtonFormField<String>(
              key: ValueKey('group_$_selectedCourse'),
              initialValue: _selectedGroup,
              decoration: const InputDecoration(
                labelText: 'Class / Student Group',
                prefixIcon: Icon(Icons.class_),
              ),
              items: _groups
                  .map((c) => DropdownMenuItem(
                        value: c.studentGroup,
                        child: Text(c.studentGroupName ?? c.studentGroup ?? 'Unknown'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedGroup = value),
              validator: (v) => v == null ? 'Select a class' : null,
            ),
            const SizedBox(height: 16),

            // Due date
            InkWell(
              onTap: _pickDueDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Due Date',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _dueDate != null
                      ? DateFormat('EEEE, MMMM d, yyyy').format(_dueDate!)
                      : 'Select due date',
                  style: TextStyle(
                    fontSize: 16,
                    color: _dueDate == null ? Colors.grey[600] : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the assignment...',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 16),

            // Attachment
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: const Icon(Icons.attach_file, color: Color(0xFF1976D2)),
                title: Text(
                  _attachmentName ?? 'Attach a file (optional)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                        _attachmentName != null ? FontWeight.w600 : null,
                  ),
                ),
                subtitle: _attachmentName == null
                    ? const Text('PDF, DOC, images')
                    : null,
                trailing: IconButton(
                  icon: Icon(
                    _attachmentName != null ? Icons.close : Icons.cloud_upload,
                  ),
                  onPressed: _attachmentName != null
                      ? () => setState(() {
                            _attachmentPath = null;
                            _attachmentName = null;
                            _attachmentBytes = null;
                          })
                      : _pickAttachment,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isSubmitting
                      ? (_isEditing ? 'Saving...' : 'Creating...')
                      : (_isEditing ? 'Save Changes' : 'Create Assignment'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
