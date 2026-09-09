import 'course_schedule_model.dart';

class InstructorModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? school;
  final String? schoolName;
  final String? schoolNumber;
  final String? department;
  final String? designation;
  final String? address;
  final List<CourseScheduleModel> classes;
  final bool isEnabled;

  InstructorModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.school,
    this.schoolName,
    this.schoolNumber,
    this.department,
    this.designation,
    this.address,
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
      schoolNumber: json['school_number'],
      department: json['department'],
      designation: json['designation'],
      address: json['address'],
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
      'school_number': schoolNumber,
      'department': department,
      'designation': designation,
      'address': address,
    };
  }

  InstructorModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? school,
    String? schoolName,
    String? schoolNumber,
    String? department,
    String? designation,
    String? address,
  }) {
    return InstructorModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      school: school ?? this.school,
      schoolName: schoolName ?? this.schoolName,
      schoolNumber: schoolNumber ?? this.schoolNumber,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      address: address ?? this.address,
      classes: classes,
      isEnabled: isEnabled,
    );
  }
}
