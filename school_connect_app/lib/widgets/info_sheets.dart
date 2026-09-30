import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Modern bottom sheet listing the user's notifications. The backend does not
/// push notifications yet, so this renders a friendly "all caught up" state —
/// the plumbing is ready for real data when the backend adds it.
Future<void> showNotificationsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      color: Color(0xFF4F46E5), size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _notificationTile(
              Icons.verified_outlined,
              const Color(0xFF16A34A),
              'You\u2019re all caught up!',
              'New announcements from your school will appear here.',
            ),
            const SizedBox(height: 10),
            _notificationTile(
              Icons.schedule_outlined,
              const Color(0xFF2563EB),
              'Timetable updates',
              'Changes made by your school admin show up automatically.',
            ),
            const SizedBox(height: 10),
            _notificationTile(
              Icons.grade_outlined,
              const Color(0xFFEA580C),
              'Grades & attendance',
              'Check the app after each class and assignment review.',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms),
  );
}

Widget _notificationTile(
    IconData icon, Color color, String title, String subtitle) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                      height: 1.35)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Help & support sheet: who to contact plus quick answers.
Future<void> showHelpSupportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.support_agent_outlined,
                      color: Color(0xFF16A34A), size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Help & Support',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _faqTile(
              'How do I mark attendance for a past day?',
              'Open the class, tap Mark Attendance, then use the date bar to '
              'go back to any previous day. Saving updates that day\u2019s records.',
            ),
            _faqTile(
              'Where do I see previous weeks\u2019 attendance?',
              'Open your class and choose Attendance History — you can view '
              'this week, month, quarter, year or any custom range.',
            ),
            _faqTile(
              'Who maintains my timetable?',
              'Your school admin uploads the timetable. You always see the '
              'latest version under Timetable — no editing needed.',
            ),
            _faqTile(
              'I can\u2019t sign in / forgot my password',
              'Use Change Password in Settings, or ask your school admin to '
              'reset your account.',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Still need help?',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          'Reach out to your school admin — they manage '
                          'accounts, classes and the timetable.',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade700,
                              height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms),
  );
}

Widget _faqTile(String question, String answer) {
  return ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    title: Text(question,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
    shape: const Border(),
    collapsedShape: const Border(),
    iconColor: const Color(0xFF1E3A8A),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(answer,
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade700, height: 1.45)),
      ),
    ],
  );
}
