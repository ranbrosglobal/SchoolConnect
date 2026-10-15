import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/assistant_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/kit/kit.dart';
import '../assistant/assistant_screen.dart';
import 'teacher_calendar_tab.dart';
import 'teacher_classes_tab.dart';
import 'teacher_home_tab.dart';
import 'teacher_profile_tab.dart';

/// Teacher shell: the same structure as the student app with the teacher's
/// accent — consistent muscle memory across roles, distinct identity.
class TeacherDashboard extends ConsumerStatefulWidget {
  const TeacherDashboard({super.key});

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {
  static const int _aiIndex = 2;
  int _index = 0;

  static const List<AppNavItem> _items = [
    AppNavItem(icon: Icons.space_dashboard_outlined, selectedIcon: Icons.space_dashboard_rounded, label: 'Home', doodle: DoodleKind.home),
    AppNavItem(icon: Icons.class_outlined, selectedIcon: Icons.class_rounded, label: 'Classes', doodle: DoodleKind.classes),
    AppNavItem(icon: Icons.auto_awesome_outlined, selectedIcon: Icons.auto_awesome_rounded, label: 'Ask AI', doodle: DoodleKind.sparkle),
    AppNavItem(icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month_rounded, label: 'Calendar', doodle: DoodleKind.calendar),
    AppNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile', doodle: DoodleKind.profile),
  ];

  List<Widget> get _tabs => [
    TeacherHomeTab(onOpenTab: (i) => setState(() => _index = i)),
    TeacherClassesTab(),
    AssistantScreen(),
    TeacherCalendarTab(),
    TeacherProfileTab(),
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
        role: AppRoleStyle.teacher,
        items: _items,
        aiIndex: _aiIndex,
        aiBusy: thinking,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}
