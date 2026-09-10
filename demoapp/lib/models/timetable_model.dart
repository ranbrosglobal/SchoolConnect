/// Student timetable payload from `sc_auth.api.data.my_timetable`:
/// a week's schedule grid rows plus the student's teachers and subjects.
class TimetableModel {
  final DateTime? weekStart;
  final DateTime? weekEnd;
  final List<ScheduleRow> timetable;
  final List<TeacherInfo> teachers;
  final List<SubjectInfo> subjects;

  const TimetableModel({
    this.weekStart,
    this.weekEnd,
    this.timetable = const [],
    this.teachers = const [],
    this.subjects = const [],
  });

  factory TimetableModel.fromJson(Map<String, dynamic> json) {
    return TimetableModel(
      weekStart: json['week_start'] != null ? DateTime.tryParse(json['week_start'] as String) : null,
      weekEnd: json['week_end'] != null ? DateTime.tryParse(json['week_end'] as String) : null,
      timetable: (json['timetable'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ScheduleRow.fromJson)
          .toList(),
      teachers: (json['teachers'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TeacherInfo.fromJson)
          .toList(),
      subjects: (json['subjects'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubjectInfo.fromJson)
          .toList(),
    );
  }
}

class ScheduleRow {
  final String name;
  final DateTime date;
  final int weekday; // 0 = Monday ... 6 = Sunday
  final String? fromTime;
  final String? toTime;
  final String? course;
  final String courseName;
  final String? room;
  final String? instructorName;
  final String? studentGroupName;

  const ScheduleRow({
    required this.name,
    required this.date,
    required this.weekday,
    this.fromTime,
    this.toTime,
    this.course,
    required this.courseName,
    this.room,
    this.instructorName,
    this.studentGroupName,
  });

  factory ScheduleRow.fromJson(Map<String, dynamic> json) {
    return ScheduleRow(
      name: json['name'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      weekday: (json['weekday'] as num?)?.toInt() ?? 0,
      fromTime: json['from_time'] as String?,
      toTime: json['to_time'] as String?,
      course: json['course'] as String?,
      courseName: json['course_name'] as String? ?? json['course'] as String? ?? 'Class',
      room: json['room'] as String?,
      instructorName: json['instructor_name'] as String? ?? json['instructor'] as String?,
      studentGroupName: json['student_group_name'] as String?,
    );
  }
}

class TeacherInfo {
  final String name;
  final String instructorName;
  final List<CourseRef> courses;

  const TeacherInfo({
    required this.name,
    required this.instructorName,
    this.courses = const [],
  });

  factory TeacherInfo.fromJson(Map<String, dynamic> json) {
    return TeacherInfo(
      name: json['name'] as String? ?? '',
      instructorName: json['instructor_name'] as String? ?? json['name'] as String? ?? 'Teacher',
      courses: (json['courses'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CourseRef.fromJson)
          .toList(),
    );
  }
}

class CourseRef {
  final String course;
  final String courseName;

  const CourseRef({required this.course, required this.courseName});

  factory CourseRef.fromJson(Map<String, dynamic> json) {
    return CourseRef(
      course: json['course'] as String? ?? '',
      courseName: json['course_name'] as String? ?? json['course'] as String? ?? '',
    );
  }
}

class SubjectInfo {
  final String course;
  final String courseName;
  final List<TeacherRef> teachers;

  const SubjectInfo({
    required this.course,
    required this.courseName,
    this.teachers = const [],
  });

  factory SubjectInfo.fromJson(Map<String, dynamic> json) {
    return SubjectInfo(
      course: json['course'] as String? ?? '',
      courseName: json['course_name'] as String? ?? json['course'] as String? ?? '',
      teachers: (json['teachers'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TeacherRef.fromJson)
          .toList(),
    );
  }
}

class TeacherRef {
  final String name;
  final String instructorName;

  const TeacherRef({required this.name, required this.instructorName});

  factory TeacherRef.fromJson(Map<String, dynamic> json) {
    return TeacherRef(
      name: json['name'] as String? ?? '',
      instructorName: json['instructor_name'] as String? ?? json['name'] as String? ?? '',
    );
  }
}
