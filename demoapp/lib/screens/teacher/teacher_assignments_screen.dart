import 'package:flutter/material.dart';

class TeacherAssignmentsScreen extends StatelessWidget {
  const TeacherAssignmentsScreen({super.key});

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
              icon: const Icon(Icons.more_vert, color: Color(0xFF1E3A8A)),
              onPressed: () {},
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Color(0xFF1976D2),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF1976D2),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Active'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAssignmentsList(),
            _buildAssignmentsList(),
            _buildAssignmentsList(),
            _buildAssignmentsList(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: const Color(0xFF1976D2),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildAssignmentsList() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildAssignmentItem(
          title: 'Algebra Basics Worksheet',
          className: 'Class 8A',
          dueDate: '20 May, 2024',
          submitted: 12,
          total: 28,
          status: 'Submitted',
          iconColor: const Color(0xFF1976D2),
        ),
        _buildAssignmentItem(
          title: 'Linear Equations Assignment',
          className: 'Class 9A',
          dueDate: '22 May, 2024',
          submitted: 18,
          total: 30,
          status: 'Submitted',
          iconColor: const Color(0xFFE53935),
        ),
        _buildAssignmentItem(
          title: 'Quiz: Real Numbers',
          className: 'Class 8B',
          dueDate: '25 May, 2024',
          submitted: 0,
          total: 26,
          status: 'Upcoming',
          iconColor: const Color(0xFF4CAF50),
        ),
        _buildAssignmentItem(
          title: 'Chapter 2: Polynomials',
          className: 'Class 10A',
          dueDate: '28 May, 2024',
          submitted: 0,
          total: 32,
          status: 'Upcoming',
          iconColor: const Color(0xFF1976D2),
        ),
        _buildAssignmentItem(
          title: 'Integers Worksheet',
          className: 'Class 8A',
          dueDate: '15 May, 2024',
          submitted: 28,
          total: 28,
          status: 'Submitted',
          iconColor: Colors.grey.shade500,
          isCompleted: true,
        ),
        const SizedBox(height: 80), // Fab spacing
      ],
    );
  }

  Widget _buildAssignmentItem({
    required String title,
    required String className,
    required String dueDate,
    required int submitted,
    required int total,
    required String status,
    required Color iconColor,
    bool isCompleted = false,
  }) {
    final isUpcoming = status == 'Upcoming';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.grey.shade100 : iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle_outline : Icons.description_outlined,
              color: isCompleted ? Colors.grey.shade500 : iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
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
                const SizedBox(height: 4),
                Text(
                  'Due: $dueDate',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUpcoming)
                Text(
                  '$submitted/$total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.grey.shade500 : const Color(0xFF4CAF50),
                  ),
                ),
              if (!isUpcoming) const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isCompleted
                      ? Colors.grey.shade500
                      : isUpcoming
                          ? const Color(0xFF1976D2)
                          : const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
