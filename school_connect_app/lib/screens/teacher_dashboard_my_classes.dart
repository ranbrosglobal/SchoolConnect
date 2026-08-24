import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';
import '../utils/time_format.dart';
import '../state/teacher_provider.dart';
import '../state/auth_provider.dart';
import '../models/course_schedule_model.dart';
import '../widgets/school_header.dart';

class TeacherDashboardMyClasses extends ConsumerStatefulWidget {
  const TeacherDashboardMyClasses({super.key});

  @override
  ConsumerState<TeacherDashboardMyClasses> createState() => _TeacherDashboardMyClassesState();
}

class _TeacherDashboardMyClassesState extends ConsumerState<TeacherDashboardMyClasses> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherProvider.notifier).loadClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherProvider);
    final user = ref.watch(authProvider).user;
    final userName = user?.fullName.split(' ').last ?? 'Teacher';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: state.isLoading && state.classes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildHeader(context, userName),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'My Classes',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        if (state.classes.isEmpty)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text('No classes assigned.'),
                          ))
                        else
                          ...state.classes.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildClassCard(context, c),
                          )),
                        const SizedBox(height: 100),
                      ],
                    ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _classActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.info,
        side: BorderSide(color: AppColors.info.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 40),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String userName) {
    return SliverAppBar(
      expandedHeight: 172.0,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.info,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.info, Color(0xFF005F9E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Good morning,',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.access_time_outlined, color: Colors.white60, size: 16)
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .rotate(duration: 2000.ms, begin: -0.05, end: 0.05),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Prof. $userName',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: Colors.white,
                              fontSize: 26,
                            ),
                          ),
                        ],
                      ),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: Text(userName.isNotEmpty ? userName[0] : 'T', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // School identity (name + logo) — always visible on the dashboard.
                  SchoolHeader(compact: true, textColor: Colors.white, showMotto: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, CourseScheduleModel schedule) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.hairlineBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The class name is the primary navigation cue: big,
                      // bold, no background pill.
                      Text(
                        schedule.studentGroupName ?? 'Unknown Class',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        schedule.courseName ?? 'Unknown Course',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.outline,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 15, color: AppColors.outline),
                          const SizedBox(width: 6),
                          Text('${formatTime12h(schedule.startTime)} - ${formatTime12h(schedule.endTime)}', style: const TextStyle(color: AppColors.outline, fontSize: 12.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairlineBorder),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: _classActionButton(
                    context,
                    icon: Icons.checklist,
                    label: 'Attendance',
                    onPressed: () {
                      ref.read(teacherProvider.notifier).selectClass(schedule).then((_) {
                        Navigator.pushNamed(context, '/MarkAttendance');
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _classActionButton(
                    context,
                    icon: Icons.people_outline,
                    label: 'Students',
                    onPressed: () {
                      ref.read(teacherProvider.notifier).selectClass(schedule).then((_) {
                        Navigator.pushNamed(context, '/ClassStudentsRoster');
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
