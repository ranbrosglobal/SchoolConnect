import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_model.dart';
import '../models/assignment_model.dart';
import '../services/google_sheets_service.dart';
import 'auth_provider.dart';

class StudentState {
  final bool isLoading;
  final AttendanceSummary? attendanceSummary;
  final List<AttendanceModel> attendanceRecords;
  final List<AssignmentModel> assignments;
  final String? selectedCourse;
  final String? error;

  StudentState({
    this.isLoading = false,
    this.attendanceSummary,
    this.attendanceRecords = const [],
    this.assignments = const [],
    this.selectedCourse,
    this.error,
  });

  StudentState copyWith({
    bool? isLoading,
    AttendanceSummary? attendanceSummary,
    List<AttendanceModel>? attendanceRecords,
    List<AssignmentModel>? assignments,
    String? selectedCourse,
    String? error,
  }) {
    return StudentState(
      isLoading: isLoading ?? this.isLoading,
      attendanceSummary: attendanceSummary ?? this.attendanceSummary,
      attendanceRecords: attendanceRecords ?? this.attendanceRecords,
      assignments: assignments ?? this.assignments,
      selectedCourse: selectedCourse ?? this.selectedCourse,
      error: error,
    );
  }
}

class StudentNotifier extends StateNotifier<StudentState> {
  final GoogleSheetsService _apiService;

  StudentNotifier(this._apiService) : super(StudentState());

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final summary = await _apiService.getMyAttendanceSummary();
      final assignments = await _apiService.getMyAssignments();
      state = state.copyWith(
        isLoading: false,
        attendanceSummary: summary,
        assignments: assignments,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadAttendanceForCourse(String? course) async {
    state = state.copyWith(isLoading: true, error: null, selectedCourse: course);
    try {
      final attendance = await _apiService.getMyAttendance(course: course);
      state = state.copyWith(isLoading: false, attendanceRecords: attendance);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> submitAssignment({
    required String assignment,
    required String fileName,
    String? fileUrl,
    List<int>? fileBytes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      if (fileBytes != null) {
        await _apiService.submitAssignmentWithFile(
          assignment: assignment, fileName: fileName, fileBytes: fileBytes,
        );
      } else {
        await _apiService.submitAssignment(
          assignment: assignment, fileName: fileName, fileUrl: fileUrl,
        );
      }
      final assignments = await _apiService.getMyAssignments();
      state = state.copyWith(isLoading: false, assignments: assignments);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final studentProvider = StateNotifierProvider<StudentNotifier, StudentState>((ref) {
  return StudentNotifier(ref.watch(sheetsServiceProvider));
});
