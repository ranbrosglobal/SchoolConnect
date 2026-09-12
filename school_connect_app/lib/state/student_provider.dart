import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_model.dart';
import '../models/assignment_model.dart';
import '../services/frappe_api_service.dart';
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
  final FrappeApiService _api;

  StudentNotifier(this._api) : super(StudentState());

  /// Load the student dashboard (attendance summary + assignments).
  /// Retries a few times on transient failure so the first paint has data.
  Future<void> loadDashboard({int attempt = 0}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final summary = await _api.getMyAttendanceSummary();
      final assignments = await _api.getMyAssignments();
      state = state.copyWith(
        isLoading: false,
        attendanceSummary: summary,
        assignments: assignments,
      );
    } catch (e) {
      if (attempt < 2) {
        await loadDashboard(attempt: attempt + 1);
        return;
      }
      state = state.copyWith(isLoading: false, error: _userFacingError(e));
    }
  }

  Future<void> loadAttendanceForCourse(String? course) async {
    state = state.copyWith(isLoading: true, error: null, selectedCourse: course);
    try {
      final attendance = await _api.getMyAttendance(course: course);
      state = state.copyWith(isLoading: false, attendanceRecords: attendance);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _userFacingError(e));
    }
  }

  /// Submit an assignment, with optional file bytes (real upload to Frappe File).
  Future<bool> submitAssignment({
    required String assignment,
    required String fileName,
    List<int>? fileBytes,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.submitAssignment(
        assignment: assignment,
        fileName: fileName,
        fileBytes: fileBytes,
      );
      final assignments = await _api.getMyAssignments();
      state = state.copyWith(isLoading: false, assignments: assignments);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _userFacingError(e));
      return false;
    }
  }

  /// Refetch everything (used by pull-to-refresh).
  Future<void> refresh() async {
    await loadDashboard();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  static String _userFacingError(Object e) {
    final msg = e.toString();
    if (msg.contains('Cannot connect') || msg.contains('SocketException')) {
      return 'Cannot connect to server. Please check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final studentProvider = StateNotifierProvider<StudentNotifier, StudentState>((ref) {
  return StudentNotifier(ref.watch(apiServiceProvider));
});

