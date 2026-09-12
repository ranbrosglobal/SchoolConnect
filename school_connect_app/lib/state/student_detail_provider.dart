import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student_detail_model.dart';
import 'auth_provider.dart';

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

final studentDetailProvider = FutureProvider.autoDispose
    .family<StudentDetailModel, StudentDetailRequest>((ref, request) async {
  final api = ref.watch(apiServiceProvider);
  return api.getStudentDetail(request.studentId, course: request.studentGroup);
});
