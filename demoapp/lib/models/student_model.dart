class StudentModel {
  final String id;
  final String name;
  final String? email;
  final String? school;
  final String? schoolName;
  final String? studentGroup;
  final String? studentGroupName;
  final String? program;
  final String? programName;
  final int? age;
  final String? gender;
  final String? city;
  final String? state;
  final String? country;
  final String? rollNumber;
  final bool isEnabled;

  StudentModel({
    required this.id,
    required this.name,
    this.email,
    this.school,
    this.schoolName,
    this.studentGroup,
    this.studentGroupName,
    this.program,
    this.programName,
    this.age,
    this.gender,
    this.city,
    this.state,
    this.country,
    this.rollNumber,
    this.isEnabled = true,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['name'] ?? '',
      name: json['student_name'] ?? json['name'] ?? '',
      email: json['student_email_id'] ?? json['email'],
      school: json['school'],
      schoolName: json['school_name'],
      studentGroup: json['student_group'],
      studentGroupName: json['student_group_name'],
      program: json['program'],
      programName: json['program_name'],
      age: json['age'],
      gender: json['gender'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      rollNumber: json['roll_number']?.toString() ?? json['group_roll_number']?.toString(),
      isEnabled: json['disabled'] != true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': id,
      'student_name': name,
      'student_email_id': email,
      'school': school,
      'student_group': studentGroup,
      'program': program,
      'age': age,
      'gender': gender,
      'city': city,
      'state': state,
      'country': country,
    };
  }
}
