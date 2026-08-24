import 'package:flutter/material.dart';

class StudentMessagesTab extends StatelessWidget {
  const StudentMessagesTab({super.key});

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
          'Messages',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMessageItem(
                  title: 'Class 8A Group',
                  message: 'Mr. Arjun: Don\'t forget the...',
                  time: '10:30 AM',
                  unreadCount: 3,
                  avatarColor: const Color(0xFF1976D2),
                  icon: Icons.group,
                ),
                _buildMessageItem(
                  title: 'Science Group',
                  message: 'Ms. Neha: PPT for today\'s...',
                  time: 'Yesterday',
                  unreadCount: 2,
                  avatarColor: const Color(0xFF4CAF50),
                  icon: Icons.science,
                ),
                _buildMessageItem(
                  title: 'English Group',
                  message: 'Ms. Priya: Please submit...',
                  time: 'Yesterday',
                  unreadCount: 0,
                  avatarColor: const Color(0xFFE53935),
                  icon: Icons.menu_book,
                ),
                _buildMessageItem(
                  title: 'Mr. Arjun Sharma',
                  message: 'Please complete the worksheet.',
                  time: '18 May',
                  unreadCount: 0,
                  avatarColor: Colors.grey.shade400,
                  icon: Icons.person,
                  isProfilePic: true,
                ),
                _buildMessageItem(
                  title: 'School Announcements',
                  message: 'Annual Sports Day on 25 May!',
                  time: '17 May',
                  unreadCount: 0,
                  avatarColor: const Color(0xFF5E35B1),
                  icon: Icons.campaign,
                ),
                const SizedBox(height: 32),
                Center(
                  child: Image.asset(
                    'assets/images/students_working.png', // Placeholder
                    height: 120,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.people_outline, size: 50, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey),
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF5E35B1), // Purple
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.edit_square, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem({
    required String title,
    required String message,
    required String time,
    required int unreadCount,
    required Color avatarColor,
    required IconData icon,
    bool isProfilePic = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: isProfilePic ? Colors.transparent : avatarColor.withOpacity(0.1),
            child: isProfilePic
                ? CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.blue.shade50,
                    child: const Icon(Icons.person, color: Colors.grey),
                  )
                : Icon(icon, color: avatarColor, size: 24),
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
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: unreadCount > 0 ? const Color(0xFF1E3A8A) : Colors.grey.shade600,
                    fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  color: unreadCount > 0 ? const Color(0xFF5E35B1) : Colors.grey.shade500,
                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 8),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
