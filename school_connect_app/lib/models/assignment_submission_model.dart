class AssignmentSubmissionModel {
  final String id;
  final String? assignment;
  final String? assignmentTitle;
  final String? student;
  final String? studentName;
  final String? studentEmailId;
  final String? rollNumber;
  final String? file;
  final String? fileName;
  final DateTime? submittedAt;
  final double? grade;
  final String? feedback;
  final String? status;

  AssignmentSubmissionModel({
    required this.id,
    this.assignment,
    this.assignmentTitle,
    this.student,
    this.studentName,
    this.studentEmailId,
    this.rollNumber,
    this.file,
    this.fileName,
    this.submittedAt,
    this.grade,
    this.feedback,
    this.status,
  });

  factory AssignmentSubmissionModel.fromJson(Map<String, dynamic> json) {
    return AssignmentSubmissionModel(
      id: json['name'] ?? '',
      assignment: json['assignment'],
      assignmentTitle: json['assignment_title'],
      student: json['student'],
      studentName: json['student_name'],
      studentEmailId: json['student_email_id'],
      rollNumber: json['roll_number']?.toString() ?? json['group_roll_number']?.toString(),
      file: json['file'],
      fileName: json['file_name'],
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'])
          : null,
      grade: json['grade']?.toDouble(),
      feedback: json['feedback'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': id,
      'assignment': assignment,
      'student': student,
      'file': file,
      'submitted_at': submittedAt?.toIso8601String(),
      'grade': grade,
      'feedback': feedback,
      'status': status,
    };
  }

  bool get isGraded => grade != null;
  String get displayGrade => grade != null ? grade!.toStringAsFixed(1) : 'Not graded';
}
