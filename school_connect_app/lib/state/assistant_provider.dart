import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timetable_model.dart';
import '../models/user_model.dart';
import '../services/assistant/assistant_context.dart';
import '../services/assistant/assistant_engine.dart';
import '../services/assistant/assistant_memory.dart';
import '../services/assistant/assistant_models.dart';
import 'auth_provider.dart';
import 'school_provider.dart';
import 'student_provider.dart';
import 'teacher_provider.dart';

class AssistantState {
  final List<AssistantMessage> messages;
  final bool thinking;
  final String? thinkingLabel;
  final bool hydrating;
  final AssistantContext context;

  AssistantState({
    this.messages = const [],
    this.thinking = false,
    this.thinkingLabel,
    this.hydrating = true,
    AssistantContext? context,
  }) : context = context ?? AssistantContext.empty();

  bool get isEmpty => messages.isEmpty;

  AssistantState copyWith({
    List<AssistantMessage>? messages,
    bool? thinking,
    String? thinkingLabel,
    bool clearThinkingLabel = false,
    bool? hydrating,
    AssistantContext? context,
  }) =>
      AssistantState(
        messages: messages ?? this.messages,
        thinking: thinking ?? this.thinking,
        thinkingLabel:
            clearThinkingLabel ? null : (thinkingLabel ?? this.thinkingLabel),
        hydrating: hydrating ?? this.hydrating,
        context: context ?? this.context,
      );
}

/// Bridges the app's live data to the assistant engine and keeps the
/// conversation in state (persisted per user).
class AssistantNotifier extends StateNotifier<AssistantState> {
  AssistantNotifier(this._ref)
      : super(AssistantState(context: _buildContext(_ref))) {
    _hydrate();
  }

  final Ref _ref;
  final AssistantEngine _engine = const AssistantEngine();
  final AssistantStore _store = const AssistantStore();
  final AssistantConversation _memory = AssistantConversation();

  /// Keeps the persona steady across a session: the assistant narrates what it
  /// is doing, the way a real service would while a request is in flight.
  static const List<String> _thinkingLines = [
    'Reading your school data…',
    'Checking the numbers…',
    'Cross-referencing deadlines…',
    'Putting the answer together…',
  ];

  String get _userId => _ref.read(authProvider).user?.id ?? 'anon';

  // ─── Context assembly ───────────────────────────────────────────────────

  static AssistantContext _buildContext(Ref ref) {
    final auth = ref.read(authProvider);
    final user = auth.user;
    final school = ref.read(schoolProvider).profile;
    final student = ref.read(studentProvider);
    final teacher = ref.read(teacherProvider);

    return AssistantContext(
      userName: user?.fullName ?? 'there',
      role: user?.role ?? UserRole.student,
      schoolName: school?.schoolName ?? user?.schoolName,
      classNames: user?.studentGroups ?? const [],
      attendance: student.attendanceSummary,
      assignments: [
        ...student.assignments,
        ...teacher.assignments,
      ],
      classes: teacher.classes,
      now: DateTime.now(),
    );
  }

  /// Refresh the snapshot from the current provider state. Safe to call often.
  void refreshContext({TimetableModel? timetable}) {
    final base = _buildContext(_ref);
    state = state.copyWith(
      context: timetable == null ? base : _withTimetable(base, timetable),
    );
  }

  static AssistantContext _withTimetable(
    AssistantContext base,
    TimetableModel timetable,
  ) =>
      AssistantContext(
        userName: base.userName,
        role: base.role,
        schoolName: base.schoolName,
        classNames: base.classNames,
        attendance: base.attendance,
        assignments: base.assignments,
        timetable: timetable,
        classes: base.classes,
        now: DateTime.now(),
      );

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  Future<void> _hydrate() async {
    final history = await _store.load(_userId);
    final ctx = _buildContext(_ref);

    if (history.isEmpty) {
      final welcome = AssistantMessage.assistant(
        _engine.greeting(ctx),
        plainText: AssistantEngine.plainTextOf(_engine.greeting(ctx)),
        intent: AssistantIntent.greeting,
      );
      state = state.copyWith(
        messages: [welcome],
        hydrating: false,
        context: ctx,
      );
    } else {
      state = state.copyWith(messages: history, hydrating: false, context: ctx);
    }
  }

  /// Called by the chat screen after any data load so answers use fresh rows.
  Future<void> syncData({bool fetchTimetable = false}) async {
    refreshContext();
    if (!fetchTimetable) return;
    try {
      final timetable = await _ref.read(apiServiceProvider).getMyTimetable();
      refreshContext(timetable: timetable);
    } catch (_) {
      // Timetable is optional: the assistant degrades to what it already has.
    }
  }

  List<String> get starterPrompts => _engine.starterPrompts(state.context);

  String get conversationTitle => _memory.title();

  // ─── Conversation ───────────────────────────────────────────────────────

  Future<void> ask(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty || state.thinking) return;

    final userMsg = AssistantMessage.user(query);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      thinking: true,
      thinkingLabel: _thinkingLines.first,
    );

    // Refresh from whatever the app has right now, so a save on another tab is
    // reflected without the user needing to pull to refresh.
    refreshContext();

    await _runThinkingNarration();

    final reply = _engine.respond(
      query: query,
      ctx: state.context,
      memory: _memory,
    );

    final messages = [...state.messages, reply.toMessage()];
    state = state.copyWith(
      messages: messages,
      thinking: false,
      clearThinkingLabel: true,
    );
    await _store.save(_userId, messages);
  }

  /// Cycles a couple of status lines with a short, human-feeling cadence.
  Future<void> _runThinkingNarration() async {
    for (var i = 1; i < _thinkingLines.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 210));
      if (!mounted) return;
      state = state.copyWith(thinkingLabel: _thinkingLines[i]);
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }

  void clear() {
    _memory.reset();
    const AssistantStore().clear(_userId);
    final ctx = _buildContext(_ref);
    final greeting = AssistantMessage.assistant(
      _engine.greeting(ctx),
      plainText: AssistantEngine.plainTextOf(_engine.greeting(ctx)),
      intent: AssistantIntent.greeting,
    );
    state = state.copyWith(messages: [greeting], context: ctx);
  }
}

final assistantProvider =
    StateNotifierProvider<AssistantNotifier, AssistantState>((ref) {
  return AssistantNotifier(ref);
});
