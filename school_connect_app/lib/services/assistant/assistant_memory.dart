import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'assistant_models.dart';

/// Short-term memory for a conversation.
///
/// This is what lets follow-ups work: after answering "what is my maths
/// attendance?", a bare "what about science?" or "and the homework?" resolves
/// against what was just discussed instead of falling back to a generic reply.
class AssistantConversation {
  AssistantIntent? lastIntent;
  String? lastCourse;
  String? lastAssignmentTitle;
  int turnCount = 0;

  AssistantConversation();

  void remember({
    AssistantIntent? intent,
    String? course,
    String? assignmentTitle,
  }) {
    if (intent != null && intent != AssistantIntent.unknown) {
      lastIntent = intent;
    }
    if (course != null) lastCourse = course;
    if (assignmentTitle != null) lastAssignmentTitle = assignmentTitle;
    turnCount++;
  }

  void reset() {
    lastIntent = null;
    lastCourse = null;
    lastAssignmentTitle = null;
    turnCount = 0;
  }

  /// A human title for this conversation, derived from what was discussed.
  String title() {
    final intent = lastIntent;
    if (intent == null) return 'New conversation';
    return switch (intent) {
      AssistantIntent.attendance => 'Attendance check-in',
      AssistantIntent.timetable => 'Timetable & schedule',
      AssistantIntent.assignments => 'Assignment plan',
      AssistantIntent.dueSoon => 'Deadlines this week',
      AssistantIntent.overdue => 'Catching up on late work',
      AssistantIntent.grades => 'Grades review',
      AssistantIntent.performance => 'Progress review',
      AssistantIntent.studyPlan => 'Study plan',
      AssistantIntent.classSummary => 'Class overview',
      AssistantIntent.roster => 'Class rosters',
      AssistantIntent.atRisk => 'Students needing support',
      AssistantIntent.submissions => 'Grading backlog',
      AssistantIntent.schoolInfo => 'School details',
      AssistantIntent.greeting => 'Hello',
      AssistantIntent.thanks => 'Thanks',
      AssistantIntent.help => 'What I can do',
      AssistantIntent.unknown => 'New conversation',
    };
  }
}

/// Persists recent assistant conversations so they survive app restarts.
///
/// Scoped per user id, so two accounts on one device never see each other's
/// history. Rich blocks are not stored — only text, role and metadata — which
/// keeps the payload small and avoids caching stale numbers.
class AssistantStore {
  static const String _prefix = 'assistant.history.v1.';
  static const int _maxMessages = 60;

  const AssistantStore();

  String _key(String userId) => '$_prefix${userId.isEmpty ? 'anon' : userId}';

  Future<List<AssistantMessage>> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AssistantMessage.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(String userId, List<AssistantMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = messages.length > _maxMessages
          ? messages.sublist(messages.length - _maxMessages)
          : messages;
      await prefs.setString(
        _key(userId),
        jsonEncode(trimmed.map((m) => m.toJson()).toList()),
      );
    } catch (_) {
      // Storage is best-effort: a failure must never break the chat.
    }
  }

  Future<void> clear(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (_) {}
  }
}
