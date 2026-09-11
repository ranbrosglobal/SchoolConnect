import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../state/student_provider.dart';
import '../../state/auth_provider.dart' show sheetsServiceProvider;
import '../../models/assignment_model.dart';

class AssignmentDetailScreen extends ConsumerStatefulWidget {
  final AssignmentModel assignment;

  const AssignmentDetailScreen({
    super.key,
    required this.assignment,
  });

  @override
  ConsumerState<AssignmentDetailScreen> createState() =>
      _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends ConsumerState<AssignmentDetailScreen> {
  // Kept in sync with the provider so the screen reflects the latest state
  // after a successful submission.
  late AssignmentModel _assignment = widget.assignment;

  String? _selectedFilePath;
  String? _selectedFileName;
  int? _selectedFileSize;
  List<int>? _selectedFileBytes;
  bool _isSubmitting = false;
  bool _downloading = false;

  Future<void> _downloadAttachment() async {
    final fileId = _assignment.attachment;
    final name = _assignment.attachmentName ?? 'attachment';
    if (fileId == null || fileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attachment file available')),
      );
      return;
    }
    setState(() => _downloading = true);
    try {
      await ref
          .read(sheetsServiceProvider)
          .downloadAndShareFile(fileId, name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opened $name — choose where to save it')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png', 'txt'],
      withData: true, // loads bytes on every platform (web + native)
    );

    if (result != null && result.files.isNotEmpty) {
      if (!mounted) return;
      final file = result.files.first;
      setState(() {
        _selectedFilePath = file.path;
        _selectedFileName = file.name;
        _selectedFileSize = file.size;
        _selectedFileBytes = file.bytes;
      });
    }
  }

  Future<void> _confirmSubmit() async {
    if (_selectedFilePath == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.upload_file, color: Color(0xFF1976D2), size: 40),
        title: const Text('Submit Assignment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${_assignment.title}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_file, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _selectedFileName ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _assignment.submissionStatus == 'Returned'
                  ? 'Make sure this is your revised file. It will replace your returned submission.'
                  : 'Make sure this is the correct file. You can only submit once.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    try {
      final success = await ref.read(studentProvider.notifier).submitAssignment(
        assignment: _assignment.id,
        fileName: _selectedFileName ?? (_selectedFilePath?.split('/').last ?? 'submission'),
        fileBytes: _selectedFileBytes,
      );

      if (!mounted) return;

      if (success) {
        // Refresh from the provider's freshly reloaded list.
        final updated = ref
            .read(studentProvider)
            .assignments
            .where((a) => a.id == _assignment.id)
            .toList();
        setState(() {
          if (updated.isNotEmpty) _assignment = updated.first;
          _selectedFilePath = null;
          _selectedFileName = null;
          _selectedFileSize = null;
          _selectedFileBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = ref.read(studentProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to submit assignment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isOverdue = _assignment.isPastDeadline;
    final isSubmitted = _assignment.isSubmitted;
    final isGraded = _assignment.isGraded;
    final isReturned = _assignment.submissionStatus == 'Returned';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isOverdue && !isSubmitted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Deadline passed',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isSubmitted && !isGraded && !isReturned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Submitted',
                      style: TextStyle(
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isReturned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Returned',
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isGraded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Graded: ${_assignment.displayGrade}/100',
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              _assignment.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Course info
            Row(
              children: [
                Icon(Icons.school_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _assignment.courseName ?? 'Unknown Course',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Instructor info
            Row(
              children: [
                Icon(Icons.person_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _assignment.instructorName ?? 'Unknown Instructor',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Due date
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.calendar_today,
                  color: isOverdue ? Colors.red : Colors.blue,
                ),
                title: Text(
                  'Due Date',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _assignment.dueDate != null
                      ? DateFormat('EEEE, MMMM d, yyyy').format(_assignment.dueDate!)
                      : 'No due date',
                  style: TextStyle(
                    color: isOverdue ? Colors.red : null,
                    fontWeight: isOverdue ? FontWeight.bold : null,
                  ),
                ),
                trailing: _assignment.daysUntilDue != null &&
                        _assignment.daysUntilDue! >= 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _assignment.daysUntilDue! <= 2
                              ? Colors.orange[100]
                              : Colors.blue[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _assignment.daysUntilDue! == 0
                              ? 'Due today'
                              : '${_assignment.daysUntilDue} days left',
                          style: TextStyle(
                            fontSize: 12,
                            color: _assignment.daysUntilDue! <= 2
                                ? Colors.orange[800]
                                : Colors.blue[800],
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            if (_assignment.description != null) ...[
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _assignment.description!,
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Attachment
            if (_assignment.attachment != null) ...[
              Text(
                'Attachment',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.attach_file,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    _assignment.attachmentName ?? 'Attachment',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: _downloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  onTap: _downloading ? null : _downloadAttachment,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Grade & feedback (after grading)
            if (isGraded) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: const Color(0xFF4CAF50).withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.emoji_events_outlined,
                            color: Color(0xFF4CAF50),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Score: ${_assignment.displayGrade}/100',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                      if (_assignment.feedback != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Feedback',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _assignment.feedback!,
                          style: TextStyle(
                            color: Colors.green[800],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Submitted state
            if (isSubmitted && !isGraded) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: const Color(0xFF1976D2).withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: const Color(0xFF1976D2).withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF1976D2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Assignment Submitted',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your submission has been received. The teacher will grade it soon.',
                        style: TextStyle(color: Colors.grey[700], height: 1.4),
                      ),
                      if (_assignment.submissionFileName != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              size: 18,
                              color: Color(0xFF1976D2),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _assignment.submissionFileName!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            if (_assignment.submittedAt != null)
                              Text(
                                DateFormat('MMM d, h:mm a').format(_assignment.submittedAt!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Returned — needs revision
            if (isReturned) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Colors.deepOrange.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Colors.deepOrange.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.assignment_return_outlined,
                            color: Colors.deepOrange,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Returned for revision',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your teacher returned this submission. Revise your work and submit it again.',
                        style: TextStyle(color: Colors.grey[700], height: 1.4),
                      ),
                      if (_assignment.feedback != null) ...[const SizedBox(height: 8), Text('"${_assignment.feedback}"', style: TextStyle(color: Colors.deepOrange.shade800, fontStyle: FontStyle.italic))],
                    ],
                  ),
                ),
              ),
            ],

            // Deadline passed — no more submissions
            if (!isSubmitted && isOverdue && !isReturned) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Colors.red.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.lock_clock_outlined, color: Colors.red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'The submission deadline for this assignment has passed. You can no longer submit.',
                          style: TextStyle(color: Colors.red, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Submit section (before deadline, or returned work)
            if (!isSubmitted && (!isOverdue || isReturned)) ...[
              const SizedBox(height: 16),

              // Selected file preview
              if (_selectedFileName != null) ...[
                Card(
                  elevation: 0,
                  color: const Color(0xFF1976D2).withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: const Color(0xFF1976D2).withValues(alpha: 0.3),
                    ),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.insert_drive_file_outlined,
                      color: Color(0xFF1976D2),
                    ),
                    title: Text(
                      _selectedFileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      _formatFileSize(_selectedFileSize).isEmpty
                          ? 'Ready to submit'
                          : _formatFileSize(_selectedFileSize),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => setState(() {
                        _selectedFilePath = null;
                        _selectedFileName = null;
                        _selectedFileSize = null;
                        _selectedFileBytes = null;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _confirmSubmit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isSubmitting ? 'Submitting...' : 'Submit Assignment',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Pick a file first
                Card(
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.upload_file_outlined,
                          size: 40,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Attach your work to submit',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PDF, DOC, PPT or images',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _pickFile,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Choose File'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
