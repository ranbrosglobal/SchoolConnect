import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/instructor_model.dart';
import '../models/course_schedule_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../models/assignment_model.dart';
import '../models/assignment_submission_model.dart';
import '../services/demo_api_service.dart';
import '../services/demo_data_service.dart';
import 'auth_provider.dart';

// Teacher state
class TeacherState {
  final bool isLoading;
  final List<CourseScheduleModel> classes;
  final List<StudentModel> currentClassStudents;
  final List<AttendanceModel> currentAttendance;
  final CourseScheduleModel? selectedClass;
  final String? error;

  // Assignments
  final List<AssignmentModel> assignments;
  final List<AssignmentSubmissionModel> submissions;
  final AssignmentModel? selectedAssignment;
  final bool isSubmitting;

  // Teacher profile
  final InstructorModel? teacherProfile;
  final bool isSavingProfile;

  // Attendance history
  final List<AttendanceModel> attendanceHistory;
  final List<DateTime> attendanceDates;
  final DateTime? historyStartDate;
  final DateTime? historyEndDate;

  TeacherState({
    this.isLoading = false,
    this.classes = const [],
    this.currentClassStudents = const [],
    this.currentAttendance = const [],
    this.selectedClass,
    this.error,
    this.assignments = const [],
    this.submissions = const [],
    this.selectedAssignment,
    this.isSubmitting = false,
    this.teacherProfile,
    this.isSavingProfile = false,
    this.attendanceHistory = const [],
    this.attendanceDates = const [],
    this.historyStartDate,
    this.historyEndDate,
  });

  TeacherState copyWith({
    bool? isLoading,
    List<CourseScheduleModel>? classes,
    List<StudentModel>? currentClassStudents,
    List<AttendanceModel>? currentAttendance,
    CourseScheduleModel? selectedClass,
    String? error,
    List<AssignmentModel>? assignments,
    List<AssignmentSubmissionModel>? submissions,
    AssignmentModel? selectedAssignment,
    bool? isSubmitting,
    InstructorModel? teacherProfile,
    bool? isSavingProfile,
    List<AttendanceModel>? attendanceHistory,
    List<DateTime>? attendanceDates,
    DateTime? historyStartDate,
    DateTime? historyEndDate,
  }) {
    return TeacherState(
      isLoading: isLoading ?? this.isLoading,
      classes: classes ?? this.classes,
      currentClassStudents: currentClassStudents ?? this.currentClassStudents,
      currentAttendance: currentAttendance ?? this.currentAttendance,
      selectedClass: selectedClass ?? this.selectedClass,
      error: error,
      assignments: assignments ?? this.assignments,
      submissions: submissions ?? this.submissions,
      selectedAssignment: selectedAssignment ?? this.selectedAssignment,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      teacherProfile: teacherProfile ?? this.teacherProfile,
      isSavingProfile: isSavingProfile ?? this.isSavingProfile,
      attendanceHistory: attendanceHistory ?? this.attendanceHistory,
      attendanceDates: attendanceDates ?? this.attendanceDates,
      historyStartDate: historyStartDate ?? this.historyStartDate,
      historyEndDate: historyEndDate ?? this.historyEndDate,
    );
  }
}

// Teacher notifier
class TeacherNotifier extends StateNotifier<TeacherState> {
  final DemoApiService _apiService;
  final DemoDataService _demoService;
  final bool _isDemoMode;
  final String? _instructorId;

  TeacherNotifier(
    this._apiService,
    this._demoService, {
    bool isDemoMode = false,
    String? instructorId,
  })  : _isDemoMode = isDemoMode,
        _instructorId = instructorId,
        super(TeacherState());

  Future<void> loadClasses() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (_isDemoMode && _instructorId != null) {
        final classes = _demoService.getMyClasses(_instructorId);
        state = state.copyWith(isLoading: false, classes: classes);
      } else {
        final classes = await _apiService.getMyClasses();
        state = state.copyWith(isLoading: false, classes: classes);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectClass(CourseScheduleModel courseSchedule) async {
    state = state.copyWith(
      isLoading: true,
      selectedClass: courseSchedule,
      error: null,
    );

    try {
      if (_isDemoMode) {
        final students = _demoService.getClassStudents(courseSchedule.studentGroup ?? '');
        final attendance = _demoService.allAttendance
            .where((a) => a.courseSchedule == courseSchedule.id)
            .toList();
        
        state = state.copyWith(
          isLoading: false,
          currentClassStudents: students,
          currentAttendance: attendance,
        );
      } else {
        final students = await _apiService.getClassStudents(courseSchedule.id);
        // Always roll-number order (1, 2, 3 …) for roster + attendance.
        students.sort((a, b) {
          final ra = int.tryParse(a.rollNumber ?? '');
          final rb = int.tryParse(b.rollNumber ?? '');
          if (ra != null && rb != null) return ra.compareTo(rb);
          return (a.rollNumber ?? '').compareTo(b.rollNumber ?? '');
        });
        final attendance = await _apiService.getAttendanceReport(
          courseSchedule: courseSchedule.id,
          date: DateTime.now(),
        );

        state = state.copyWith(
          isLoading: false,
          currentClassStudents: students,
          currentAttendance: attendance,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> markAttendance({
    required String studentGroup,
    required DateTime date,
    required List<AttendanceRecord> records,
  }) async {
    if (state.selectedClass == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      if (_isDemoMode) {
        await Future.delayed(const Duration(seconds: 1));
        await selectClass(state.selectedClass!);
        return true;
      } else {
        await _apiService.markAttendance(
          courseSchedule: state.selectedClass!.id,
          studentGroup: studentGroup,
          date: date,
          records: records,
        );

        await selectClass(state.selectedClass!);
        return true;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // Assignment management
  Future<void> loadAssignments() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (_isDemoMode && _instructorId != null) {
        final assignments = _demoService.getMyTeacherAssignments(_instructorId);
        state = state.copyWith(isLoading: false, assignments: assignments);
      } else {
        final assignments = await _apiService.getMyTeacherAssignments();
        state = state.copyWith(isLoading: false, assignments: assignments);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createAssignment({
    required String title,
    required String course,
    required String studentGroup,
    required DateTime dueDate,
    String? description,
    String? filePath,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      if (_isDemoMode) {
        await Future.delayed(const Duration(milliseconds: 800));
        _demoService.createAssignment(
          title: title,
          course: course,
          studentGroup: studentGroup,
          dueDate: dueDate,
          description: description,
          attachment: filePath?.split('/').last,
          attachmentName: filePath?.split('/').last,
          instructorId: _instructorId,
        );
        await loadAssignments();
        return true;
      } else {
        await _apiService.createAssignment(
          title: title,
          course: course,
          studentGroup: studentGroup,
          dueDate: dueDate,
          description: description,
          filePath: filePath,
        );
        await loadAssignments();
        return true;
      }
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<bool> updateAssignment({
    required String assignmentId,
    required String title,
    required String course,
    required String studentGroup,
    required DateTime dueDate,
    String? description,
    String? filePath,
    bool clearAttachment = false,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      if (_isDemoMode) {
        await Future.delayed(const Duration(milliseconds: 800));
        _demoService.updateAssignment(
          assignmentId: assignmentId,
          title: title,
          course: course,
          studentGroup: studentGroup,
          dueDate: dueDate,
          description: description,
          attachment: filePath?.split('/').last,
          attachmentName: filePath?.split('/').last,
          clearAttachment: clearAttachment,
        );
        await loadAssignments();
        return true;
      } else {
        await _apiService.updateAssignment(
          assignmentId: assignmentId,
          title: title,
          course: course,
          studentGroup: studentGroup,
          dueDate: dueDate,
          description: description,
          filePath: filePath,
          clearAttachment: clearAttachment,
        );
        await loadAssignments();
        return true;
      }
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<bool> deleteAssignment(String assignmentId) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      if (_isDemoMode) {
        await Future.delayed(const Duration(milliseconds: 500));
        _demoService.deleteAssignment(assignmentId);
      } else {
        await _apiService.deleteAssignment(assignmentId);
      }
      await loadAssignments();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<void> loadSubmissions(AssignmentModel assignment) async {
    state = state.copyWith(
      isLoading: true,
      selectedAssignment: assignment,
      error: null,
    );

    try {
      if (_isDemoMode) {
        final submissions = _demoService.getAssignmentSubmissions(assignment.id);
        state = state.copyWith(isLoading: false, submissions: submissions);
      } else {
        final submissions = await _apiService.getAssignmentSubmissions(assignment.id);
        state = state.copyWith(isLoading: false, submissions: submissions);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> gradeSubmission({
    required String submission,
    required double grade,
    String? feedback,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      if (_isDemoMode) {
        await Future.delayed(const Duration(milliseconds: 600));
        _demoService.gradeSubmission(
          submission: submission,
          grade: grade,
          feedback: feedback,
        );
        await _reloadAfterMutation();
        return true;
      } else {
        await _apiService.gradeSubmission(
          submission: submission,
          grade: grade,
          feedback: feedback,
        );
        await _reloadAfterMutation();
        return true;
      }
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<bool> unsubmitSubmission(String submission) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      if (_isDemoMode) {
        await Future.delayed(const Duration(milliseconds: 600));
        _demoService.unsubmitSubmission(submission);
      } else {
        await _apiService.unsubmitSubmission(submission);
      }
      await _reloadAfterMutation();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<bool> deleteSubmission(String submission) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      if (_isDemoMode) {
        await Future.delayed(const Duration(milliseconds: 600));
        _demoService.deleteSubmission(submission);
      } else {
        await _apiService.deleteSubmission(submission);
      }
      await _reloadAfterMutation();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<void> _reloadAfterMutation() async {
    // Refresh both the submission list and the assignments list so the
    // dashboard cards and header stats reflect the latest counts.
    if (state.selectedAssignment case final selected?) {
      await loadSubmissions(selected);
    }
    await loadAssignments();
  }

  // Attendance history
  Future<void> loadAttendanceHistory({
    required String courseSchedule,
    required String studentGroup,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (_isDemoMode) {
        final history = _demoService.getAttendanceForCourse(
          courseSchedule: courseSchedule,
          studentGroup: studentGroup,
          startDate: startDate,
          endDate: endDate,
        );
        final dates = _demoService.getAttendanceDates(
          courseSchedule: courseSchedule,
          studentGroup: studentGroup,
          startDate: startDate,
          endDate: endDate,
        );
        state = state.copyWith(
          isLoading: false,
          attendanceHistory: history,
          attendanceDates: dates,
          historyStartDate: startDate,
          historyEndDate: endDate,
        );
      } else {
        // For live backend, load today's attendance as fallback
        final students = await _apiService.getClassStudents(courseSchedule);
        final attendance = await _apiService.getAttendanceReport(
          courseSchedule: courseSchedule,
          date: DateTime.now(),
        );
        state = state.copyWith(
          isLoading: false,
          currentClassStudents: students,
          currentAttendance: attendance,
          historyStartDate: startDate,
          historyEndDate: endDate,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Teacher profile management
  Future<void> loadTeacherProfile() async {
    if (_instructorId == null) return;
    if (_isDemoMode) {
      final profile = _demoService.getTeacherProfile(_instructorId);
      state = state.copyWith(teacherProfile: profile);
    }
  }

  Future<bool> updateTeacherProfile({
    String? name,
    String? email,
    String? phone,
    String? school,
    String? schoolNumber,
    String? address,
  }) async {
    if (_instructorId == null) return false;
    state = state.copyWith(isSavingProfile: true, error: null);

    try {
      if (_isDemoMode) {
        await Future.delayed(const Duration(milliseconds: 600));
        _demoService.updateTeacherProfile(
          instructorId: _instructorId,
          name: name,
          email: email,
          phone: phone,
          school: school,
          schoolNumber: schoolNumber,
          address: address,
        );
        await loadTeacherProfile();
        return true;
      }
      return true;
    } catch (e) {
      state = state.copyWith(isSavingProfile: false, error: e.toString());
      return false;
    } finally {
      state = state.copyWith(isSavingProfile: false);
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider
final teacherProvider = StateNotifierProvider<TeacherNotifier, TeacherState>((ref) {
  final auth = ref.watch(authProvider);
  return TeacherNotifier(
    ref.watch(demoApiServiceProvider),
    ref.watch(demoServiceProvider),
    isDemoMode: auth.isDemoMode,
    instructorId: auth.user?.instructorId,
  );
});
