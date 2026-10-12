import 'package:flutter/material.dart' show Icons;

import '../../models/assignment_model.dart';
import '../../models/timetable_model.dart';
import 'assistant_context.dart';
import 'assistant_memory.dart';
import 'assistant_models.dart';

/// The reasoning core of the in-app copilot.
///
/// Pipeline for every turn:
///
///  1. **Classify** — score the utterance (+ conversation memory) against the
///     known intents, so a bare "what about maths?" resolves to whatever the
///     previous turn was about.
///  2. **Resolve entities** — pull course names, dates and assignment titles
///     out of the utterance, fuzzy-matching against the user's real data.
///  3. **Retrieve** — select only the rows needed for that intent.
///  4. **Synthesise** — build typed content blocks (metrics, rings, bars,
///     lists, trends) plus a plain-text fallback for sharing.
///
/// It is deliberately data-driven and explainable: every number it states can
/// be traced to a field on [AssistantContext].
class AssistantEngine {
  const AssistantEngine();

  // ══════════════════════════════════════════════════════════════════════════
  // Public API
  // ══════════════════════════════════════════════════════════════════════════

  /// A short, data-aware greeting used when a conversation starts.
  List<AssistantBlock> greeting(AssistantContext ctx) {
    if (ctx.isTeacher) return _teacherGreeting(ctx);
    return _studentGreeting(ctx);
  }

  /// Contextual chips shown before the user types anything.
  List<String> starterPrompts(AssistantContext ctx) {
    if (ctx.isTeacher) {
      return const [
        'How are my classes doing?',
        'What still needs grading?',
        'Which students need help?',
        'Summarise my week',
      ];
    }
    return const [
      "What's my attendance?",
      'What is due this week?',
      'How am I doing overall?',
      'Make me a study plan',
    ];
  }

  AssistantReply respond({
    required String query,
    required AssistantContext ctx,
    required AssistantConversation memory,
  }) {
    final text = query.trim();
    final lower = text.toLowerCase();
    final intent = _classify(lower, ctx, memory);
    final course = _resolveCourse(lower, ctx, memory);
    final day = _resolveDay(lower, ctx);

    final answer = switch (intent) {
      AssistantIntent.greeting => _answerGreeting(ctx),
      AssistantIntent.thanks => _answerThanks(ctx),
      AssistantIntent.help => _answerHelp(ctx),
      AssistantIntent.attendance => _answerAttendance(ctx, course),
      AssistantIntent.timetable => _answerTimetable(ctx, day),
      AssistantIntent.assignments => _answerAssignments(ctx, course),
      AssistantIntent.dueSoon => _answerDueSoon(ctx),
      AssistantIntent.overdue => _answerOverdue(ctx),
      AssistantIntent.grades => _answerGrades(ctx, course),
      AssistantIntent.performance => _answerPerformance(ctx),
      AssistantIntent.studyPlan => _answerStudyPlan(ctx),
      AssistantIntent.classSummary => _answerClassSummary(ctx),
      AssistantIntent.roster => _answerRoster(ctx),
      AssistantIntent.atRisk => _answerAtRisk(ctx),
      AssistantIntent.submissions => _answerSubmissions(ctx),
      AssistantIntent.schoolInfo => _answerSchoolInfo(ctx),
      AssistantIntent.unknown => _answerUnknown(ctx, text),
    };

    memory.remember(
      intent: intent,
      course: course,
      assignmentTitle: answer.assignmentTitle,
    );

    return AssistantReply(
      blocks: answer.blocks,
      followUps: answer.followUps,
      intent: intent,
      plainText: plainTextOf(answer.blocks),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. Intent classification
  // ══════════════════════════════════════════════════════════════════════════

  static const Map<AssistantIntent, List<String>> _keywords = {
    AssistantIntent.greeting: [
      'hi', 'hello', 'hey', 'yo', 'good morning', 'good evening', 'good afternoon',
    ],
    AssistantIntent.thanks: ['thanks', 'thank you', 'thx', 'cheers', 'appreciate'],
    AssistantIntent.help: [
      'help', 'what can you do', 'capabilities', 'what do you know', 'commands',
    ],
    AssistantIntent.attendance: [
      'attendance', 'present', 'absent', 'late', 'bunk', 'attend', 'register',
      'how many days', 'leave record',
    ],
    AssistantIntent.timetable: [
      'timetable', 'schedule', 'class today', 'classes today', 'next class',
      'what class', 'period', 'room', 'tomorrow', 'calendar', 'free period',
    ],
    AssistantIntent.assignments: [
      'assignment', 'homework', 'home work', 'task', 'submission', 'submit',
      'worksheet', 'project', 'due',
    ],
    AssistantIntent.dueSoon: [
      'due this week', 'due soon', 'upcoming', 'this week', 'next week',
      'what is due', "what's due", 'deadline',
    ],
    AssistantIntent.overdue: [
      'overdue', 'late', 'missed', 'behind', 'past due', 'not submitted',
    ],
    AssistantIntent.grades: [
      'grade', 'grades', 'score', 'scores', 'result', 'results', 'marks', 'gpa',
      'percentage', 'report card',
    ],
    AssistantIntent.performance: [
      'how am i doing', 'how am i', 'progress', 'performance', 'overall',
      'improve', 'strength', 'weak', 'weakness', 'better',
    ],
    AssistantIntent.studyPlan: [
      'study plan', 'revise', 'revision', 'prepare', 'study schedule',
      'plan my', 'how should i study', 'study for',
    ],
    AssistantIntent.classSummary: [
      'my classes', 'how are my classes', 'class summary', 'how is my class',
      'summarise my', 'summarize my', 'my week', 'overview', 'my teaching',
    ],
    AssistantIntent.roster: [
      'who is in', 'roster', 'students in', 'list students', 'my students',
      'how many students', 'class list', 'roll',
    ],
    AssistantIntent.atRisk: [
      'at risk', 'need help', 'struggling', 'failing', 'low attendance',
      'need attention', 'falling behind', 'who needs',
    ],
    AssistantIntent.submissions: [
      'need grading', 'needs grading', 'grading', 'to grade', 'ungraded',
      'pending grading', 'backlog', 'not graded', 'marking',
    ],
    AssistantIntent.schoolInfo: [
      'school', 'school name', 'my school', 'which school', 'profile',
    ],
  };

  AssistantIntent _classify(
    String lower,
    AssistantContext ctx,
    AssistantConversation memory,
  ) {
    // A bare follow-up ("and?", "what about that?") inherits the last intent.
    final wordCount = lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final mentionsKeyword = _keywords.entries
        .any((e) => e.value.any((k) => lower.contains(k)));
    final isFollowUp = memory.lastIntent != null &&
        !mentionsKeyword &&
        (wordCount <= 2 || lower == 'and what about that?');
    if (isFollowUp) {
      return memory.lastIntent == AssistantIntent.unknown
          ? AssistantIntent.performance
          : memory.lastIntent!;
    }

    final scores = <AssistantIntent, double>{};
    for (final entry in _keywords.entries) {
      double score = 0;
      for (final kw in entry.value) {
        if (lower.contains(kw)) {
          // Longer phrases are stronger evidence than single words.
          score += kw.contains(' ') ? 3.0 : 1.0;
        }
      }
      if (score > 0) scores[entry.key] = score;
    }

    // Pronouns: "when is it due?" right after an assignment answer.
    if (lower.contains('it') || lower.contains('that') || lower.contains('those')) {
      if (memory.lastIntent != null) {
        scores[memory.lastIntent!] = (scores[memory.lastIntent!] ?? 0) + 1.6;
      }
    }

    // Naming a subject alone should use whatever dimension we last discussed.
    final namedCourse = _resolveCourse(lower, ctx, memory);
    if (namedCourse != null && scores.isEmpty && memory.lastIntent != null) {
      scores[memory.lastIntent!] = 2.0;
    }

    // Domain guard-rails: only offer teacher intents to teachers and
    // student intents to students, so an ambiguous word can't wander.
    for (final intent in scores.keys.toList()) {
      if (_isTeacherIntent(intent) && !ctx.isTeacher) scores.remove(intent);
      if (_isStudentIntent(intent) && ctx.isTeacher) scores.remove(intent);
    }

    if (scores.isEmpty) return AssistantIntent.unknown;
    return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static bool _isTeacherIntent(AssistantIntent i) => const {
        AssistantIntent.classSummary,
        AssistantIntent.roster,
        AssistantIntent.submissions,
      }.contains(i);

  static bool _isStudentIntent(AssistantIntent i) => const {
        AssistantIntent.dueSoon,
        AssistantIntent.overdue,
        AssistantIntent.attendance,
        AssistantIntent.timetable,
        AssistantIntent.studyPlan,
      }.contains(i);

  // ══════════════════════════════════════════════════════════════════════════
  // 2. Entity resolution
  // ══════════════════════════════════════════════════════════════════════════

  String? _resolveCourse(
    String lower,
    AssistantContext ctx,
    AssistantConversation memory,
  ) {
    final candidates = <String>{
      ...ctx.courseAttendance.keys,
      ...ctx.subjects,
      ...ctx.gradeByCourse.keys,
      ...ctx.assignments.map((a) => a.courseName ?? a.course ?? '').where((s) => s.isNotEmpty),
    };
    for (final c in candidates) {
      final cl = c.toLowerCase();
      if (cl.isEmpty) continue;
      // Match full name or any word longer than 3 chars ("maths" → Mathematics).
      if (lower.contains(cl)) return c;
      for (final word in cl.split(RegExp(r'[^a-z]+'))) {
        if (word.length >= 4 && lower.contains(word)) return c;
      }
    }
    // Inherit the subject from the previous turn when nothing is named.
    if (memory.lastCourse != null && candidates.contains(memory.lastCourse)) {
      return memory.lastCourse;
    }
    return null;
  }

  DateTime? _resolveDay(String lower, AssistantContext ctx) {
    final now = ctx.now;
    if (lower.contains('tomorrow')) return now.add(const Duration(days: 1));
    if (lower.contains('yesterday')) return now.subtract(const Duration(days: 1));
    if (lower.contains('today') || lower.contains('tonight')) return now;
    const weekdays = {
      'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
      'friday': 5, 'saturday': 6, 'sunday': 7,
    };
    for (final e in weekdays.entries) {
      if (lower.contains(e.key)) {
        final delta = (e.value - now.weekday + 7) % 7;
        return now.add(Duration(days: delta));
      }
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. Answers — student
  // ══════════════════════════════════════════════════════════════════════════

  List<AssistantBlock> _studentGreeting(AssistantContext ctx) {
    final blocks = <AssistantBlock>[
      HeadlineBlock(
        'Hi ${ctx.firstName} 👋',
        caption: ctx.schoolName == null ? null : '${ctx.schoolName}',
      ),
      TextBlock(
        'I read your live attendance, assignments and timetable, so you can ask '
        'me anything about your schoolwork — no digging through tabs.',
      ),
    ];
    if (ctx.hasData) {
      blocks.add(MetricsBlock([
        AssistantMetric(
          label: 'Attendance',
          value: ctx.overallAttendance.toStringAsFixed(0),
          suffix: '%',
          tone: _attendanceTone(ctx.overallAttendance),
        ),
        AssistantMetric(
          label: 'Due soon',
          value: '${ctx.todoAssignments.length}',
          tone: ctx.todoAssignments.isEmpty ? AssistantTone.success : AssistantTone.warning,
        ),
        AssistantMetric(
          label: 'Avg grade',
          value: ctx.gradedAssignments.isEmpty ? '—' : ctx.averageGrade.toStringAsFixed(1),
        ),
      ]));
    }
    return blocks;
  }

  List<AssistantBlock> _teacherGreeting(AssistantContext ctx) {
    final classes = ctx.classNamesFromClasses.isEmpty
        ? ctx.classes
        : ctx.classes;
    return [
      HeadlineBlock('Hello ${ctx.firstName} 👋', caption: ctx.schoolName),
      TextBlock(
        'I can see your ${classes.length} class${classes.length == 1 ? '' : 'es'}'
        '${ctx.totalStudentsTaught > 0 ? ' and ${ctx.totalStudentsTaught} enrolled students' : ''}. '
        'Ask me what needs attention today.',
      ),
      MetricsBlock([
        AssistantMetric(label: 'Classes', value: '${classes.length}'),
        AssistantMetric(
          label: 'To grade',
          value: '${ctx.assignmentsNeedingGrades.length}',
          tone: ctx.assignmentsNeedingGrades.isEmpty
              ? AssistantTone.success
              : AssistantTone.warning,
        ),
        AssistantMetric(label: 'Assignments', value: '${ctx.assignments.length}'),
      ]),
    ];
  }

  _Answer _answerGreeting(AssistantContext ctx) => _Answer(
        blocks: ctx.isTeacher ? _teacherGreeting(ctx) : _studentGreeting(ctx),
        followUps: ctx.isTeacher
            ? ['What still needs grading?', 'How are my classes doing?']
            : ["What's my attendance?", 'What is due this week?'],
      );

  _Answer _answerThanks(AssistantContext ctx) => _Answer(
        blocks: [
          TextBlock(
            ctx.isTeacher
                ? 'Anytime. I will keep an eye on submissions and ping you when something stacks up.'
                : 'Anytime. Keep chipping away — small steps every day add up.',
          ),
        ],
        followUps: ctx.isTeacher
            ? ['Summarise my week', 'Which students need help?']
            : ['Make me a study plan', 'How am I doing overall?'],
      );

  _Answer _answerHelp(AssistantContext ctx) {
    final items = ctx.isTeacher
        ? const [
            ('Grading backlog', 'Which assignments still need grades?'),
            ('Class health', 'How are my classes doing?'),
            ('Student support', 'Which students need help?'),
            ('Weekly summary', 'Summarise my week'),
          ]
        : const [
            ('Attendance', "What's my attendance?"),
            ('Due soon', 'What is due this week?'),
            ('Grades', 'How are my grades?'),
            ('Study plan', 'Make me a study plan'),
          ];
    return _Answer(
      blocks: [
        const TextBlock('Here is what I am best at:'),
        ListBlock(
          items: [
            for (final i in items)
              AssistantListItem(
                title: i.$1,
                subtitle: '"${i.$2}"',
                icon: Icons.bolt_rounded,
                tone: AssistantTone.accent,
              ),
          ],
        ),
        TextBlock('You can also just name a subject, like "maths".'),
      ],
      followUps: [for (final i in items) i.$2],
    );
  }

  _Answer _answerAttendance(AssistantContext ctx, String? course) {
    final summary = ctx.attendance;
    if (summary == null || summary.overallPercentage <= 0 && ctx.courseAttendance.isEmpty) {
      return _Answer(
        blocks: [
          HeadlineBlock('No attendance on record yet', caption: ctx.firstName),
          const TextBlock(
            'Once your teachers start marking registers, I will show your overall '
            'and subject-wise attendance right here.',
          ),
        ],
        followUps: ['What is due this week?', 'Show my timetable'],
      );
    }

    final pct = ctx.overallAttendance;
    final blocks = <AssistantBlock>[];

    if (course != null && ctx.courseAttendance.containsKey(course)) {
      final value = ctx.courseAttendance[course]!;
      blocks.add(HeadlineBlock('$course: ${value.toStringAsFixed(1)}%', caption: 'Attendance'));
      blocks.add(RingBlock(percent: value, label: course));
      blocks.add(TextBlock(_attendanceVerdict(value, course)));
    } else {
      blocks.add(HeadlineBlock(
        'You are at ${pct.toStringAsFixed(1)}% overall',
        caption: '${ctx.attendanceCounts.present} present · '
            '${ctx.attendanceCounts.absent} absent · ${ctx.attendanceCounts.leave} leave',
      ));
      blocks.add(MetricsBlock([
        AssistantMetric(
          label: 'Present',
          value: '${ctx.attendanceCounts.present}',
          tone: AssistantTone.success,
        ),
        AssistantMetric(
          label: 'Absent',
          value: '${ctx.attendanceCounts.absent}',
          tone: ctx.attendanceCounts.absent > 0 ? AssistantTone.danger : AssistantTone.neutral,
        ),
        AssistantMetric(label: 'Leave', value: '${ctx.attendanceCounts.leave}'),
      ]));
      final trend = ctx.attendanceTrend;
      if (trend.length >= 2) {
        blocks.add(TrendBlock(
          title: 'Attendance by week',
          values: trend,
          caption: _trendCaption(trend),
        ));
      }
    }

    if (ctx.courseAttendance.isNotEmpty) {
      final entries = ctx.courseAttendance.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      blocks.add(BarsBlock(
        title: 'By subject — weakest first',
        bars: [
          for (final e in entries)
            AssistantBar(
              label: e.key,
              value: e.value,
              valueLabel: '${e.value.toStringAsFixed(0)}%',
              tone: _attendanceTone(e.value),
            ),
        ],
      ));
      final low = ctx.coursesBelow(75);
      if (low.isNotEmpty) {
        blocks.add(TextBlock(
          'Heads up: ${low.map((e) => e.key).join(', ')} '
          '${low.length == 1 ? 'is' : 'are'} below the 75% mark. '
          'Attending the next few sessions in ${low.first.key} moves that the most.',
        ));
      }
    }

    final recent = ctx.recentDays(days: 10);
    if (recent.isNotEmpty) {
      blocks.add(HeatBlock(
        title: 'Recent days',
        days: [for (final d in recent) (label: d.label, status: d.status)],
      ));
    }

    return _Answer(
      blocks: blocks,
      followUps: [
        if (ctx.weakestCourses.isNotEmpty)
          'Why is ${ctx.weakestCourses.first.key} low?',
        'What is due this week?',
        'Make me a study plan',
      ],
    );
  }

  String _attendanceVerdict(double pct, String course) {
    if (pct >= 90) return '$course attendance is strong — keep the streak going.';
    if (pct >= 75) {
      return 'You are safely above the 75% requirement in $course, but there is not much slack.';
    }
    return 'That is below the usual 75% requirement in $course. Attending the next few classes is the fastest fix.';
  }

  String _trendCaption(List<double> trend) {
    if (trend.length < 2) return '';
    final first = trend.first;
    final last = trend.last;
    final delta = last - first;
    if (delta.abs() < 3) return 'Holding steady week to week.';
    return delta > 0
        ? 'Trending up — ${delta.toStringAsFixed(0)} points since the first week shown.'
        : 'Slipping a little — ${delta.abs().toStringAsFixed(0)} points down since the first week shown.';
  }

  _Answer _answerTimetable(AssistantContext ctx, DateTime? day) {
    if (ctx.timetable == null) {
      return _Answer(
        blocks: [
          const TextBlock(
            'I could not load a timetable for you yet. Once your classes are scheduled '
            'I will list them here with rooms and teachers.',
          ),
        ],
        followUps: ['What is due this week?'],
      );
    }

    final target = day ?? ctx.now;
    final isToday = _sameDay(target, ctx.now);
    final rows = isToday ? ctx.classesToday : _rowsForDay(ctx, target);
    final label = isToday
        ? 'Today'
        : '${_weekdayName(target.weekday)} ${target.day}/${target.month}';

    if (rows.isEmpty) {
      return _Answer(
        blocks: [
          HeadlineBlock('No classes $label', caption: 'Enjoy the gap'),
          TextBlock(
            isToday && ctx.timetable?.timetable.isNotEmpty == true
                ? 'Nothing scheduled for today — a good window for revision.'
                : 'Nothing on the timetable for that day.',
          ),
        ],
        followUps: ['What is due this week?', 'Make me a study plan'],
      );
    }

    final blocks = <AssistantBlock>[
      HeadlineBlock(
        '$label — ${rows.length} class${rows.length == 1 ? '' : 'es'}',
        caption: ctx.timetable!.weekStart != null
            ? 'Week of ${_shortDate(ctx.timetable!.weekStart!)}'
            : null,
      ),
    ];

    if (isToday) {
      final next = ctx.nextClass;
      final mins = ctx.minutesToNextClass;
      if (next != null && mins != null) {
        blocks.add(MetricsBlock([
          AssistantMetric(
            label: 'Next class',
            value: next.courseName,
            tone: AssistantTone.accent,
          ),
          AssistantMetric(
            label: 'Starts in',
            value: mins <= 0 ? 'now' : '$mins',
            suffix: mins <= 0 ? '' : ' min',
            tone: mins <= 15 ? AssistantTone.warning : AssistantTone.neutral,
          ),
          AssistantMetric(label: 'Room', value: next.room ?? '—'),
        ]));
      }
    }

    blocks.add(ListBlock(
      items: [
        for (final r in rows)
          AssistantListItem(
            title: r.courseName,
            subtitle: [
              if (r.fromTime != null) '${r.fromTime}${r.toTime != null ? '–${r.toTime}' : ''}',
              if (r.instructorName != null) r.instructorName!,
              if (r.room != null) 'Room ${r.room}',
            ].join(' · '),
            icon: Icons.schedule_rounded,
            tone: _isNow(r, ctx) ? AssistantTone.accent : AssistantTone.neutral,
            trailing: _isNow(r, ctx) ? 'Now' : null,
          ),
      ],
    ));

    return _Answer(
      blocks: blocks,
      followUps: [
        if (!isToday) 'What about today?',
        'What is due this week?',
        "What's my attendance?",
      ],
    );
  }

  bool _isNow(ScheduleRow row, AssistantContext ctx) {
    final current = ctx.currentClass;
    return current != null && current.name == row.name;
  }

  List<ScheduleRow> _rowsForDay(AssistantContext ctx, DateTime day) {
    final rows = ctx.timetable?.timetable ?? const [];
    return rows
        .where((r) => _sameDay(r.date, day))
        .toList()
      ..sort((a, b) => (a.fromTime ?? '').compareTo(b.fromTime ?? ''));
  }

  _Answer _answerAssignments(AssistantContext ctx, String? course) {
    if (ctx.isTeacher) return _answerSubmissions(ctx);

    var list = ctx.upcomingAssignments;
    if (course != null) {
      list = list.where((a) => (a.courseName ?? a.course) == course).toList();
    }

    if (list.isEmpty) {
      return _Answer(
        blocks: [
          HeadlineBlock(
            course == null ? 'Nothing upcoming' : 'Nothing upcoming in $course',
            caption: 'You are clear',
          ),
          const TextBlock('No assignments with a future deadline right now.'),
          if (ctx.awaitingGrade.isNotEmpty)
            TextBlock(
              '${ctx.awaitingGrade.length} submission'
              '${ctx.awaitingGrade.length == 1 ? ' is' : 's are'} still waiting to be graded.',
            ),
        ],
        followUps: ['What grades do I have?', "What's my attendance?"],
      );
    }

    final next = list.first;
    final blocks = <AssistantBlock>[
      HeadlineBlock(
        'Next up: ${next.title}',
        caption: '${next.courseName ?? 'General'}'
            '${next.studentGroupName != null ? ' · ${next.studentGroupName}' : ''}',
      ),
      MetricsBlock([
        AssistantMetric(
          label: 'Due',
          value: _relativeDue(next, ctx),
          tone: _dueTone(next, ctx),
        ),
        AssistantMetric(label: 'Remaining', value: '${ctx.todoAssignments.length}'),
        AssistantMetric(label: 'Overdue', value: '${ctx.overdueAssignments.length}',
            tone: ctx.overdueAssignments.isEmpty ? AssistantTone.success : AssistantTone.danger),
      ]),
      ListBlock(
        title: 'Your to-do list',
        items: [
          for (final a in list.take(6))
            AssistantListItem(
              title: a.title,
              subtitle: [
                a.courseName ?? a.course ?? 'General',
                'Due ${_shortDate(a.dueDate!)}',
                '${_daysUntil(a, ctx)}d left',
              ].join(' · '),
              icon: Icons.assignment_rounded,
              tone: _dueTone(a, ctx),
              trailing: _daysUntil(a, ctx) <= 1 ? 'Urgent' : null,
            ),
        ],
      ),
      if (list.length > 6) TextBlock('…and ${list.length - 6} more after these.'),
    ];

    return _Answer(
      blocks: blocks,
      followUps: [
        if (next.courseName != null) 'What is due in ${next.courseName}?',
        'What is overdue?',
        'Make me a study plan',
      ],
      assignmentTitle: next.title,
    );
  }

  _Answer _answerDueSoon(AssistantContext ctx) {
    if (ctx.isTeacher) return _answerSubmissions(ctx);
    final week = ctx.dueWithin(7);
    if (week.isEmpty) {
      return _Answer(
        blocks: [
          const HeadlineBlock('Nothing due in the next 7 days', caption: 'Clear week'),
          if (ctx.upcomingAssignments.isNotEmpty)
            TextBlock(
              'Your next deadline after that is ${ctx.upcomingAssignments.first.title} '
              'on ${_shortDate(ctx.upcomingAssignments.first.dueDate!)}.',
            )
          else
            const TextBlock('You are fully caught up. Good time to revise ahead.'),
        ],
        followUps: ['Make me a study plan', 'How am I doing overall?'],
      );
    }

    final grouped = <String, List<AssignmentModel>>{};
    for (final a in week) {
      final key = a.courseName ?? a.course ?? 'General';
      grouped.putIfAbsent(key, () => []).add(a);
    }

    return _Answer(
      blocks: [
        HeadlineBlock(
          '${week.length} thing${week.length == 1 ? '' : 's'} due in the next 7 days',
          caption: week.first.title,
        ),
        MetricsBlock([
          AssistantMetric(
            label: 'Most urgent',
            value: _relativeDue(week.first, ctx),
            tone: _dueTone(week.first, ctx),
          ),
          AssistantMetric(label: 'Subjects', value: '${grouped.length}'),
          AssistantMetric(
            label: 'Overdue',
            value: '${ctx.overdueAssignments.length}',
            tone: ctx.overdueAssignments.isEmpty ? AssistantTone.success : AssistantTone.danger,
          ),
        ]),
        ListBlock(
          title: 'In deadline order',
          items: [
            for (final a in week)
              AssistantListItem(
                title: a.title,
                subtitle: '${a.courseName ?? 'General'} · ${_weekdayName(a.dueDate!.weekday)} ${_shortDate(a.dueDate!)}',
                trailing: _relativeDue(a, ctx),
                tone: _dueTone(a, ctx),
                icon: Icons.event_available_rounded,
              ),
          ],
        ),
        TextBlock(
          'Suggested order: ${week.take(3).map((a) => a.title).join(' → ')}.',
        ),
      ],
      followUps: [
        if (ctx.weakestCourses.isNotEmpty) 'Why is ${ctx.weakestCourses.first.key} low?',
        'Make me a study plan',
        'What is overdue?',
      ],
    );
  }

  _Answer _answerOverdue(AssistantContext ctx) {
    final overdue = ctx.overdueAssignments;
    if (overdue.isEmpty) {
      return _Answer(
        blocks: [
          const HeadlineBlock('Nothing overdue 🎉', caption: 'All clear'),
          TextBlock(
            ctx.awaitingGrade.isEmpty
                ? 'Everything with a deadline has been submitted.'
                : 'Everything is submitted — ${ctx.awaitingGrade.length} waiting on grades.',
          ),
        ],
        followUps: ['What is due this week?', 'How am I doing overall?'],
      );
    }
    return _Answer(
      blocks: [
        HeadlineBlock(
          '${overdue.length} overdue item${overdue.length == 1 ? '' : 's'}',
          caption: 'These passed their deadline without a submission',
        ),
        ListBlock(
          items: [
            for (final a in overdue)
              AssistantListItem(
                title: a.title,
                subtitle: '${a.courseName ?? 'General'} · was due ${_shortDate(a.dueDate!)}',
                trailing: '${_daysSince(a, ctx)}d late',
                tone: AssistantTone.danger,
                icon: Icons.error_outline_rounded,
              ),
          ],
        ),
        TextBlock(
          'Talk to the teacher before submitting — a late note is usually better '
          'than a silent zero.',
        ),
      ],
      followUps: ['What is due this week?', 'Make me a study plan'],
    );
  }

  _Answer _answerGrades(AssistantContext ctx, String? course) {
    final graded = ctx.gradedAssignments;
    if (graded.isEmpty) {
      return _Answer(
        blocks: [
          const HeadlineBlock('No grades yet', caption: 'Pending'),
          TextBlock(
            ctx.awaitingGrade.isEmpty
                ? 'Nothing has been submitted yet, so there is nothing graded.'
                : '${ctx.awaitingGrade.length} submission${ctx.awaitingGrade.length == 1 ? '' : 's'} '
                    'waiting to be graded — check back soon.',
          ),
        ],
        followUps: ['What is due this week?', "What's my attendance?"],
      );
    }

    if (course != null && ctx.gradeByCourse.containsKey(course)) {
      final rows = graded.where((a) => (a.courseName ?? a.course) == course).toList();
      final avg = ctx.gradeByCourse[course]!;
      return _Answer(
        blocks: [
          HeadlineBlock('$course: ${avg.toStringAsFixed(1)} average', caption: '${rows.length} graded'),
          RingBlock(percent: avg, label: course),
          ListBlock(
            items: [
              for (final a in rows)
                AssistantListItem(
                  title: a.title,
                  trailing: a.displayGrade,
                  tone: _gradeTone(a.grade ?? 0),
                  icon: Icons.grading_rounded,
                ),
            ],
          ),
        ],
        followUps: ['How am I doing overall?', 'Make me a study plan'],
      );
    }

    final byCourse = ctx.gradeByCourse.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return _Answer(
      blocks: [
        HeadlineBlock(
          'Average ${ctx.averageGrade.toStringAsFixed(1)} across ${ctx.subjectsWithGrades} subjects',
          caption: ctx.standing.label,
        ),
        RingBlock(
          percent: ctx.averageGrade,
          label: 'Overall average',
          caption: ctx.standing.why,
        ),
        BarsBlock(
          title: 'Average by subject',
          bars: [
            for (final e in byCourse)
              AssistantBar(
                label: e.key,
                value: e.value,
                valueLabel: e.value.toStringAsFixed(1),
                tone: _gradeTone(e.value),
              ),
          ],
        ),
        ListBlock(
          title: 'Recently graded',
          items: [
            for (final a in (graded.toList()
                  ..sort((a, b) => (b.submittedAt ?? b.dueDate ?? b.creation ?? ctx.now)
                      .compareTo(a.submittedAt ?? a.dueDate ?? a.creation ?? ctx.now)))
                .take(5))
              AssistantListItem(
                title: a.title,
                subtitle: a.courseName ?? a.course ?? 'General',
                trailing: a.displayGrade,
                tone: _gradeTone(a.grade ?? 0),
                icon: Icons.workspace_premium_rounded,
              ),
          ],
        ),
        if (ctx.bestAssignment != null && ctx.worstAssignment != null &&
            ctx.bestAssignment!.id != ctx.worstAssignment!.id)
          TextBlock(
            'Strongest: ${ctx.bestAssignment!.title} (${ctx.bestAssignment!.displayGrade}). '
            '${ctx.worstAssignment!.title} (${ctx.worstAssignment!.displayGrade}) is where the '
            'average is losing the most points.',
          ),
      ],
      followUps: [
        'How am I doing overall?',
        if (byCourse.isNotEmpty) 'How are my ${byCourse.first.key} grades?',
        'Make me a study plan',
      ],
    );
  }

  _Answer _answerPerformance(AssistantContext ctx) {
    final standing = ctx.standing;
    final weak = ctx.weakestCourses;
    final blocks = <AssistantBlock>[
      HeadlineBlock(
        ctx.gradedAssignments.isEmpty
            ? 'Too early for a full picture'
            : 'Overall: ${standing.label}',
        caption: standing.why,
      ),
    ];

    if (ctx.gradedAssignments.isNotEmpty || ctx.courseAttendance.isNotEmpty) {
      blocks.add(MetricsBlock([
        AssistantMetric(
          label: 'Avg grade',
          value: ctx.gradedAssignments.isEmpty ? '—' : ctx.averageGrade.toStringAsFixed(1),
        ),
        AssistantMetric(
          label: 'Attendance',
          value: ctx.overallAttendance.toStringAsFixed(0),
          suffix: '%',
          tone: _attendanceTone(ctx.overallAttendance),
        ),
        AssistantMetric(
          label: 'Done',
          value: '${ctx.gradedAssignments.length + ctx.awaitingGrade.length}',
          tone: AssistantTone.success,
        ),
      ]));
    }

    final gradeByCourse = ctx.gradeByCourse.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    if (gradeByCourse.isNotEmpty) {
      blocks.add(BarsBlock(
        title: 'Where the marks are',
        bars: [
          for (final e in gradeByCourse)
            AssistantBar(
              label: e.key,
              value: e.value,
              valueLabel: e.value.toStringAsFixed(1),
              tone: _gradeTone(e.value),
            ),
        ],
      ));
    }

    final insights = <String>[];
    if (weak.isNotEmpty && weak.first.value < 80) {
      insights.add(
        '${weak.first.key} is your weakest subject at ${weak.first.value.toStringAsFixed(0)}% attendance.',
      );
    }
    if (ctx.overdueAssignments.isNotEmpty) {
      insights.add('${ctx.overdueAssignments.length} overdue item(s) are dragging the average down.');
    }
    if (ctx.awaitingGrade.length > 3) {
      insights.add('${ctx.awaitingGrade.length} submissions are awaiting grades — the picture will change.');
    }
    if (ctx.bestAssignment != null) {
      insights.add('You scored ${ctx.bestAssignment!.displayGrade} on ${ctx.bestAssignment!.title} — repeat whatever worked there.');
    }
    if (insights.isNotEmpty) {
      blocks.add(ListBlock(
        title: 'What I would do next',
        items: [
          for (final i in insights)
            AssistantListItem(title: i, icon: Icons.tips_and_updates_rounded, tone: AssistantTone.accent),
        ],
      ));
    }

    return _Answer(
      blocks: blocks,
      followUps: ['Make me a study plan', 'What is due this week?'],
    );
  }

  _Answer _answerStudyPlan(AssistantContext ctx) {
    final weak = ctx.weakestCourses.where((e) => e.value < 85).toList();
    final due = ctx.dueWithin(10);

    if (weak.isEmpty && due.isEmpty && ctx.gradedAssignments.isEmpty) {
      return _Answer(
        blocks: [
          const HeadlineBlock('Not enough data for a plan yet'),
          const TextBlock(
            'I build study plans from your attendance, deadlines and grades. '
            'Once a few weeks are on record I will space revision across your weakest subjects.',
          ),
        ],
        followUps: ['What is due this week?', "What's my attendance?"],
      );
    }

    final blocks = <AssistantBlock>[
      HeadlineBlock(
        'Your 7-day study plan',
        caption: 'Weighted toward your weakest subjects and nearest deadlines',
      ),
    ];

    // Build slots: two per day, alternating weakest subjects and due work.
    final subjects = <String>{
      ...weak.map((e) => e.key),
      ...due.map((a) => a.courseName ?? a.course ?? 'General'),
    }.toList();

    final plan = <AssistantListItem>[];
    final today = ctx.now;
    for (int d = 0; d < 5 && subjects.isNotEmpty; d++) {
      final day = today.add(Duration(days: d));
      final primary = subjects[d % subjects.length];
      final secondary = subjects.length > 1 ? subjects[(d + 1) % subjects.length] : null;
      final dueItem = due.where((a) => (a.courseName ?? a.course) == primary).toList();
      final detail = dueItem.isEmpty
          ? 'Revision block · 30 min'
          : 'Finish "${dueItem.first.title}" · due ${_shortDate(dueItem.first.dueDate!)}';
      plan.add(AssistantListItem(
        title: '${_weekdayName(day.weekday)} · $primary',
        subtitle: detail +
            (secondary != null ? ' · then 15 min $secondary recall' : ''),
        icon: Icons.menu_book_rounded,
        tone: AssistantTone.accent,
      ));
    }

    blocks.add(ListBlock(title: 'Suggested week', items: plan));

    final weaknessNotes = <String>[];
    for (final w in weak.take(2)) {
      weaknessNotes.add(
        '${w.key}: ${w.value.toStringAsFixed(0)}% attendance. Two focused sessions a week '
        'plus attending every class recovers this fastest.',
      );
    }
    if (due.isNotEmpty) {
      weaknessNotes.add(
        'Start with ${due.first.title} — it is the nearest deadline '
        '(${_relativeDue(due.first, ctx)}).',
      );
    }
    if (weaknessNotes.isNotEmpty) {
      blocks.add(ListBlock(
        title: 'Why this plan',
        items: [
          for (final n in weaknessNotes)
            AssistantListItem(title: n, icon: Icons.psychology_alt_rounded),
        ],
      ));
    }

    return _Answer(
      blocks: blocks,
      followUps: ["What's my attendance?", 'How am I doing overall?', 'What is due this week?'],
    );
  }

  // ─── Teacher answers ─────────────────────────────────────────────────────

  _Answer _answerClassSummary(AssistantContext ctx) {
    if (ctx.classes.isEmpty) {
      return _Answer(
        blocks: [
          const HeadlineBlock('No classes assigned yet'),
          const TextBlock(
            'Once your classes are timetabled I will summarise attendance, '
            'submissions and grading load for each one.',
          ),
        ],
        followUps: ['What still needs grading?'],
      );
    }

    final byClass = <String, List<AssignmentModel>>{};
    for (final a in ctx.assignments) {
      final key = a.studentGroupName ?? a.studentGroup ?? 'Unassigned';
      byClass.putIfAbsent(key, () => []).add(a);
    }

    final rows = ctx.classes.map((c) {
      final name = c.studentGroupName ?? c.studentGroup ?? 'Class';
      final list = byClass[name] ?? const <AssignmentModel>[];
      final pending = list.fold<int>(0, (s, a) => s + (a.submittedCount - a.gradedCount).clamp(0, 9999));
      final rate = list.isEmpty
          ? null
          : list.map((a) => a.submissionRate).reduce((a, b) => a + b) / list.length;
      return (name: name, count: c.studentCount, list: list, pending: pending, rate: rate);
    }).toList();

    return _Answer(
      blocks: [
        HeadlineBlock(
          '${ctx.classes.length} class${ctx.classes.length == 1 ? '' : 'es'} in your care',
          caption: ctx.totalStudentsTaught > 0 ? '${ctx.totalStudentsTaught} students enrolled' : null,
        ),
        MetricsBlock([
          AssistantMetric(label: 'Classes', value: '${ctx.classes.length}'),
          AssistantMetric(
            label: 'To grade',
            value: '${ctx.assignmentsNeedingGrades.length}',
            tone: ctx.assignmentsNeedingGrades.isEmpty
                ? AssistantTone.success
                : AssistantTone.warning,
          ),
          AssistantMetric(
            label: 'Assignments',
            value: '${ctx.assignments.length}',
          ),
        ]),
        BarsBlock(
          title: 'Average submission rate',
          bars: [
            for (final r in rows.where((r) => r.rate != null))
              AssistantBar(
                label: r.name,
                value: r.rate! * 100,
                valueLabel: '${(r.rate! * 100).toStringAsFixed(0)}%',
                tone: r.rate! >= 0.8
                    ? AssistantTone.success
                    : r.rate! >= 0.6
                        ? AssistantTone.warning
                        : AssistantTone.danger,
              ),
          ],
        ),
        ListBlock(
          title: 'Class by class',
          items: [
            for (final r in rows)
              AssistantListItem(
                title: r.name,
                subtitle: [
                  if (r.count != null) '${r.count} students',
                  '${r.list.length} assignment${r.list.length == 1 ? '' : 's'}',
                  if (r.pending > 0) '${r.pending} awaiting grades' else 'no grading backlog',
                ].join(' · '),
                trailing: r.rate == null ? null : '${(r.rate! * 100).toStringAsFixed(0)}%',
                tone: r.pending > 0 ? AssistantTone.warning : AssistantTone.success,
                icon: Icons.groups_rounded,
              ),
          ],
        ),
      ],
      followUps: ['What still needs grading?', 'Which students need help?'],
    );
  }

  _Answer _answerRoster(AssistantContext ctx) {
    if (ctx.classes.isEmpty) {
      return _Answer(
        blocks: [const TextBlock('You do not have classes assigned yet.')],
        followUps: ['What still needs grading?'],
      );
    }
    return _Answer(
      blocks: [
        HeadlineBlock(
          'Your classes',
          caption: ctx.totalStudentsTaught > 0 ? '${ctx.totalStudentsTaught} students total' : null,
        ),
        ListBlock(
          items: [
            for (final c in ctx.classes)
              AssistantListItem(
                title: c.studentGroupName ?? c.studentGroup ?? 'Class',
                subtitle: [
                  c.courseName ?? 'Course',
                  if (c.room != null) 'Room ${c.room}',
                  if (c.startTime != null) c.startTime!,
                ].join(' · '),
                trailing: c.studentCount == null ? null : '${c.studentCount}',
                icon: Icons.groups_rounded,
                tone: AssistantTone.accent,
              ),
          ],
        ),
        const TextBlock(
          'Open a class from the Classes tab to see the roster, mark attendance or grade work.',
        ),
      ],
      followUps: ['How are my classes doing?', 'What still needs grading?'],
    );
  }

  _Answer _answerAtRisk(AssistantContext ctx) {
    final backlog = ctx.gradingBacklog.where((r) => r.pending > 0).toList();
    final lowSubmission = ctx.assignments
        .where((a) => a.totalStudents > 0 && a.submissionRate < 0.6)
        .toList();

    if (backlog.isEmpty && lowSubmission.isEmpty) {
      return _Answer(
        blocks: [
          const HeadlineBlock('Nothing is slipping', caption: 'All classes healthy'),
          const TextBlock(
            'Submission rates look healthy and there is no grading backlog right now.',
          ),
        ],
        followUps: ['How are my classes doing?', 'Summarise my week'],
      );
    }

    return _Answer(
      blocks: [
        HeadlineBlock(
          '${lowSubmission.length + backlog.length} signal${lowSubmission.length + backlog.length == 1 ? '' : 's'} to act on',
          caption: 'Ranked by impact',
        ),
        if (lowSubmission.isNotEmpty)
          ListBlock(
            title: 'Low submission rates',
            items: [
              for (final a in lowSubmission)
                AssistantListItem(
                  title: a.title,
                  subtitle: '${a.studentGroupName ?? 'Class'} · '
                      '${a.submittedCount}/${a.totalStudents} submitted',
                  trailing: '${(a.submissionRate * 100).toStringAsFixed(0)}%',
                  tone: AssistantTone.danger,
                  icon: Icons.trending_down_rounded,
                ),
            ],
          ),
        if (backlog.isNotEmpty)
          ListBlock(
            title: 'Waiting on your grades',
            items: [
              for (final r in backlog.take(5))
                AssistantListItem(
                  title: r.assignment.title,
                  subtitle: '${r.pending} submission${r.pending == 1 ? '' : 's'} ungraded',
                  trailing: r.pending > 10 ? 'High' : 'Normal',
                  tone: r.pending > 10 ? AssistantTone.warning : AssistantTone.info,
                  icon: Icons.rate_review_rounded,
                ),
            ],
          ),
      ],
      followUps: ['What still needs grading?', 'How are my classes doing?'],
    );
  }

  _Answer _answerSubmissions(AssistantContext ctx) {
    if (ctx.assignments.isEmpty) {
      return _Answer(
        blocks: [
          const HeadlineBlock('No assignments yet', caption: 'Nothing to grade'),
          const TextBlock('Create an assignment and I will track submissions and grading for you.'),
        ],
        followUps: ['How are my classes doing?'],
      );
    }

    final needing = ctx.assignmentsNeedingGrades;
    final totalPending = needing.fold<int>(
      0,
      (s, a) => s + (a.submittedCount - a.gradedCount).clamp(0, 9999),
    );

    if (needing.isEmpty) {
      return _Answer(
        blocks: [
          const HeadlineBlock('Grading is up to date ✅', caption: 'Nothing pending'),
          TextBlock(
            'All ${ctx.assignments.length} assignment'
            '${ctx.assignments.length == 1 ? '' : 's'} are fully graded.',
          ),
          ListBlock(
            title: 'Recent submission rates',
            items: [
              for (final a in ctx.assignments.take(5))
                AssistantListItem(
                  title: a.title,
                  subtitle: '${a.submittedCount}/${a.totalStudents} submitted',
                  trailing: '${(a.submissionRate * 100).toStringAsFixed(0)}%',
                  tone: AssistantTone.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
            ],
          ),
        ],
        followUps: ['How are my classes doing?', 'Summarise my week'],
      );
    }

    return _Answer(
      blocks: [
        HeadlineBlock(
          '$totalPending submission${totalPending == 1 ? '' : 's'} to grade',
          caption: 'across ${needing.length} assignment${needing.length == 1 ? '' : 's'}',
        ),
        MetricsBlock([
          AssistantMetric(
            label: 'Assignments',
            value: '${needing.length}',
            tone: AssistantTone.warning,
          ),
          AssistantMetric(label: 'Submissions', value: '$totalPending'),
          AssistantMetric(label: 'Graded', value: '${ctx.assignments.length - needing.length}',
              tone: AssistantTone.success),
        ]),
        ListBlock(
          title: 'Biggest backlogs first',
          items: [
            for (final a in needing)
              AssistantListItem(
                title: a.title,
                subtitle: '${a.studentGroupName ?? 'Class'} · '
                    '${a.submittedCount}/${a.totalStudents} submitted',
                trailing: '${(a.submittedCount - a.gradedCount)} to grade',
                tone: AssistantTone.warning,
                icon: Icons.rate_review_rounded,
              ),
          ],
        ),
      ],
      followUps: ['Which students need help?', 'How are my classes doing?'],
    );
  }

  // ─── Shared answers ──────────────────────────────────────────────────────

  _Answer _answerSchoolInfo(AssistantContext ctx) {
    return _Answer(
      blocks: [
        HeadlineBlock(ctx.schoolName ?? 'Your school', caption: 'Signed in as ${ctx.userName}'),
        if (ctx.classNames.isNotEmpty)
          ListBlock(
            title: 'Your classes',
            items: [
              for (final c in ctx.classNames)
                AssistantListItem(title: c, icon: Icons.groups_rounded),
            ],
          ),
        const TextBlock(
          'Your school can update its logo, motto and contact details from the admin console.',
        ),
      ],
      followUps: ctx.isTeacher
          ? ['How are my classes doing?']
          : ["What's my attendance?", 'Show my timetable'],
    );
  }

  _Answer _answerUnknown(AssistantContext ctx, String original) {
    final options = ctx.isTeacher
        ? ['What still needs grading?', 'How are my classes doing?', 'Which students need help?']
        : ["What's my attendance?", 'What is due this week?', 'How am I doing overall?'];
    return _Answer(
      blocks: [
        HeadlineBlock('I did not catch that', caption: '"${_truncate(original, 60)}"'),
        const TextBlock(
          'I am strongest on your attendance, assignments, grades and timetable. '
          'Try one of these:',
        ),
        ActionsBlock([
          for (final o in options) AssistantAction(label: o, prompt: o),
        ]),
      ],
      followUps: options,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════════════════════════════════

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _weekdayName(int weekday) => const [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
      ][(weekday - 1).clamp(0, 6)];

  static String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max - 1)}…';

  int _daysUntil(AssignmentModel a, AssistantContext ctx) {
    final due = DateTime(a.dueDate!.year, a.dueDate!.month, a.dueDate!.day);
    final today = DateTime(ctx.now.year, ctx.now.month, ctx.now.day);
    return due.difference(today).inDays;
  }

  int _daysSince(AssignmentModel a, AssistantContext ctx) {
    final due = DateTime(a.dueDate!.year, a.dueDate!.month, a.dueDate!.day);
    final today = DateTime(ctx.now.year, ctx.now.month, ctx.now.day);
    return today.difference(due).inDays;
  }

  String _relativeDue(AssignmentModel a, AssistantContext ctx) {
    final d = _daysUntil(a, ctx);
    if (d < 0) return 'overdue';
    if (d == 0) return 'today';
    if (d == 1) return 'tomorrow';
    return 'in $d days';
  }

  AssistantTone _dueTone(AssignmentModel a, AssistantContext ctx) {
    final d = _daysUntil(a, ctx);
    if (d < 0) return AssistantTone.danger;
    if (d <= 1) return AssistantTone.warning;
    if (d <= 3) return AssistantTone.info;
    return AssistantTone.neutral;
  }

  static AssistantTone _attendanceTone(double pct) {
    if (pct >= 90) return AssistantTone.success;
    if (pct >= 75) return AssistantTone.info;
    if (pct >= 60) return AssistantTone.warning;
    return AssistantTone.danger;
  }

  static AssistantTone _gradeTone(double grade) {
    if (grade >= 85) return AssistantTone.success;
    if (grade >= 70) return AssistantTone.info;
    if (grade >= 55) return AssistantTone.warning;
    return AssistantTone.danger;
  }

  /// Flatten blocks into readable text for sharing, copying and screen readers.
  static String plainTextOf(List<AssistantBlock> blocks) {
    final out = <String>[];
    for (final b in blocks) {
      switch (b) {
        case TextBlock(:final text):
          out.add(text);
        case HeadlineBlock(:final text, :final caption):
          out.add([text, if (caption != null) '($caption)'].join(' '));
        case MetricsBlock(:final metrics):
          out.add(metrics.map((m) => '${m.label}: ${m.value}${m.suffix ?? ''}').join('  ·  '));
        case RingBlock(:final percent, :final label, :final caption):
          out.add('$label: ${percent.toStringAsFixed(1)}%'
              '${caption != null ? ' — $caption' : ''}');
        case ListBlock(:final title, :final items):
          if (title != null) out.add('$title:');
          for (final i in items) {
            out.add('  • ${i.title}'
                '${i.subtitle != null ? ' — ${i.subtitle}' : ''}'
                '${i.trailing != null ? ' [${i.trailing}]' : ''}');
          }
        case BarsBlock(:final title, :final bars):
          if (title != null) out.add('$title:');
          out.add('  ${bars.map((b) => '${b.label} ${b.valueLabel ?? b.value.toStringAsFixed(0)}').join('  ')}');
        case TrendBlock(:final title, :final values):
          out.add('${title ?? 'Trend'}: '
              '${values.map((v) => '${v.toStringAsFixed(0)}%').join(' → ')}');
        case HeatBlock(:final title, :final days):
          out.add('${title ?? 'Days'}: '
              '${days.map((d) => '${d.label}:${d.status}').join('  ')}');
        case ActionsBlock(:final actions):
          out.add(actions.map((a) => a.label).join('  |  '));
      }
    }
    return out.join('\n');
  }

}

/// Convenience getter used by the engine's summary strings.
extension on AssistantContext {
  int get subjectsWithGrades => gradeByCourse.length;
}

/// Internal answer payload before it becomes a public [AssistantReply].
class _Answer {
  final List<AssistantBlock> blocks;
  final List<String> followUps;
  final String? assignmentTitle;

  const _Answer({
    required this.blocks,
    this.followUps = const [],
    this.assignmentTitle,
  });
}
