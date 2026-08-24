import 'course_schedule_model.dart';

class InstructorModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? school;
  final String? schoolName;
  final String? department;
  final String? designation;
  final List<CourseScheduleModel> classes;
  final bool isEnabled;

  InstructorModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.school,
    this.schoolName,
    this.department,
    this.designation,
    this.classes = const [],
    this.isEnabled = true,
  });

  factory InstructorModel.fromJson(Map<String, dynamic> json) {
    return InstructorModel(
      id: json['name'] ?? '',
      name: json['instructor_name'] ?? json['name'] ?? '',
      email: json['instructor_email'] ?? json['email'],
      phone: json['phone'],
      school: json['school'],
      schoolName: json['school_name'],
      department: json['department'],
      designation: json['designation'],
      classes: (json['classes'] ?? [])
          .map<CourseScheduleModel>((c) => CourseScheduleModel.fromJson(c))
          .toList(),
      isEnabled: json['disabled'] != true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': id,
      'instructor_name': name,
      'instructor_email': email,
      'phone': phone,
      'school': school,
      'department': department,
      'designation': designation,
    };
  }
}
