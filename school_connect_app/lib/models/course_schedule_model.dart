class CourseScheduleModel {
  final String id;
  final String? course;
  final String? courseName;
  final String? studentGroup;
  final String? studentGroupName;
  final String? instructor;
  final String? instructorName;
  final String? school;
  final DateTime? scheduleDate;
  final String? startTime;
  final String? endTime;
  final String? room;
  final bool? isCompleted;

  CourseScheduleModel({
    required this.id,
    this.course,
    this.courseName,
    this.studentGroup,
    this.studentGroupName,
    this.instructor,
    this.instructorName,
    this.school,
    this.scheduleDate,
    this.startTime,
    this.endTime,
    this.room,
    this.isCompleted,
  });

  factory CourseScheduleModel.fromJson(Map<String, dynamic> json) {
    return CourseScheduleModel(
      id: json['name'] ?? '',
      course: json['course'],
      courseName: json['course_name'],
      studentGroup: json['student_group'],
      studentGroupName: json['student_group_name'],
      instructor: json['instructor'],
      instructorName: json['instructor_name'],
      school: json['school'],
      scheduleDate: json['schedule_date'] != null
          ? DateTime.parse(json['schedule_date'])
          : null,
      startTime: json['from_time'],
      endTime: json['to_time'],
      room: json['room'],
      isCompleted: json['is_completed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': id,
      'course': course,
      'student_group': studentGroup,
      'instructor': instructor,
      'school': school,
      'schedule_date': scheduleDate?.toIso8601String().split('T')[0],
      'from_time': startTime,
      'to_time': endTime,
      'room': room,
    };
  }

  String get displayName => '${courseName ?? "Unknown"} - ${studentGroupName ?? "Unknown"}';
}
