import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/app_shell.dart';
import 'student_dashboard_home.dart';
import 'assignments_list.dart';
import 'my_results.dart';
import 'student_profile.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;

  static const List<AppDestination> _destinations = [
    AppDestination(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      label: 'Dashboard',
    ),
    AppDestination(
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_rounded,
      label: 'Assignments',
    ),
    AppDestination(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics_rounded,
      label: 'Results',
    ),
    AppDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  final List<Widget> _tabs = const [
    StudentDashboardHome(),
    AssignmentsList(),
    MyResults(),
    StudentProfile(),
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      index: _currentIndex,
      onChanged: (i) => setState(() => _currentIndex = i),
      destinations: _destinations,
      tabs: _tabs,
      accent: AppColors.primary,
    );
  }
}
