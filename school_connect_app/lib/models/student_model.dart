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
      // Real id keys first. The backend's student rows carry the primary key in
      // `id` and the human name in `name`; reading `name` first (Frappe's
      // doc-name convention) gave every student an id equal to their display
      // name. Attendance was then saved under an id no roster could read back —
      // "saved, but nothing saved" — and the server now rejects those writes.
      // `name` stays the last resort for payloads that only ship a doc name.
      id: (json['id'] ??
              json['student'] ??
              json['student_id'] ??
              json['name'] ??
              '')
          .toString(),
      name: (json['student_name'] ??
              json['full_name'] ??
              json['name'] ??
              '')
          .toString(),
      email: json['student_email_id'] ?? json['email'],
      school: json['school'] ?? json['school_id'],
      schoolName: json['school_name'],
      studentGroup: json['student_group'] ?? json['class_id'],
      studentGroupName: json['student_group_name'] ?? json['class_name'],
      program: json['program'],
      programName: json['program_name'],
      age: json['age'],
      gender: json['gender'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      rollNumber: json['roll_number']?.toString() ??
          json['group_roll_number']?.toString(),
      isEnabled: json['disabled'] != true && json['status'] != 'Inactive',
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
