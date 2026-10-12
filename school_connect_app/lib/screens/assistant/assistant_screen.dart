import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../services/assistant/assistant_models.dart';
import '../../services/export_service.dart' show ExportService;
import '../../state/assistant_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/student_provider.dart';
import '../../state/teacher_provider.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../../widgets/assistant/assistant_blocks.dart';
import '../../widgets/kit/kit.dart';

/// The AI copilot.
///
/// One screen serves students and teachers; the engine switches its intents
/// based on the signed-in role. Answers are rendered from typed blocks rather
/// than Markdown so metrics, rings and bars all match the app's design system.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isStudent {
    final role = ref.read(authProvider).user?.role;
    return role == null || role == UserRole.student;
  }

  /// Make sure the assistant has real data before the first question.
  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await _refresh(silent: true);
  }

  Future<void> _refresh({bool silent = false}) async {
    final notifier = ref.read(assistantProvider.notifier);
    try {
      if (_isStudent) {
        final student = ref.read(studentProvider);
        if (student.attendanceSummary == null || student.assignments.isEmpty) {
          await ref.read(studentProvider.notifier).loadDashboard();
        }
        await notifier.syncData(fetchTimetable: true);
      } else {
        final teacher = ref.read(teacherProvider);
        if (teacher.classes.isEmpty) {
          await ref.read(teacherProvider.notifier).loadClasses();
        }
        await notifier.syncData();
      }
    } catch (_) {
      // The assistant still answers from whatever data it already holds.
    }
    if (!silent && mounted) _scrollToBottom();
  }

  void _send([String? preset]) {
    final text = preset ?? _input.text.trim();
    if (text.isEmpty) return;
    if (preset == null) _input.clear();
    _focus.unfocus();
    HapticFeedback.lightImpact();
    ref.read(assistantProvider.notifier).ask(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _shareConversation() async {
    final state = ref.read(assistantProvider);
    if (state.messages.isEmpty) return;
    final header = 'School Connect — AI Assistant\n'
        '${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}\n'
        'Signed in as: ${ref.read(authProvider).user?.fullName ?? 'User'}\n'
        '${'=' * 44}\n\n';
    final body = state.messages
        .map((m) => '${m.isUser ? 'You' : 'Assistant'}: ${m.plainText}')
        .join('\n\n');
    await ExportService.instance
        .shareTextFile(header + body, 'school_connect_ai_summary.txt');
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role;
    final isTeacher = role != null && role != UserRole.student;
    final state = ref.watch(assistantProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _header(isTeacher),
          Expanded(
            child: state.hydrating
                ? const _ChatSkeleton()
                : RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppColors.primary,
                    child: _messageList(state),
                  ),
          ),
          _composer(state),
        ],
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _header(bool isTeacher) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xxl)),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.ai,
          boxShadow: AppShadows.glow(AppColors.primary, strength: 0.30),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -50,
              child: _bloom(200, Colors.white.withValues(alpha: 0.18)),
            ),
            Positioned(
              bottom: -90,
              left: -60,
              child: _bloom(220, AppColors.tertiary.withValues(alpha: 0.30)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 18),
              child: Row(
                children: [
                  const AssistantOrb(size: 34),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isTeacher ? 'Teaching Assistant' : 'Study Assistant',
                          style: AppText.cardTitle.copyWith(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF7DFAC8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Grounded in your live school data',
                                style: AppText.caption.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  HeaderIconButton(
                    icon: Icons.share_outlined,
                    tooltip: 'Share conversation',
                    onTap: _shareConversation,
                  ),
                  const SizedBox(width: 6),
                  HeaderIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Sync data',
                    onTap: _refresh,
                  ),
                  const SizedBox(width: 6),
                  HeaderIconButton(
                    icon: Icons.add_comment_outlined,
                    tooltip: 'New conversation',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ref.read(assistantProvider.notifier).clear();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bloom(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );

  // ─── Messages ────────────────────────────────────────────────────────────

  Widget _messageList(AssistantState state) {
    final showStarters = state.messages.length <= 1 && !state.thinking;
    final items = <Widget>[
      if (!state.context.hasData)
        const _DataNotice(),
      for (final m in state.messages) _bubble(m),
      if (showStarters) _starters(state),
      if (state.thinking) _thinking(state.thinkingLabel),
      const SizedBox(height: 8),
    ];

    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: items,
    );
  }

  Widget _bubble(AssistantMessage m) {
    if (m.isUser) return _userBubble(m);
    return _assistantBubble(m);
  }

  Widget _userBubble(AssistantMessage m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            gradient: AppGradients.brand,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(AppRadius.lg),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: AppShadows.glow(AppColors.primary, strength: 0.24),
          ),
          child: Text(
            m.plainText,
            style: AppText.body.copyWith(
              color: Colors.white,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 240.ms)
        .slideY(begin: 0.12, end: 0, duration: 280.ms, curve: Curves.easeOutCubic);
  }

  Widget _assistantBubble(AssistantMessage m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: AssistantOrb(size: 22),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AssistantBlockView(
                        blocks: m.blocks,
                        accent: AppColors.primary,
                        onAction: _send,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const AiTag(),
                          const Spacer(),
                          _MessageAction(
                            icon: Icons.copy_rounded,
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: m.plainText));
                              _toast('Copied answer');
                            },
                          ),
                          _MessageAction(
                            icon: Icons.ios_share_rounded,
                            onTap: _shareConversation,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (m.followUps.isNotEmpty && _isLast(m))
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in m.followUps.take(3))
                    Pressable(
                      onTap: () => _send(f),
                      borderRadius: AppRadius.brPill,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.brPill,
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded,
                                size: 12, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              f,
                              style: AppText.caption.copyWith(
                                fontSize: 11.5,
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.08, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }

  bool _isLast(AssistantMessage m) {
    final messages = ref.read(assistantProvider).messages;
    return messages.isNotEmpty && messages.last.id == m.id;
  }

  Widget _starters(AssistantState state) {
    final prompts = ref.read(assistantProvider.notifier).starterPrompts;
    return Padding(
      padding: const EdgeInsets.only(left: 30, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TRY ASKING', style: AppText.eyebrow),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in prompts)
                Pressable(
                  onTap: () => _send(p),
                  borderRadius: AppRadius.brPill,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.10),
                          AppColors.tertiary.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: AppRadius.brPill,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                    ),
                    child: Text(
                      p,
                      style: AppText.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thinking(String? label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: AssistantOrb(size: 22, thinking: true),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
              child: Row(
                children: [
                  const TypingDots(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ThinkingStrip(
                      text: label ?? 'Working on it…',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  // ─── Composer ────────────────────────────────────────────────────────────

  Widget _composer(AssistantState state) {
    final busy = state.thinking;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.hairlineBorder)),
        boxShadow: AppShadows.soft(),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppRadius.brLg,
                        border: Border.all(color: AppColors.hairlineBorder),
                      ),
                      child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: AppText.body.copyWith(fontSize: 14, color: AppColors.ink),
                        decoration: InputDecoration(
                          hintText: 'Ask about your schoolwork…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.mic_none_rounded,
                                size: 20, color: AppColors.inkFaint),
                            tooltip: 'Voice input',
                            onPressed: () => _toast('Voice input is coming soon'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Pressable(
                    onTap: () {
                      if (!busy) _send();
                    },
                    borderRadius: AppRadius.brPill,
                    child: AnimatedContainer(
                      duration: AppMotion.base,
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: busy ? null : AppGradients.ai,
                        color: busy ? AppColors.surfaceContainerHigh : null,
                        shape: BoxShape.circle,
                        boxShadow: busy
                            ? null
                            : AppShadows.glow(AppColors.primary, strength: 0.36),
                      ),
                      child: busy
                          ? const Padding(
                              padding: EdgeInsets.all(15),
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : const Icon(Icons.arrow_upward_rounded,
                              color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }
}

class _MessageAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MessageAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brPill,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 15, color: AppColors.inkFaint),
      ),
    );
  }
}

/// Shown when the assistant has no school data to read yet.
class _DataNotice extends StatelessWidget {
  const _DataNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: AppRadius.brMd,
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 16, color: AppColors.warningDark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'I have no school data yet. Pull down to sync, and I will answer '
                'from your real attendance, assignments and grades.',
                style: AppText.caption.copyWith(
                  color: AppColors.warningDark,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatSkeleton extends StatelessWidget {
  const _ChatSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonCard(lines: 2),
        SizedBox(height: 12),
        SkeletonCard(lines: 3),
        SizedBox(height: 12),
        Skeleton(height: 46, radius: AppRadius.lg),
      ],
    );
  }
}
