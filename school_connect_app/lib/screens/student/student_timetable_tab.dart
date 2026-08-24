import 'package:flutter/material.dart';

class StudentTimetableTab extends StatelessWidget {
  const StudentTimetableTab({super.key});

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
          'Timetable',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: Color(0xFF1E3A8A)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildTimelineItem(
                    time: '08:00 AM',
                    title: 'Mathematics',
                    subtitle: 'Room 201\nMr. Arjun Sharma',
                    icon: Icons.calculate_outlined,
                    color: const Color(0xFF5E35B1),
                    bgColor: const Color(0xFFEDE7F6),
                    isFirst: true,
                  ),
                  _buildTimelineItem(
                    time: '09:45 AM',
                    title: 'Science',
                    subtitle: 'Room 305\nMs. Neha Verma',
                    icon: Icons.science_outlined,
                    color: const Color(0xFF4CAF50),
                    bgColor: const Color(0xFFE8F5E9),
                  ),
                  _buildTimelineItem(
                    time: '11:30 AM',
                    title: 'English',
                    subtitle: 'Room 103\nMs. Priya Mehta',
                    icon: Icons.menu_book_outlined,
                    color: const Color(0xFFE53935),
                    bgColor: const Color(0xFFFFEBEE),
                  ),
                  _buildTimelineItem(
                    time: '01:00 PM',
                    title: 'Social Studies',
                    subtitle: 'Room 202\nMr. Rohit Das',
                    icon: Icons.public,
                    color: const Color(0xFFFF9800),
                    bgColor: const Color(0xFFFFF3E0),
                  ),
                  _buildTimelineItem(
                    time: '02:15 PM',
                    title: 'Computer',
                    subtitle: 'Lab 1\nMr. Karan Malhotra',
                    icon: Icons.computer,
                    color: const Color(0xFF1976D2),
                    bgColor: const Color(0xFFE3F2FD),
                    isLast: true,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildDateNode('Mon', '20', isSelected: true),
          _buildDateNode('Tue', '21'),
          _buildDateNode('Wed', '22'),
          _buildDateNode('Thu', '23'),
          _buildDateNode('Fri', '24'),
        ],
      ),
    );
  }

  Widget _buildDateNode(String day, String date, {bool isSelected = false}) {
    return Column(
      children: [
        Text(
          day,
          style: TextStyle(
            color: isSelected ? const Color(0xFF5E35B1) : Colors.grey.shade500,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5E35B1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              date,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String time,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              Container(
                width: 2,
                height: 20,
                color: isFirst ? Colors.transparent : Colors.grey.shade300,
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : Colors.grey.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: bgColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
