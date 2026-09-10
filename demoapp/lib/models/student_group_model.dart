import 'student_model.dart';

class StudentGroupModel {
  final String id;
  final String name;
  final String? program;
  final String? programName;
  final String? course;
  final String? courseName;
  final String? school;
  final String? schoolName;
  final int? groupSize;
  final bool? active;
  final List<StudentModel> students;

  StudentGroupModel({
    required this.id,
    required this.name,
    this.program,
    this.programName,
    this.course,
    this.courseName,
    this.school,
    this.schoolName,
    this.groupSize,
    this.active,
    this.students = const [],
  });

  factory StudentGroupModel.fromJson(Map<String, dynamic> json) {
    return StudentGroupModel(
      id: json['name'] ?? '',
      name: json['student_group_name'] ?? json['name'] ?? '',
      program: json['program'],
      programName: json['program_name'],
      course: json['course'],
      courseName: json['course_name'],
      school: json['school'],
      schoolName: json['school_name'],
      groupSize: json['group_size'] ?? json['student_count'],
      active: json['active'],
      students: (json['students'] ?? [])
          .map<StudentModel>((s) => StudentModel.fromJson(s))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': id,
      'student_group_name': name,
      'program': program,
      'course': course,
      'school': school,
      'group_size': groupSize,
    };
  }

  String get displayName => name;
}
