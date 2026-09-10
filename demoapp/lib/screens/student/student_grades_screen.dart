import 'package:flutter/material.dart';

class StudentGradesScreen extends StatelessWidget {
  const StudentGradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E3A8A), size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Grades',
            style: TextStyle(
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFF1E3A8A)),
              onPressed: () {},
            ),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF5E35B1),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF5E35B1),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            tabs: [
              Tab(text: 'Latest'), // Changed from "To Grade" as that doesn't make sense for students
              Tab(text: 'All'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGradesList(),
            _buildGradesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGradesList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF5E35B1), // Purple bg
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5E35B1).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Average',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '85%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: 0.85,
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSubjectGrade(
            subject: 'Mathematics',
            grade: '88%',
            icon: Icons.calculate_outlined,
            iconColor: const Color(0xFF1976D2),
            gradeColor: const Color(0xFF4CAF50), // Green grade text
          ),
          _buildSubjectGrade(
            subject: 'Science',
            grade: '82%',
            icon: Icons.science_outlined,
            iconColor: const Color(0xFF4CAF50),
            gradeColor: const Color(0xFF1976D2),
          ),
          _buildSubjectGrade(
            subject: 'English',
            grade: '90%',
            icon: Icons.menu_book_outlined,
            iconColor: const Color(0xFFE53935),
            gradeColor: const Color(0xFFFF9800),
          ),
          _buildSubjectGrade(
            subject: 'Social Studies',
            grade: '78%',
            icon: Icons.public,
            iconColor: const Color(0xFFFF9800),
            gradeColor: const Color(0xFF9C27B0),
          ),
          _buildSubjectGrade(
            subject: 'Computer',
            grade: '87%',
            icon: Icons.computer,
            iconColor: const Color(0xFF009688),
            gradeColor: const Color(0xFF009688),
          ),
          const SizedBox(height: 24),
          Image.asset(
            'assets/images/student_study.png', // Placeholder
            height: 150,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.local_library_outlined, size: 60, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSubjectGrade({
    required String subject,
    required String grade,
    required IconData icon,
    required Color iconColor,
    required Color gradeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              subject,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
          Text(
            grade,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: gradeColor,
            ),
          ),
        ],
      ),
    );
  }
}
