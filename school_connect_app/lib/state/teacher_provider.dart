import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course_schedule_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../models/assignment_model.dart';
import '../models/assignment_submission_model.dart';
import '../services/google_sheets_service.dart';
import 'auth_provider.dart';

class TeacherState {
  final bool isLoading;
  final List<CourseScheduleModel> classes;
  final List<StudentModel> currentClassStudents;
  final List<AttendanceModel> currentAttendance;
  final CourseScheduleModel? selectedClass;
  final String? error;
  final List<AssignmentModel> assignments;
  final List<AssignmentSubmissionModel> submissions;
  final AssignmentModel? selectedAssignment;
  final bool isSubmitting;

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
    );
  }
}

class TeacherNotifier extends StateNotifier<TeacherState> {
  final GoogleSheetsService _apiService;

  TeacherNotifier(this._apiService) : super(TeacherState());

  Future<void> loadClasses() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final classes = await _apiService.getMyClasses();
      state = state.copyWith(isLoading: false, classes: classes);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectClass(CourseScheduleModel courseSchedule) async {
    state = state.copyWith(isLoading: true, selectedClass: courseSchedule, error: null);
    try {
      final students = await _apiService.getClassStudents(courseSchedule.id);
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
      await _apiService.markAttendance(
        courseSchedule: state.selectedClass!.id,
        studentGroup: studentGroup,
        date: date,
        records: records,
      );
      await selectClass(state.selectedClass!);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> loadAssignments() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assignments = await _apiService.getMyTeacherAssignments();
      state = state.copyWith(isLoading: false, assignments: assignments);
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
    List<int>? fileBytes,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _apiService.createAssignment(
        title: title, course: course, studentGroup: studentGroup,
        dueDate: dueDate, description: description, filePath: filePath,
        fileBytes: fileBytes,
      );
      await loadAssignments();
      return true;
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
    List<int>? fileBytes,
    bool clearAttachment = false,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _apiService.updateAssignment(
        assignmentId: assignmentId, title: title, course: course,
        studentGroup: studentGroup, dueDate: dueDate,
        description: description, filePath: filePath,
        fileBytes: fileBytes, clearAttachment: clearAttachment,
      );
      await loadAssignments();
      return true;
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
      await _apiService.deleteAssignment(assignmentId);
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
    state = state.copyWith(isLoading: true, selectedAssignment: assignment, error: null);
    try {
      final submissions = await _apiService.getAssignmentSubmissions(assignment.id);
      state = state.copyWith(isLoading: false, submissions: submissions);
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
      await _apiService.gradeSubmission(submission: submission, grade: grade, feedback: feedback);
      await _reloadAfterMutation();
      return true;
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
      await _apiService.unsubmitSubmission(submission);
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
      await _apiService.deleteSubmission(submission);
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
    if (state.selectedAssignment case final selected?) {
      await loadSubmissions(selected);
    }
    await loadAssignments();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final teacherProvider = StateNotifierProvider<TeacherNotifier, TeacherState>((ref) {
  return TeacherNotifier(ref.watch(sheetsServiceProvider));
});
