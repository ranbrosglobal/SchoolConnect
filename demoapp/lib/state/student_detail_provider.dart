import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student_detail_model.dart';
import 'auth_provider.dart';

/// Identifies which student (and optional class context) to load.
class StudentDetailRequest {
  final String studentId;
  final String? studentGroup;

  const StudentDetailRequest({required this.studentId, this.studentGroup});

  @override
  bool operator ==(Object other) =>
      other is StudentDetailRequest &&
      other.studentId == studentId &&
      other.studentGroup == studentGroup;

  @override
  int get hashCode => Object.hash(studentId, studentGroup);
}

/// Loads a student's profile, roll number, attendance % and grades.
final studentDetailProvider = FutureProvider.autoDispose
    .family<StudentDetailModel, StudentDetailRequest>((ref, request) async {
  final auth = ref.watch(authProvider);
  final api = ref.watch(apiServiceProvider);
  final demo = ref.watch(demoServiceProvider);

  if (auth.isDemoMode) {
    return demo.getStudentDetails(request.studentId, group: request.studentGroup);
  }
  return api.getStudentDetails(
    student: request.studentId,
    studentGroup: request.studentGroup,
  );
});
