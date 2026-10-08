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
  /// The date the currently loaded [currentAttendance] belongs to. Attendance
  /// is per-day: a new day starts from an unmarked (default present) roster.
  final DateTime? attendanceDate;
  /// Loading flag for the per-date roster fetch (separate from [isLoading] so
  /// switching dates doesn't blank the whole screen).
  final bool isLoadingAttendance;
  /// Date-range history for the selected class (history browser screen).
  final AttendanceHistory? attendanceHistory;
  /// True when [currentAttendance] came back from the server for the day being
  /// viewed. False means the last read failed or could not see the day's rows.
  final bool attendanceVerified;
  /// Why the last read of the day's records failed. Without this a failed read
  /// looked exactly like "nothing was ever saved for this day".
  final String? attendanceLoadError;
  /// Records the server accepted for the displayed day during this session.
  /// Shown when the confirmation read can't see them yet (legacy date formats,
  /// flaky link) so a successful save is never reported as "nothing saved".
  final List<AttendanceModel> lastSavedRecords;
  /// The day [lastSavedRecords] belongs to.
  final DateTime? lastSavedDate;
  /// True when the day's rows were recovered from the class-wide record list
  /// because the day roster couldn't match them (older timestamped dates).
  final bool attendanceMatchedLegacy;

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
    this.attendanceDate,
    this.isLoadingAttendance = false,
    this.attendanceHistory,
    this.attendanceVerified = false,
    this.attendanceLoadError,
    this.lastSavedRecords = const [],
    this.lastSavedDate,
    this.attendanceMatchedLegacy = false,
  });

  /// Records worth showing as "saved" for [date]: the server's day roster when
  /// it has rows, otherwise what this session just wrote to the server.
  List<AttendanceModel> savedRecordsFor(DateTime? date) {
    final day = date == null
        ? null
        : DateTime(date.year, date.month, date.day);
    final loadedDay = attendanceDate == null
        ? null
        : DateTime(attendanceDate!.year, attendanceDate!.month, attendanceDate!.day);
    // Never hand back another day's rows while a date switch is still loading.
    if (currentAttendance.isNotEmpty &&
        (day == null || loadedDay == null || day == loadedDay)) {
      return currentAttendance;
    }
    if (day == null || lastSavedDate == null) return const [];
    final savedDay = DateTime(
        lastSavedDate!.year, lastSavedDate!.month, lastSavedDate!.day);
    return day == savedDay ? lastSavedRecords : const [];
  }

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
    DateTime? attendanceDate,
    bool? isLoadingAttendance,
    AttendanceHistory? attendanceHistory,
    bool clearAttendanceHistory = false,
    bool? attendanceVerified,
    String? attendanceLoadError,
    List<AttendanceModel>? lastSavedRecords,
    DateTime? lastSavedDate,
    bool? attendanceMatchedLegacy,
    bool clearLastSavedRecords = false,
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
      attendanceDate: attendanceDate ?? this.attendanceDate,
      isLoadingAttendance: isLoadingAttendance ?? this.isLoadingAttendance,
      attendanceHistory: clearAttendanceHistory
          ? null
          : (attendanceHistory ?? this.attendanceHistory),
      attendanceVerified: attendanceVerified ?? this.attendanceVerified,
      attendanceLoadError: attendanceLoadError,
      lastSavedRecords: clearLastSavedRecords
          ? const []
          : (lastSavedRecords ?? this.lastSavedRecords),
      lastSavedDate: clearLastSavedRecords ? null : (lastSavedDate ?? this.lastSavedDate),
      attendanceMatchedLegacy: attendanceMatchedLegacy ?? this.attendanceMatchedLegacy,
    );
  }
}

class TeacherNotifier extends StateNotifier<TeacherState> {
  final GoogleSheetsService _api;

  TeacherNotifier(this._api) : super(TeacherState());

  /// Monotonic token for per-date attendance loads. Guards against the
  /// out-of-order race where a slow load for a previously-viewed date lands
  /// AFTER a newer one and overwrites the UI with stale records.
  int _attendanceRequestSeq = 0;

  Future<void> loadClasses() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final classes = await _api.getMyClasses();
      state = state.copyWith(isLoading: false, classes: classes);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectClass(CourseScheduleModel courseSchedule, {DateTime? date}) async {
    state = state.copyWith(isLoading: true, selectedClass: courseSchedule, error: null);
    try {
      final students = await _api.getClassStudents(courseSchedule.classKey);
      students.sort((a, b) {
        final ra = int.tryParse(a.rollNumber ?? '');
        final rb = int.tryParse(b.rollNumber ?? '');
        if (ra != null && rb != null) return ra.compareTo(rb);
        return (a.rollNumber ?? '').compareTo(b.rollNumber ?? '');
      });
      state = state.copyWith(
        isLoading: false,
        currentClassStudents: students,
        // Start from an empty sheet for the requested day; the per-date loader
        // fills in whatever has already been marked for that date.
        currentAttendance: const [],
        attendanceDate: date,
        // No server answer for this class/day yet — the screen must not treat
        // the empty list below as "nothing is saved".
        attendanceVerified: false,
        attendanceLoadError: null,
        attendanceMatchedLegacy: false,
        clearLastSavedRecords: true,
      );
      // Keep the day the caller asked for. Callers that omit a date get
      // today — never whatever day a previous screen happened to be viewing.
      await loadAttendanceForDate(
        courseSchedule,
        date: date ?? DateTime.now(),
        students: students,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load the already-marked attendance for one specific date. Attendance is
  /// per-day: each new day starts from an unmarked roster, and picking a past
  /// date shows exactly what was recorded then. Students already loaded are
  /// reused so switching dates doesn't refetch the roster.
  Future<void> loadAttendanceForDate(
    CourseScheduleModel courseSchedule, {
    required DateTime date,
    List<StudentModel>? students,
  }) async {
    final requestSeq = ++_attendanceRequestSeq;
    final classKey = courseSchedule.classKey;
    state = state.copyWith(isLoadingAttendance: true, attendanceDate: date, error: null);
    try {
      final roster = students ??
          (state.currentClassStudents.isNotEmpty
              ? state.currentClassStudents
              : await _api.getClassStudents(classKey));
      var attendance = await _api.getClassAttendanceRoster(
        classKey,
        date: date,
        course: courseSchedule.courseName ?? courseSchedule.course,
      );
      // The day roster can't see rows an older build saved with a full ISO
      // timestamp. Recover them from the class-wide record list instead of
      // telling the teacher "nothing saved" for a day they did mark.
      var matchedLegacy = false;
      if (attendance.isEmpty) {
        try {
          final recovered =
              await _api.getClassAttendanceForDayFromRecords(classKey, date: date);
          if (recovered.isNotEmpty) {
            attendance = recovered;
            matchedLegacy = true;
          }
        } catch (_) {
          // Best effort — an empty day is still a valid answer.
        }
      }
      // A newer load started while this one was in flight — discard this
      // result so the screen never shows another day's records.
      if (requestSeq != _attendanceRequestSeq) return;
      state = state.copyWith(
        isLoadingAttendance: false,
        currentClassStudents: roster,
        currentAttendance: attendance,
        attendanceVerified: true,
        attendanceLoadError: null,
        attendanceMatchedLegacy: matchedLegacy,
        // The server confirmed the day, so the local "just saved" copy is no
        // longer needed.
        clearLastSavedRecords: attendance.isNotEmpty,
      );
    } catch (e) {
      if (requestSeq != _attendanceRequestSeq) return;
      // Failed load → no stale data masquerading as the day's records.
      // (copyWith can't clear a list, so build the state explicitly.)
      state = TeacherState(
        isLoading: state.isLoading,
        classes: state.classes,
        currentClassStudents: state.currentClassStudents,
        currentAttendance: const [],
        selectedClass: state.selectedClass,
        error: e.toString(),
        assignments: state.assignments,
        submissions: state.submissions,
        selectedAssignment: state.selectedAssignment,
        isSubmitting: state.isSubmitting,
        attendanceDate: state.attendanceDate,
        isLoadingAttendance: false,
        attendanceHistory: state.attendanceHistory,
        attendanceVerified: false,
        attendanceLoadError: e.toString(),
        lastSavedRecords: state.lastSavedRecords,
        lastSavedDate: state.lastSavedDate,
      );
    }
  }

  /// Fetch attendance history for the selected class over a date range.
  Future<bool> loadAttendanceHistory({
    required CourseScheduleModel courseSchedule,
    required DateTime from,
    required DateTime to,
  }) async {
    state = state.copyWith(isLoading: true, error: null, clearAttendanceHistory: true);
    try {
      final history = await _api.getAttendanceHistory(
        courseSchedule.classKey,
        from: from,
        to: to,
      );
      state = state.copyWith(isLoading: false, attendanceHistory: history);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> markAttendance({
    required String studentGroup,
    required DateTime date,
    required List<AttendanceRecord> records,
  }) async {
    if (state.selectedClass == null) return false;
    final selectedClass = state.selectedClass!;
    // Resolve to one non-empty class key for BOTH the write and the read-back;
    // a mismatch here is what makes a saved register look unsaved.
    final classKey =
        studentGroup.trim().isNotEmpty ? studentGroup.trim() : selectedClass.classKey;
    final dayKey = DateTime(date.year, date.month, date.day);
    final courseName = selectedClass.courseName ?? selectedClass.course;
    final nameById = {for (final s in state.currentClassStudents) s.id: s.name};

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.markAttendance(
        courseSchedule: selectedClass.id,
        studentGroup: classKey,
        date: date,
        records: records,
        courseName: courseName,
      );
      // Remember what the server just accepted. If the confirmation read can't
      // see these rows (legacy date formats, flaky link) the screen still shows
      // the save instead of "nothing saved yet".
      state = state.copyWith(
        lastSavedRecords: [
          for (final r in records)
            AttendanceModel(
              id: 'session-${r.studentId}-$classKey',
              student: r.studentId,
              studentName: nameById[r.studentId],
              studentGroup: classKey,
              courseName: courseName,
              date: dayKey,
              status: r.status,
            ),
        ],
        lastSavedDate: dayKey,
        attendanceLoadError: null,
      );
      // Re-read the day's records from the server so the UI reflects what was
      // actually persisted — not what the client assumed. This is what makes
      // "did it save?" trustworthy: the chips show the saved truth.
      await loadAttendanceForDate(
        selectedClass,
        date: date,
        students: state.currentClassStudents,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Clear every mark for the selected class on [date], then re-read the
  /// (now empty) day from the server.
  Future<bool> clearAttendance({
    required String classId,
    required DateTime date,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.clearAttendance(classId: classId, date: date);
      state = state.copyWith(clearLastSavedRecords: true);
      await loadAttendanceForDate(
        state.selectedClass ?? state.classes.firstWhere(
          (c) => c.classKey == classId,
          orElse: () => state.selectedClass!,
        ),
        date: date,
        students: state.currentClassStudents,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> loadAssignments() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assignments = await _api.getTeacherAssignments();
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
      await _api.createAssignment(
        title: title,
        course: course,
        studentGroup: studentGroup,
        dueDate: dueDate,
        description: description,
        filePath: filePath,
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
      await _api.updateAssignment(
        assignmentId: assignmentId,
        title: title,
        course: course,
        studentGroup: studentGroup,
        dueDate: dueDate,
        description: description,
        filePath: filePath,
        fileBytes: fileBytes,
        clearAttachment: clearAttachment,
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
      await _api.deleteAssignment(assignmentId);
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
      final submissions = await _api.getAssignmentSubmissions(assignment.id);
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
      await _api.gradeSubmission(submission: submission, grade: grade, feedback: feedback);
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
      await _api.unsubmitSubmission(submission);
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
      await _api.deleteSubmission(submission);
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
  return TeacherNotifier(ref.watch(apiServiceProvider));
});
