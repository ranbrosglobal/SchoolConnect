class AssignmentModel {
  final String id;
  final String title;
  final String? description;
  final String? course;
  final String? courseName;
  final String? studentGroup;
  final String? studentGroupName;
  final String? instructor;
  final String? instructorName;
  final DateTime? dueDate;
  final String? fromTime;
  final String? toTime;
  final DateTime? creation;
  final String? attachment;
  final String? attachmentName;

  // Submission info (student view)
  final bool submitted;
  final double? grade;
  final String? feedback;
  final String? submissionStatus;
  final String? submissionFile;
  final String? submissionFileName;
  final DateTime? submittedAt;

  // Stats (teacher view)
  final int totalStudents;
  final int submittedCount;
  final int gradedCount;

  AssignmentModel({
    required this.id,
    required this.title,
    this.description,
    this.course,
    this.courseName,
    this.studentGroup,
    this.studentGroupName,
    this.instructor,
    this.instructorName,
    this.dueDate,
    this.fromTime,
    this.toTime,
    this.creation,
    this.attachment,
    this.attachmentName,
    this.submitted = false,
    this.grade,
    this.feedback,
    this.submissionStatus,
    this.submissionFile,
    this.submissionFileName,
    this.submittedAt,
    this.totalStudents = 0,
    this.submittedCount = 0,
    this.gradedCount = 0,
  });

  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    // Student submission info (nested under "submission")
    final submission = json['submission'];
    final submissionMap =
        submission is Map<String, dynamic> ? submission : null;

    DateTime? parseDate(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());
    double? parseDouble(dynamic value) => value == null ? null : double.tryParse(value.toString());
    int parseInt(dynamic value) => int.tryParse(value.toString()) ?? 0;

    return AssignmentModel(
      id: (json['name'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description'],
      course: json['course'],
      courseName: json['course_name'],
      studentGroup: json['student_group'] ?? json['class_id'],
      studentGroupName: json['student_group_name'] ?? json['class_name'],
      instructor: json['instructor'],
      instructorName: json['instructor_name'],
      dueDate: parseDate(json['due_date']),
      fromTime: json['from_time'],
      toTime: json['to_time'],
      creation: parseDate(json['creation']),
      attachment: json['attachment'],
      attachmentName: json['attachment_name'],
      submitted: json['submitted'] == true ||
          (submissionMap != null && submissionMap['status'] != 'Returned'),
      grade: parseDouble(submissionMap?['grade'] ?? json['grade']),
      feedback: submissionMap?['feedback'] ?? json['feedback'],
      submissionStatus:
          submissionMap?['status'] ?? json['submission_status'],
      submissionFile: submissionMap?['file'],
      submissionFileName: submissionMap?['file_name'],
        submittedAt: parseDate(submissionMap?['submitted_at']),
        totalStudents: parseInt(json['total_students']),
        submittedCount: parseInt(json['submitted_count']),
        gradedCount: parseInt(json['graded_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': id,
      'title': title,
      'description': description,
      'course': course,
      'student_group': studentGroup,
      'instructor': instructor,
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'attachment': attachment,
    };
  }

  bool get isOverdue {
    // A submission is late only once the due day itself has ended.
    if (dueDate == null) return false;
    final deadline = dueDate!.add(const Duration(days: 1));
    return DateTime.now().isAfter(deadline);
  }

  /// The submission window is closed (deadline passed).
  bool get isPastDeadline => isOverdue;

  int? get daysUntilDue {
    if (dueDate == null) return null;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  bool get isSubmitted => submitted;
  bool get isGraded => grade != null;
  String get displayGrade => grade != null ? grade!.toStringAsFixed(1) : 'Not graded';

  double get submissionRate {
    if (totalStudents <= 0) return 0;
    return submittedCount / totalStudents;
  }
}
