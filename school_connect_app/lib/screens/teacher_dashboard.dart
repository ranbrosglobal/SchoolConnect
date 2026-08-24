import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';
import '../widgets/app_shell.dart';
import 'teacher_dashboard_my_classes.dart';
import 'teacher_assignments.dart';
import 'student_profile.dart'; // Teacher profile can reuse student profile shell for now

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _currentIndex = 0;

  static const List<AppDestination> _destinations = [
    AppDestination(
      icon: Icons.class_outlined,
      selectedIcon: Icons.class_rounded,
      label: 'Classes',
    ),
    AppDestination(
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_rounded,
      label: 'Assignments',
    ),
    AppDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  final List<Widget> _tabs = const [
    TeacherDashboardMyClasses(),
    TeacherAssignments(),
    StudentProfile(), // Just a placeholder for profile
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      index: _currentIndex,
      onChanged: (i) => setState(() => _currentIndex = i),
      destinations: _destinations,
      tabs: _tabs,
      accent: AppColors.info,
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/CreateAssignment'),
              backgroundColor: AppColors.info,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Assignment', style: TextStyle(color: Colors.white)),
            ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack)
          : null,
    );
  }
}
