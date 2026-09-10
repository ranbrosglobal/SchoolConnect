import 'package:flutter/material.dart';
import 'student_assignment_detail_screen.dart';

class StudentAssignmentsScreen extends StatelessWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
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
            'Assignments',
            style: TextStyle(
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.star_border, color: Color(0xFF1E3A8A)),
              onPressed: () {},
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Color(0xFF5E35B1), // Purple
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF5E35B1),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Submitted'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAssignmentsList(context),
            _buildAssignmentsList(context),
            _buildAssignmentsList(context),
            _buildAssignmentsList(context),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: const Color(0xFF5E35B1),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildAssignmentsList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAssignmentDetailScreen(
              title: 'Linear Equations Assignment',
              className: 'Mathematics • Class 9A',
            )));
          },
          child: _buildAssignmentItem(
            title: 'Algebra Basics Worksheet',
            className: 'Mathematics • Class 8A',
            dueDate: '20 May, 2024',
            status: 'Submitted',
            statusColor: const Color(0xFF4CAF50),
            icon: Icons.menu_book_outlined,
            iconColor: const Color(0xFF1976D2),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAssignmentDetailScreen(
              title: 'Linear Equations Assignment',
              className: 'Mathematics • Class 9A',
            )));
          },
          child: _buildAssignmentItem(
            title: 'Linear Equations Assignment',
            className: 'Mathematics • Class 9A',
            dueDate: '22 May, 2024',
            status: '15/20',
            statusColor: const Color(0xFFE53935),
            isGraded: true,
            icon: Icons.assignment_outlined,
            iconColor: const Color(0xFFE53935),
          ),
        ),
        _buildAssignmentItem(
          title: 'Quiz: Real Numbers',
          className: 'Science • Class 8B',
          dueDate: '25 May, 2024',
          status: 'Upcoming',
          statusColor: const Color(0xFF1976D2),
          icon: Icons.help_outline,
          iconColor: const Color(0xFF1976D2),
          iconSize: 36,
        ),
        _buildAssignmentItem(
          title: 'Chapter 2: Polynomials',
          className: 'Mathematics • Class 10A',
          dueDate: '28 May, 2024',
          status: 'Upcoming',
          statusColor: const Color(0xFF1976D2),
          icon: Icons.book_outlined,
          iconColor: const Color(0xFF5E35B1),
        ),
        const SizedBox(height: 80), // Fab spacing
      ],
    );
  }

  Widget _buildAssignmentItem({
    required String title,
    required String className,
    required String dueDate,
    required String status,
    required Color statusColor,
    bool isGraded = false,
    required IconData icon,
    required Color iconColor,
    double iconSize = 28,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                const SizedBox(height: 4),
                Text(
                  className,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Due: $dueDate',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isGraded) ...[
                        Icon(Icons.check, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              if (isGraded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              Icon(icon, color: iconColor, size: iconSize),
            ],
          ),
        ],
      ),
    );
  }
}
