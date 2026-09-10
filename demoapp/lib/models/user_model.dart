enum UserRole { superAdmin, admin, schoolAdmin, instructor, student }

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? schoolId;
  final String? schoolName;
  final String? token;
  final String? studentId;
  final List<String> studentGroups;
  final String? instructorId;
  final DateTime? lastPasswordChange;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.schoolId,
    this.schoolName,
    this.token,
    this.studentId,
    this.studentGroups = const [],
    this.instructorId,
    this.lastPasswordChange,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['name'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? json['first_name'] ?? '',
      role: _parseRole(json['role'] ?? json['user_type']),
      schoolId: json['school'],
      schoolName: json['school_name'],
      token: json['token'],
      studentId: json['student_id'],
      studentGroups: (json['student_groups'] as List?)?.cast<String>() ?? const [],
      instructorId: json['instructor_id'],
      lastPasswordChange: json['last_password_change'] != null
          ? DateTime.parse(json['last_password_change'])
          : null,
    );
  }

  static UserRole _parseRole(String? roleStr) {
    if (roleStr == null) return UserRole.student;
    
    switch (roleStr.toLowerCase()) {
      case 'super admin':
        return UserRole.superAdmin;
      case 'system manager':
      case 'administrator':
        return UserRole.admin;
      case 'school admin':
        return UserRole.schoolAdmin;
      case 'instructor':
      case 'teacher':
        return UserRole.instructor;
      case 'student':
        return UserRole.student;
      default:
        return UserRole.student;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'school': schoolId,
      'school_name': schoolName,
      'token': token,
      'student_id': studentId,
      'student_groups': studentGroups,
      'instructor_id': instructorId,
    };
  }

  bool get isAdmin => role == UserRole.admin || role == UserRole.schoolAdmin;
  bool get isInstructor => role == UserRole.instructor;
  bool get isStudent => role == UserRole.student;
  bool get isSuperAdmin => role == UserRole.superAdmin;
}
