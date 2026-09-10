import 'package:flutter/material.dart';

class TeacherMessagesTab extends StatelessWidget {
  const TeacherMessagesTab({super.key});

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
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF1E3A8A)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMessageItem(
                  title: 'Class 9A Group',
                  message: 'Riya: Thank you sir! 💛',
                  time: '10:30 AM',
                  unreadCount: 3,
                  avatarColor: const Color(0xFF1976D2),
                  icon: Icons.group,
                ),
                _buildMessageItem(
                  title: 'Class 10A Group',
                  message: 'Alisha: I have a doubt.',
                  time: 'Yesterday',
                  unreadCount: 2,
                  avatarColor: const Color(0xFFFF9800),
                  icon: Icons.group,
                ),
                _buildMessageItem(
                  title: 'Staff Room',
                  message: 'Meera: Meeting at 3 PM',
                  time: 'Yesterday',
                  unreadCount: 0,
                  avatarColor: const Color(0xFF4CAF50),
                  icon: Icons.work,
                ),
                _buildMessageItem(
                  title: 'Principal',
                  message: 'Please submit report.',
                  time: '12 May',
                  unreadCount: 0,
                  avatarColor: Colors.grey.shade400,
                  icon: Icons.person,
                  isProfilePic: true,
                ),
                _buildMessageItem(
                  title: 'Announcements',
                  message: 'School will remain closed...',
                  time: '12 May',
                  unreadCount: 0,
                  avatarColor: const Color(0xFF9C27B0),
                  icon: Icons.campaign,
                ),
                const SizedBox(height: 32),
                Center(
                  child: Image.asset(
                    'assets/images/message_illustration.png', // Placeholder
                    height: 120,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.mark_email_unread_outlined, size: 50, color: Colors.grey),
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
              color: const Color(0xFF1976D2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.filter_list, color: Color(0xFF1976D2)),
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
            backgroundImage: isProfilePic ? const AssetImage('assets/images/default_avatar.png') : null,
            child: isProfilePic
                ? const Icon(Icons.person, color: Colors.grey)
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
                  color: unreadCount > 0 ? const Color(0xFF1976D2) : Colors.grey.shade500,
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
