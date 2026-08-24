import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_model.dart';
import '../models/assignment_model.dart';
import '../services/demo_api_service.dart';
import '../services/demo_data_service.dart';
import 'auth_provider.dart';

// Student state
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

// Student notifier
class StudentNotifier extends StateNotifier<StudentState> {
  final DemoApiService _apiService;
  final DemoDataService _demoService;
  final bool _isDemoMode;
  final String? _studentId;

  StudentNotifier(
    this._apiService,
    this._demoService, {
    bool isDemoMode = false,
    String? studentId,
  })  : _isDemoMode = isDemoMode,
        _studentId = studentId,
        super(StudentState());

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get _isDisposed => _disposed;

  String? _resolveGroup() {
    if (_studentId == null) return null;
    final student = _demoService.allStudents
        .where((s) => s.id == _studentId)
        .toList();
    if (student.isEmpty) return null;
    return student.first.studentGroup;
  }

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (_isDemoMode && _studentId != null) {
        final group = _resolveGroup() ?? 'GRP-001';
        final summaryData = _demoService.getAttendanceSummary(_studentId);
        final assignments = _demoService.getMyAssignments(group, studentId: _studentId);
        
        final attendanceSummary = AttendanceSummary(
          overallPercentage: summaryData['overall'] ?? 0,
          courseWisePercentage: Map<String, double>.from(
            summaryData..remove('overall'),
          ),
          monthlyAttendance: [],
        );

        if (_isDisposed) return;
        state = state.copyWith(
          isLoading: false,
          attendanceSummary: attendanceSummary,
          assignments: assignments,
        );
      } else {
        final summary = await _apiService.getMyAttendanceSummary();
        final assignments = await _apiService.getMyAssignments();

        if (_isDisposed) return;
        state = state.copyWith(
          isLoading: false,
          attendanceSummary: summary,
          assignments: assignments,
        );
      }
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadAttendanceForCourse(String? course) async {
    state = state.copyWith(isLoading: true, error: null, selectedCourse: course);

    try {
      if (_isDemoMode && _studentId != null) {
        final attendance = _demoService.getStudentAttendance(_studentId);
        if (_isDisposed) return;
        state = state.copyWith(
          isLoading: false,
          attendanceRecords: attendance,
        );
      } else {
        final attendance = await _apiService.getMyAttendance(course: course);
        if (_isDisposed) return;
        state = state.copyWith(
          isLoading: false,
          attendanceRecords: attendance,
        );
      }
    } catch (e) {
      if (_isDisposed) return;
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
      if (_isDemoMode) {
        await Future.delayed(const Duration(seconds: 1));
        _demoService.submitAssignment(
          assignment: assignment,
          filePath: fileName,
          studentId: _studentId,
        );
        final assignments =
            _demoService.getMyAssignments(_resolveGroup() ?? 'GRP-001', studentId: _studentId);
        state = state.copyWith(isLoading: false, assignments: assignments);
        return true;
      } else if (fileBytes != null) {
        await _apiService.submitAssignmentWithFile(
          assignment: assignment,
          fileName: fileName,
          fileBytes: fileBytes,
        );
      } else {
        await _apiService.submitAssignment(
          assignment: assignment,
          fileName: fileName,
          fileUrl: fileUrl,
        );
      }

      final assignments = await _apiService.getMyAssignments();
      if (_isDisposed) return false;
      state = state.copyWith(isLoading: false, assignments: assignments);
      return true;
    } catch (e) {
      if (_isDisposed) return false;
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider
final studentProvider = StateNotifierProvider<StudentNotifier, StudentState>((ref) {
  final auth = ref.watch(authProvider);
  return StudentNotifier(
    ref.watch(demoApiServiceProvider),
    ref.watch(demoServiceProvider),
    isDemoMode: auth.isDemoMode,
    studentId: auth.user?.studentId,
  );
});
