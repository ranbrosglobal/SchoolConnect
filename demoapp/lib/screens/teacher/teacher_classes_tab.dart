import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/auth_provider.dart';
import 'teacher_class_detail_screen.dart';

/// Shows the teacher's classes loaded from the local database.
class TeacherClassesTab extends ConsumerStatefulWidget {
  const TeacherClassesTab({super.key});

  @override
  ConsumerState<TeacherClassesTab> createState() => _TeacherClassesTabState();
}

class _TeacherClassesTabState extends ConsumerState<TeacherClassesTab> {
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(demoApiServiceProvider);
      final demoService = ref.read(demoServiceProvider);
      final auth = ref.read(authProvider);
      final groups = await service.getStudentGroups();
      final allStudents = await service.getAllStudents();
      final instructorId = auth.user?.instructorId;

      // Get the teacher's course schedules to map groups to course schedule IDs
      final myClasses = instructorId != null
          ? demoService.getMyClasses(instructorId)
          : <dynamic>[];

      final result = <Map<String, dynamic>>[];
      for (final g in groups) {
        final count = allStudents.where((s) => s.studentGroup == g.id).length;
        // Find a course schedule for this group belonging to this teacher
        String? csId;
        for (final cs in myClasses) {
          if (cs.studentGroup == g.id) {
            csId = cs.id;
            break;
          }
        }
        result.add({
          'id': g.id,
          'name': g.name,
          'program': g.program ?? '',
          'studentCount': count,
          'courseScheduleId': csId,
        });
      }

      if (!mounted) return;
      setState(() {
        _classes = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Classes',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.class_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No classes yet.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _classes.length,
                    itemBuilder: (context, index) {
                      final cls = _classes[index];
                      return _buildClassCard(
                        context,
                        className: cls['name'],
                        subject: cls['program'],
                        studentsCount: cls['studentCount'],
                        courseScheduleId: cls['courseScheduleId'],
                        studentGroupId: cls['id'],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildClassCard(
    BuildContext context, {
    required String className,
    required String subject,
    required int studentsCount,
    String? courseScheduleId,
    String? studentGroupId,
  }) {
    // Pick a color based on the class name hash
    final colors = [
      (Color(0xFF1976D2), Color(0xFFE3F2FD)),
      (Color(0xFF4CAF50), Color(0xFFE8F5E9)),
      (Color(0xFF9C27B0), Color(0xFFF3E5F5)),
      (Color(0xFFFF9800), Color(0xFFFFF3E0)),
      (Color(0xFF00BCD4), Color(0xFFE0F7FA)),
      (Color(0xFFE91E63), Color(0xFFFCE4EC)),
    ];
    final pair = colors[className.hashCode.abs() % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(                        builder: (_) => TeacherClassDetailScreen(
                          className: className,
                          subject: subject,
                          courseScheduleId: courseScheduleId,
                          studentGroupId: studentGroupId,
                        ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: pair.$2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.class_, color: pair.$1, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (subject.isNotEmpty)
                        Text(
                          subject,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        '$studentsCount Students',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
