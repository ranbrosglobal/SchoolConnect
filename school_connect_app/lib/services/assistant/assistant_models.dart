import 'package:flutter/material.dart';

/// What the user is asking for. Classified locally from the utterance plus the
/// conversation so far, so the assistant can pick a *shape* of answer rather
/// than dumping everything it knows.
enum AssistantIntent {
  greeting,
  help,
  attendance,
  timetable,
  assignments,
  dueSoon,
  overdue,
  grades,
  performance,
  studyPlan,
  classSummary,
  roster,
  atRisk,
  submissions,
  schoolInfo,
  thanks,
  unknown,
}

/// Which pipeline produced a reply. Surfaced in the UI so the assistant is
/// honest about how an answer was made.
enum AssistantEngineKind { local, model }

// ─────────────────────────────────────────────────────────────────────────────
// Rich content blocks
// ─────────────────────────────────────────────────────────────────────────────

sealed class AssistantBlock {
  const AssistantBlock();
}

/// A paragraph of prose.
class TextBlock extends AssistantBlock {
  final String text;
  const TextBlock(this.text);
}

/// A bold lead-in followed by supporting prose — used for the answer headline.
class HeadlineBlock extends AssistantBlock {
  final String text;
  final String? caption;
  const HeadlineBlock(this.text, {this.caption});
}

/// Two to four headline numbers in a row.
class MetricsBlock extends AssistantBlock {
  final List<AssistantMetric> metrics;
  const MetricsBlock(this.metrics);
}

class AssistantMetric {
  final String label;
  final String value;
  final String? suffix;
  final AssistantTone tone;
  const AssistantMetric({
    required this.label,
    required this.value,
    this.suffix,
    this.tone = AssistantTone.neutral,
  });
}

/// A progress ring with a caption.
class RingBlock extends AssistantBlock {
  final double percent;
  final String label;
  final String? caption;
  const RingBlock({required this.percent, required this.label, this.caption});
}

/// A titled list (assignments, students, courses...).
class ListBlock extends AssistantBlock {
  final String? title;
  final List<AssistantListItem> items;
  final String? emptyText;
  const ListBlock({this.title, required this.items, this.emptyText});
}

class AssistantListItem {
  final String title;
  final String? subtitle;
  final String? trailing;
  final AssistantTone tone;
  final IconData? icon;
  const AssistantListItem({
    required this.title,
    this.subtitle,
    this.trailing,
    this.tone = AssistantTone.neutral,
    this.icon,
  });
}

/// Horizontal comparison bars, e.g. attendance per subject.
class BarsBlock extends AssistantBlock {
  final String? title;
  final List<AssistantBar> bars;
  const BarsBlock({this.title, required this.bars});
}

class AssistantBar {
  final String label;
  final double value; // 0..100
  final String? valueLabel;
  final AssistantTone tone;
  const AssistantBar({
    required this.label,
    required this.value,
    this.valueLabel,
    this.tone = AssistantTone.neutral,
  });
}

/// Trend line over time.
class TrendBlock extends AssistantBlock {
  final String? title;
  final List<double> values;
  final List<String>? labels;
  final String? caption;
  const TrendBlock({this.title, required this.values, this.labels, this.caption});
}

/// Day-by-day attendance strip.
class HeatBlock extends AssistantBlock {
  final String? title;
  final List<({String label, String status})> days;
  const HeatBlock({this.title, required this.days});
}

/// Follow-up chips attached to the message.
class ActionsBlock extends AssistantBlock {
  final List<AssistantAction> actions;
  const ActionsBlock(this.actions);
}

class AssistantAction {
  /// Label shown on the chip.
  final String label;

  /// Prompt sent when tapped (null = informational only).
  final String? prompt;
  final IconData icon;
  final AssistantTone tone;
  const AssistantAction({
    required this.label,
    this.prompt,
    this.icon = Icons.bolt_rounded,
    this.tone = AssistantTone.accent,
  });
}

enum AssistantTone { neutral, accent, success, warning, danger, info }

Color toneColor(AssistantTone tone) {
  switch (tone) {
    case AssistantTone.accent:
      return const Color(0xFF5B4BE0);
    case AssistantTone.success:
      return const Color(0xFF047857);
    case AssistantTone.warning:
      return const Color(0xFFB45309);
    case AssistantTone.danger:
      return const Color(0xFFBE123C);
    case AssistantTone.info:
      return const Color(0xFF1D4ED8);
    case AssistantTone.neutral:
      return const Color(0xFF5C628C);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Messages
// ─────────────────────────────────────────────────────────────────────────────

enum AssistantAuthor { user, assistant }

class AssistantMessage {
  final String id;
  final AssistantAuthor author;
  final List<AssistantBlock> blocks;

  /// Plain text used for copy/share and the accessibility label.
  final String plainText;
  final DateTime at;
  final AssistantEngineKind engine;
  final AssistantIntent? intent;
  final bool failed;

  /// Chips offered under this answer. Transient — not persisted.
  final List<String> followUps;

  const AssistantMessage({
    required this.id,
    required this.author,
    required this.blocks,
    required this.plainText,
    required this.at,
    this.engine = AssistantEngineKind.local,
    this.intent,
    this.failed = false,
    this.followUps = const [],
  });

  bool get isUser => author == AssistantAuthor.user;

  factory AssistantMessage.user(String text) => AssistantMessage(
        id: 'u-${DateTime.now().microsecondsSinceEpoch}',
        author: AssistantAuthor.user,
        blocks: [TextBlock(text)],
        plainText: text,
        at: DateTime.now(),
      );

  factory AssistantMessage.assistant(
    List<AssistantBlock> blocks, {
    required String plainText,
    AssistantIntent? intent,
    AssistantEngineKind engine = AssistantEngineKind.local,
    List<String> followUps = const [],
  }) =>
      AssistantMessage(
        id: 'a-${DateTime.now().microsecondsSinceEpoch}',
        author: AssistantAuthor.assistant,
        blocks: blocks,
        plainText: plainText,
        at: DateTime.now(),
        intent: intent,
        engine: engine,
        followUps: followUps,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author.name,
        'plainText': plainText,
        'at': at.toIso8601String(),
        'engine': engine.name,
        'intent': intent?.name,
      };

  static AssistantMessage fromJson(Map<String, dynamic> json) => AssistantMessage(
        id: json['id']?.toString() ?? 'm',
        author: json['author'] == 'user' ? AssistantAuthor.user : AssistantAuthor.assistant,
        // Persisted history keeps only the text; rich blocks are rebuilt live
        // from current data when a message is re-asked.
        blocks: [TextBlock(json['plainText']?.toString() ?? '')],
        plainText: json['plainText']?.toString() ?? '',
        at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
        engine: json['engine'] == 'model' ? AssistantEngineKind.model : AssistantEngineKind.local,
        intent: AssistantIntent.values.firstWhere(
          (i) => i.name == json['intent'],
          orElse: () => AssistantIntent.unknown,
        ),
      );
}

/// The engine's answer for one turn.
class AssistantReply {
  final List<AssistantBlock> blocks;
  final List<String> followUps;
  final AssistantIntent intent;
  final String plainText;
  final AssistantEngineKind engine;

  const AssistantReply({
    required this.blocks,
    this.followUps = const [],
    required this.intent,
    required this.plainText,
    this.engine = AssistantEngineKind.local,
  });

  AssistantMessage toMessage() => AssistantMessage.assistant(
        blocks,
        plainText: plainText,
        intent: intent,
        engine: engine,
        followUps: followUps,
      );
}
