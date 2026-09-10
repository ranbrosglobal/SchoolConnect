import 'package:flutter/material.dart';

class TeacherGradingScreen extends StatelessWidget {
  const TeacherGradingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
            'Grading',
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
            labelColor: Color(0xFF1976D2),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF1976D2),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            tabs: [
              Tab(text: 'To Grade (12)'),
              Tab(text: 'Graded'),
              Tab(text: 'All'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGradingList(),
            _buildGradingList(),
            _buildGradingList(),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Start Grading',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.edit_note, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradingList() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildStudentItem('Riya Singh', 'Submitted on 18 May', '18/20'),
        _buildStudentItem('Karan Verma', 'Submitted on 18 May', '15/20'),
        _buildStudentItem('Aisha Khan', 'Submitted on 17 May', '17/20'),
        _buildStudentItem('Manav Patel', 'Submitted on 17 May', '16/20'),
        _buildStudentItem('Neha Sharma', 'Submitted on 17 May', '19/20'),
        _buildStudentItem('Arjun Malhotra', 'Submitted on 17 May', '14/20'),
      ],
    );
  }

  Widget _buildStudentItem(String name, String date, String score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFFE3F2FD),
            child: Icon(Icons.person, color: Color(0xFF1976D2)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEB), // Light red bg
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              score,
              style: const TextStyle(
                color: Color(0xFFE53935), // Red text
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
