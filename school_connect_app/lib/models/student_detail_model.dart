class StudentDetailModel {
  final String id;
  final String name;
  final String? email;
  final String? gender;
  final String? school;
  final String? schoolName;
  final String? studentGroup;
  final String? studentGroupName;
  final String? rollNumber;
  final double overallAttendance;
  final Map<String, double> courseWiseAttendance;
  final List<GradeRecord> grades;

  StudentDetailModel({
    required this.id,
    required this.name,
    this.email,
    this.gender,
    this.school,
    this.schoolName,
    this.studentGroup,
    this.studentGroupName,
    this.rollNumber,
    this.overallAttendance = 0,
    this.courseWiseAttendance = const {},
    this.grades = const [],
  });

  factory StudentDetailModel.fromJson(Map<String, dynamic> json) {
    return StudentDetailModel(
      id: json['name'] ?? json['student'] ?? '',
      name: json['student_name'] ?? json['name'] ?? '',
      email: json['student_email_id'],
      gender: json['gender'],
      school: json['school'],
      schoolName: json['school_name'],
      studentGroup: json['student_group'],
      studentGroupName: json['student_group_name'],
      rollNumber: json['roll_number']?.toString() ?? json['group_roll_number']?.toString(),
      overallAttendance: (json['overall_attendance'] ?? 0).toDouble(),
      courseWiseAttendance: Map<String, double>.from(
        (json['course_wise_attendance'] ?? {}).map(
          (key, value) => MapEntry(key.toString(), (value ?? 0).toDouble()),
        ),
      ),
      grades: (json['grades'] ?? [])
          .map<GradeRecord>((g) => GradeRecord.fromJson(g))
          .toList(),
    );
  }
}

class GradeRecord {
  final String assignment;
  final String title;
  final String? courseName;
  final DateTime? dueDate;
  final double? grade;
  final String? feedback;
  final String? status;

  GradeRecord({
    required this.assignment,
    required this.title,
    this.courseName,
    this.dueDate,
    this.grade,
    this.feedback,
    this.status,
  });

  factory GradeRecord.fromJson(Map<String, dynamic> json) {
    return GradeRecord(
      assignment: json['assignment'] ?? '',
      title: json['title'] ?? json['assignment'] ?? '',
      courseName: json['course_name'],
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      grade: json['grade']?.toDouble(),
      feedback: json['feedback'],
      status: json['status'],
    );
  }

  bool get isGraded => grade != null;
  String get displayGrade => grade != null ? grade!.toStringAsFixed(1) : 'Not graded';
}
