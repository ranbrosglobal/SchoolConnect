import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../state/auth_provider.dart';
import '../../state/student_provider.dart';
import '../../services/export_service.dart' show ExportService;

/// Study Assistant — a context-aware chatbot for students.
///
/// It loads the student's real data (attendance summary + upcoming
/// assignments) and answers questions grounded in that data. It works fully
/// offline once data is loaded; the deterministic response layer can later
/// be replaced or augmented by an LLM backend endpoint
/// (`sc_auth.api.assistant.ask`) without changing this UI.
///
/// The chat can be shared as a text file via the ExportService share flow.
class StudentMessagesTab extends ConsumerStatefulWidget {
  const StudentMessagesTab({super.key});

  @override
  ConsumerState<StudentMessagesTab> createState() => _StudentMessagesTabState();
}

class _StudentMessagesTabState extends ConsumerState<StudentMessagesTab> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _chat = <ChatMessage>[];
  bool _loadingData = true;
  String? _dataError;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    setState(() {
      _chat.clear();
      _loadingData = true;
      _dataError = null;
      _chat.add(ChatMessage(
        role: ChatRole.bot,
        text:
            'Hi there! 👋 I\'m your Study Assistant. Ask me about your '
            'attendance, upcoming assignments, grades, or anything school-related.',
      ));
    });
    try {
      final auth = ref.read(authProvider);
      final userName = auth.user?.fullName.split(' ').first ?? 'Student';

      await ref.read(studentProvider.notifier).loadDashboard();


      final summary = ref.read(studentProvider).attendanceSummary;
      final assignments = ref.read(studentProvider).assignments;

      final pending = assignments.where((a) => a.isSubmitted && !a.isGraded).toList();
      final overdue = assignments.where((a) => a.isOverdue && !a.isSubmitted).toList();
      final dueSoon =
          assignments.where((a) => a.dueDate != null &&
              a.dueDate!.isAfter(DateTime.now()) &&
              a.dueDate!.isBefore(DateTime.now().add(const Duration(days: 7))))
              .toList();
      final graded = assignments.where((a) => a.isGraded).toList();

      final name = auth.user?.fullName ?? userName;
      setState(() {
        _chat.insertAll(1, [
          ChatMessage(
            role: ChatRole.bot,
            text: 'I\'ve loaded your info, $name. Here\'s a quick snapshot:\n'
                '• Attendance: ${summary?.overallPercentage.toStringAsFixed(0) ?? "—"}%\n'
                '• Pending submissions: ${pending.length}\n'
                '• Overdue: ${overdue.length}\n'
                '• Due soon: ${dueSoon.length}\n'
                '• Graded: ${graded.length}\n\n'
                'Try asking "when is my next assignment due?" or "what\'s my attendance?".',
          ),
        ]);
        _loadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dataError = e.toString();
        _loadingData = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loadingData) return;
    _controller.clear();
    setState(() => _chat.add(ChatMessage(role: ChatRole.user, text: text)));
    _scrollToBottom();

    final answer = _generateResponse(text);
    setState(() => _chat.add(ChatMessage(role: ChatRole.bot, text: answer)));
    _scrollToBottom();
  }

  Future<String> _generateResponse(String query) async {
    final lower = query.toLowerCase();
    final summary = ref.read(studentProvider).attendanceSummary;
    final assignments = ref.read(studentProvider).assignments;
    final auth = ref.read(authProvider);
    final name = auth.user?.fullName ?? 'Student';

    // Attendance questions
    if (lower.contains('attendance') || lower.contains('present') || lower.contains('absent')) {
      final pct = summary?.overallPercentage.toStringAsFixed(1) ?? '—';
      final courses = (summary?.courseWisePercentage ?? {}).entries.toList();
      if (courses.isEmpty) {
        return 'Your overall attendance is $pct%. You don\'t have subject-wise attendance data yet. Keep attending your classes to improve it!';
      }
      final courseLines = courses.map((e) => '  • ${e.key}: ${e.value.toStringAsFixed(0)}%').join('\n');
      return 'Your overall attendance is $pct%.\nSubject-wise:\n$courseLines';
    }

    // Assignment / due questions
    if (lower.contains('assignment') || lower.contains('homework') || lower.contains('task') ||
        lower.contains('due') || lower.contains('deadline')) {
      final upcoming = assignments
          .where((a) => a.dueDate != null && a.dueDate!.isAfter(DateTime.now()))
          .toList()
        ..sort((a, b) => (a.dueDate ?? DateTime.now()).compareTo(b.dueDate ?? DateTime.now()));

      if (upcoming.isEmpty) {
        return 'You have no upcoming assignments right now. Great job! 🎉 Check back after your next class for new tasks.';
      }
      final next = upcoming.first;
      final dueStr = next.dueDate != null
          ? DateFormat('EEEE, MMM d, yyyy').format(next.dueDate!)
          : 'No due date set';
      final lines = <String>[];
      lines.add('Your next assignment is:\n');
      lines.add('  📘 ${next.title}');
      lines.add('  Course: ${next.courseName ?? "Unknown"}');
      lines.add('  Class: ${next.studentGroupName ?? "Unknown"}');
      lines.add('  Due: $dueStr');
      if (next.isSubmitted) {
        lines.add('  Status: Submitted ✓');
        if (next.isGraded) {
          lines.add('  Grade: ${next.displayGrade}');
          if (next.feedback != null) {
            lines.add('  Feedback: ${next.feedback}');
          }
        }
      } else {
        lines.add('  Status: Pending');
      }
      if (upcoming.length > 1) {
        lines.add('\nYou also have ${upcoming.length - 1} more assignment(s) due soon.');
      }
      return lines.join('\n');
    }

    // Grade / score questions
    if (lower.contains('grade') || lower.contains('score') || lower.contains('result') ||
        lower.contains('mark') || lower.contains('scored')) {
      final graded = assignments.where((a) => a.isGraded).toList();
      if (graded.isEmpty) {
        return 'No assignments have been graded yet. Once your teacher grades your work, you\'ll see the scores here.';
      }
      final lines = <String>['Here are your graded assignments:'];
      for (final a in graded) {
        lines.add('  • ${a.title} — ${a.displayGrade}');
        if (a.courseName != null) lines.add('    (${a.courseName})');
      }
      final avg = graded.isEmpty
          ? 0.0
          : graded.map((a) => a.grade ?? 0.0).reduce((a, b) => a + b) / graded.length;
      lines.add('\nAverage: ${avg.toStringAsFixed(1)}/100');
      return lines.join('\n');
    }

    // Pending / overdue questions
    if (lower.contains('pending') || lower.contains('overdue') || lower.contains('late') ||
        lower.contains('missed')) {
      final pending = assignments.where((a) => a.isSubmitted && !a.isGraded).toList();
      final overdue = assignments.where((a) => a.isOverdue && !a.isSubmitted).toList();
      if (pending.isEmpty && overdue.isEmpty) {
        return 'You\'re all caught up! No pending or overdue assignments.';
      }
      final lines = <String>[];
      if (pending.isNotEmpty) {
        lines.add('Pending submissions (waiting for grading):');
        for (final a in pending.take(5)) {
          lines.add('  • ${a.title} — ${a.courseName ?? "Unknown"}');
        }
        if (pending.length > 5) lines.add('  ...and ${pending.length - 5} more');
      }
      if (overdue.isNotEmpty) {
        lines.add('\n⚠️ Overdue (past deadline, not submitted):');
        for (final a in overdue.take(5)) {
          lines.add(_overdueLine(a));
        }
      }
      return lines.join('\n');
    }

    // Schedule / timetable questions
    if (lower.contains('schedule') || lower.contains('timetable') || lower.contains('class') ||
        lower.contains('today') || lower.contains('tomorrow')) {
      return await _scheduleResponse();
    }

    // Help / what can you do
    if (lower.contains('help') || lower.contains('what can') || lower.contains('capabilities') ||
        lower.contains('know') || lower.contains('hello') || lower.contains('hi ') ||
        lower == 'hi' || lower == 'hello') {
      return 'Hey $name! Here\'s what I can help with:\n'
          '• "What\'s my attendance?" — your overall + subject-wise attendance\n'
          '• "When is my next assignment due?" — your upcoming homework\n'
          '• "What grades did I get?" — your scored assignments\n'
          '• "What\'s pending or overdue?" — what you still need to do\n'
          '• "Share my progress" — export this chat as a file';
    }

    // Share intent
    if (lower.contains('share') || lower.contains('export') || lower.contains('send')) {
      await _shareChat();
      return 'I\'ve prepared your progress summary for sharing. You can now choose where to save or send it.';
    }

    // Default: be helpful
    return 'I understood you\'re asking about "$query". Try asking about your attendance, upcoming assignments, grades, or what\'s pending. For example: "When is my next assignment due?"';
  }

  Future<String> _scheduleResponse() async {
    try {
      final service = ref.read(apiServiceProvider);
      final timetable = await service.getMyTimetable();
      final weekStart = timetable.weekStart;
      final rows = timetable.timetable;
      if (rows.isEmpty) {
        return 'No classes scheduled for this week. Check back after your teacher adds the timetable.';
      }
      final today = DateTime.now();
      final todayRows = rows.where((r) =>
          r.date.year == today.year &&
          r.date.month == today.month &&
          r.date.day == today.day).toList();
      final lines = <String>[];
      lines.add(_weekRangeLine(timetable, weekStart));
      if (todayRows.isNotEmpty) {
        lines.add('\nToday:');
        for (final r in todayRows) {
          final rt = r.fromTime ?? '';
          final rn = r.courseName ?? 'Class';
          final rtn = r.instructorName ?? 'your teacher';
          final rr = r.room ?? 'Room TBD';
          lines.add('  • $rt – $rn with $rtn in $rr');
        }
      } else {
        lines.add('\nNo classes today.');
      }
      return lines.join('\n');
    } catch (e) {
      return 'I couldn\'t load your timetable right now. Please check the Calendar tab.';
    }
  }

  Future<void> _shareChat() async {
    final text = _chat.map((m) =>
        '${m.role == ChatRole.user ? "You" : "Study Assistant"}: ${m.text}')
        .join('\n\n');
    final header = 'School Connect — Study Assistant Summary\n'
        'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}\n'
        'Student: ${ref.read(authProvider).user?.fullName ?? "Student"}\n'
        'Attendance: ${(ref.read(studentProvider).attendanceSummary?.overallPercentage.toStringAsFixed(0) ?? "—")}%\n'
        'Assignments: ${ref.read(studentProvider).assignments.length}\n'
        '========================================\n\n';
    await ExportService.instance.shareTextFile(header + text, 'study_assistant_summary.txt');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

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
          'Study Assistant',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF1E3A8A)),
            onPressed: _chat.isEmpty ? null : _shareChat,
            tooltip: 'Share this conversation',
          ),
        ],
      ),
      body: _loadingData
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your school data...'),
                ],
              ),
            )
          : _dataError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'Couldn\'t load your data: $_dataError',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadContext,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount: _chat.length,
                        itemBuilder: (context, index) {
                          final msg = _chat[index];
                          return _chatBubble(msg);
                        },
                      ),
                    ),
                    _buildInput(),
                  ],
                ),
    );
  }

  Widget _chatBubble(ChatMessage msg) {
    final isUser = msg.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF5E35B1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF1E1B4B),
            height: 1.4,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  String _overdueLine(AssignmentModel a) {
    final d = a.dueDate;
    return '  • ${a.title} — due ${d != null ? DateFormat('MMM d').format(d) : "?"}';
  }

  String _weekRangeLine(TimetableModel t, DateTime? weekStart) {
    final startDate = weekStart != null
        ? DateFormat('MMM d').format(weekStart)
        : '?';
    final endDate = t.weekEnd != null
        ? DateFormat('MMM d, yyyy').format(t.weekEnd)
        : DateFormat('MMM d, yyyy').format(DateTime.now());
    return 'This week ($startDate – $endDate): ';
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Ask about your schoolwork...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF5E35B1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 22),
              onPressed: _loadingData ? null : _send,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final ChatRole role;
  final String text;
  const ChatMessage({required this.role, required this.text});
}

enum ChatRole { user, bot }
