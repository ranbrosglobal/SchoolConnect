import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/assistant_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';
import '../assistant/assistant_screen.dart';
import 'student_classes_tab.dart';
import 'student_home_tab.dart';
import 'student_profile_tab.dart';
import 'student_timetable_tab.dart';

/// Student shell: four tabs with the AI copilot as the center destination.
///
/// The assistant sits in the middle of the bar because it is the one thing a
/// student reaches for between screens — it is a destination, not a utility.
class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});

  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  static const int _aiIndex = 2;
  int _index = 0;

  static const List<AppNavItem> _items = [
    AppNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home', doodle: DoodleKind.home),
    AppNavItem(icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: 'Classes', doodle: DoodleKind.classes),
    AppNavItem(icon: Icons.auto_awesome_outlined, selectedIcon: Icons.auto_awesome_rounded, label: 'Ask AI', doodle: DoodleKind.sparkle),
    AppNavItem(icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today_rounded, label: 'Calendar', doodle: DoodleKind.calendar),
    AppNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile', doodle: DoodleKind.profile),
  ];

  static const List<Widget> _tabs = [
    StudentHomeTab(),
    StudentClassesTab(),
    AssistantScreen(),
    StudentTimetableTab(),
    StudentProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final thinking = ref.watch(assistantProvider.select((s) => s.thinking));

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: AppBottomNav(
        index: _index,
        role: AppRoleStyle.student,
        items: _items,
        aiIndex: _aiIndex,
        aiBusy: thinking,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}
