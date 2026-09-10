import 'package:flutter/material.dart';
import 'screens/student_dashboard.dart';
import 'screens/teacher_dashboard.dart';
import 'screens/6_login_screen.dart';
import 'screens/signup_step1.dart';
import 'screens/signup_step2.dart';
import 'screens/signup_step3.dart';
import 'screens/signup_step4.dart';
import 'screens/create_assignment.dart';
import 'screens/class_students_roster.dart';
import 'screens/assignment_submissions.dart';
import 'screens/attendance_detail_math.dart';
import 'screens/mark_attendance.dart';
import 'screens/teacher_assignments.dart';
import 'screens/assignments_list.dart';
import 'screens/my_results.dart';
import 'screens/teacher_dashboard_my_classes.dart';
import 'screens/assignment_detail.dart';
import 'screens/student_profile.dart';
import 'screens/student_dashboard_home.dart';
import 'screens/student_timetable.dart';
import 'screens/shared_student_detail.dart';
import 'screens/change_password_modal.dart';
import 'screens/super_admin_portal.dart';
import 'screens/admin/school_admin_dashboard.dart';
import 'screens/teacher/teacher_manage_classes_screen.dart';
import 'screens/teacher/teacher_manage_students_screen.dart';
import 'screens/teacher/teacher_settings_screen.dart';


class AppRoutes {
  static Map<String, WidgetBuilder> get routes => {
    '/SuperAdminPortal': (context) => const SuperAdminPortal(),
    '/SchoolAdminDashboard': (context) => const SchoolAdminDashboard(),
    '/StudentDashboard': (context) => const StudentDashboard(),
    '/TeacherDashboard': (context) => const TeacherDashboard(),
    '/LoginScreen': (context) => const LoginScreen(),
    '/SignupStep1': (context) => const SignupStep1(),
    '/SignupStep2': (context) => const SignupStep2(),
    '/SignupStep3': (context) => const SignupStep3(),
    '/SignupStep4': (context) => const SignupStep4(),
    '/CreateAssignment': (context) => const CreateAssignment(),
    '/ClassStudentsRoster': (context) => const ClassStudentsRoster(),
    '/AssignmentSubmissions': (context) => const AssignmentSubmissions(),
    '/AttendanceDetailMath': (context) => const AttendanceDetailMath(),
    '/MarkAttendance': (context) => const MarkAttendance(),
    '/TeacherAssignments': (context) => const TeacherAssignments(),
    '/AssignmentsList': (context) => const AssignmentsList(),
    '/MyResults': (context) => const MyResults(),
    '/TeacherDashboardMyClasses': (context) => const TeacherDashboardMyClasses(),
    '/AssignmentDetail': (context) => const AssignmentDetail(),
    '/StudentProfile': (context) => const StudentProfile(),
    '/StudentDashboardHome': (context) => const StudentDashboardHome(),
    '/SharedStudentDetail': (context) => const SharedStudentDetail(),
    '/ChangePasswordModal': (context) => const ChangePasswordModal(),
    '/MyTimetable': (context) => const StudentTimetable(),
    '/TeacherManageClasses': (context) => const TeacherManageClassesScreen(),
    '/TeacherManageStudents': (context) => const TeacherManageStudentsScreen(),
    '/TeacherSettings': (context) => const TeacherSettingsScreen(),
  };
}

/// Custom page route with smooth transitions
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SmoothPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: curvedAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        );
}
