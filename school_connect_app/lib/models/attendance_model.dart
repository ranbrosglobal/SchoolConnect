enum AttendanceStatus { present, absent, halfDay, leave }

class AttendanceModel {
  final String id;
  final String? student;
  final String? studentName;
  final String? courseSchedule;
  final String? courseName;
  final String? studentGroup;
  final String? studentGroupName;
  final DateTime? date;
  final AttendanceStatus status;
  final String? remarks;

  AttendanceModel({
    required this.id,
    this.student,
    this.studentName,
    this.courseSchedule,
    this.courseName,
    this.studentGroup,
    this.studentGroupName,
    this.date,
    this.status = AttendanceStatus.present,
    this.remarks,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['name'] ?? '',
      student: json['student'],
      studentName: json['student_name'],
      courseSchedule: json['course_schedule'],
      courseName: json['course_name'],
      studentGroup: json['student_group'],
      studentGroupName: json['student_group_name'],
      date: json['student_attendance_date'] != null
          ? DateTime.parse(json['student_attendance_date'])
          : null,
      status: _parseStatus(json['status']),
      remarks: json['remarks'],
    );
  }

  static AttendanceStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      case 'half day':
        return AttendanceStatus.halfDay;
      case 'leave':
        return AttendanceStatus.leave;
      default:
        return AttendanceStatus.present;
    }
  }

  String get statusString {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.leave:
        return 'Leave';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': id,
      'student': student,
      'course_schedule': courseSchedule,
      'student_group': studentGroup,
      'student_attendance_date': date?.toIso8601String().split('T')[0],
      'status': statusString,
      'remarks': remarks,
    };
  }
}
