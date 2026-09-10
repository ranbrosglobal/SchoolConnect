import 'package:flutter/material.dart';

class StudentClassesTab extends StatelessWidget {
  const StudentClassesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF1E3A8A)),
          onPressed: () {},
        ),
        title: const Text(
          'My Classes',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.send_outlined, color: Color(0xFF1E3A8A)),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildClassItem(
            className: 'Class 8A',
            subject: 'Mathematics',
            teacher: 'Mr. Arjun Sharma',
            iconColor: const Color(0xFF1976D2),
            bgColor: const Color(0xFFE3F2FD),
          ),
          _buildClassItem(
            className: 'Class 8B',
            subject: 'Science',
            teacher: 'Ms. Neha Verma',
            iconColor: const Color(0xFF4CAF50),
            bgColor: const Color(0xFFE8F5E9),
          ),
          _buildClassItem(
            className: 'Class 9A',
            subject: 'Mathematics',
            teacher: 'Mr. Arjun Sharma',
            iconColor: const Color(0xFF1976D2),
            bgColor: const Color(0xFFE3F2FD),
          ),
          _buildClassItem(
            className: 'Class 9B',
            subject: 'English',
            teacher: 'Ms. Priya Mehta',
            iconColor: const Color(0xFFFF9800),
            bgColor: const Color(0xFFFFF3E0),
          ),
          _buildClassItem(
            className: 'Class 10A',
            subject: 'Mathematics',
            teacher: 'Mr. Rohit Das',
            iconColor: const Color(0xFF9C27B0),
            bgColor: const Color(0xFFF3E5F5),
          ),
          _buildClassItem(
            className: 'Class 10B',
            subject: 'Computer',
            teacher: 'Mr. Karan Malhotra',
            iconColor: const Color(0xFF009688),
            bgColor: const Color(0xFFE0F2F1),
          ),
          const SizedBox(height: 32),
          Center(
            child: Icon(Icons.menu_book_outlined, size: 40, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildClassItem({
    required String className,
    required String subject,
    required String teacher,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bgColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subject,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  teacher,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 26,
              backgroundColor: iconColor.withOpacity(0.1),
              child: Icon(Icons.person, color: iconColor, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}
