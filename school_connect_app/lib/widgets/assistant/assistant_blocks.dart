import 'package:flutter/material.dart';

import '../../services/assistant/assistant_models.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import '../kit/kit.dart';

/// Renders one structured assistant answer.
///
/// The engine emits typed blocks instead of Markdown so the app controls the
/// presentation: metrics become tiles, comparisons become bars, and lists get
/// the same visual language as the rest of the app.
class AssistantBlockView extends StatelessWidget {
  final List<AssistantBlock> blocks;
  final Color accent;
  final void Function(String prompt)? onAction;

  const AssistantBlockView({
    super.key,
    required this.blocks,
    this.accent = AppColors.primary,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final w = _build(blocks[i]);
      if (w == null) continue;
      children.add(w);
      if (i != blocks.length - 1) children.add(const SizedBox(height: 14));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget? _build(AssistantBlock block) {
    switch (block) {
      case HeadlineBlock(:final text, :final caption):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: AppText.cardTitle.copyWith(fontSize: 16.5, height: 1.3),
            ),
            if (caption != null) ...[
              const SizedBox(height: 3),
              Text(caption, style: AppText.caption.copyWith(fontSize: 11.5)),
            ],
          ],
        );

      case TextBlock(:final text):
        return Text(text, style: AppText.body.copyWith(fontSize: 13.5, height: 1.5));

      case MetricsBlock(:final metrics):
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _metric(metrics[i])),
            ],
          ],
        );

      case RingBlock(:final percent, :final label, :final caption):
        return Row(
          children: [
            ProgressRing(
              percent: percent,
              size: 74,
              stroke: 8,
              gradient: ProgressRing.gradientFor(percent),
              center: Text(
                '${percent.toStringAsFixed(0)}%',
                style: AppText.cardTitle.copyWith(fontSize: 15),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.cardTitle),
                  if (caption != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      style: AppText.body.copyWith(fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );

      case ListBlock(:final title, :final items, :final emptyText):
        if (items.isEmpty) {
          return Text(
            emptyText ?? 'Nothing to show.',
            style: AppText.body.copyWith(fontSize: 13, color: AppColors.inkFaint),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title, style: AppText.eyebrow),
              const SizedBox(height: 8),
            ],
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 7),
              _listItem(items[i]),
            ],
          ],
        );

      case BarsBlock(:final title, :final bars):
        if (bars.isEmpty) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title, style: AppText.eyebrow),
              const SizedBox(height: 10),
            ],
            for (int i = 0; i < bars.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _bar(bars[i]),
            ],
          ],
        );

      case TrendBlock(:final title, :final values, :final caption):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) Text(title, style: AppText.eyebrow),
            const SizedBox(height: 8),
            Sparkline(values: values, height: 54, color: accent),
            if (caption != null && caption.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(caption, style: AppText.caption.copyWith(fontSize: 11.5)),
            ],
          ],
        );

      case HeatBlock(:final title, :final days):
        if (days.isEmpty) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title, style: AppText.eyebrow),
              const SizedBox(height: 8),
            ],
            HeatStrip(days: days, cellSize: 28),
          ],
        );

      case ActionsBlock(:final actions):
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in actions)
              Pressable(
                onTap: () => onAction?.call(a.prompt ?? a.label),
                borderRadius: AppRadius.brPill,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.09),
                    borderRadius: AppRadius.brPill,
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(a.icon, size: 13, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        a.label,
                        style: AppText.caption.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
    }
  }

  Widget _metric(AssistantMetric m) {
    final tone = toneColor(m.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: AppRadius.brSm,
        border: Border.all(color: tone.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.label.toUpperCase(),
            style: AppText.eyebrow.copyWith(fontSize: 9.5, color: tone),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  m.value,
                  style: AppText.cardTitle.copyWith(fontSize: 16, color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (m.suffix != null)
                Text(
                  m.suffix!,
                  style: AppText.cardTitle.copyWith(fontSize: 11, color: AppColors.inkSoft),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _listItem(AssistantListItem item) {
    final tone = toneColor(item.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.brSm,
        border: Border.all(color: AppColors.hairlineBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: AppRadius.brXs,
            ),
            child: Icon(item.icon ?? Icons.circle, size: 14, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppText.cardTitle.copyWith(fontSize: 13.5),
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle!,
                    style: AppText.caption.copyWith(fontSize: 11.5, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          if (item.trailing != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.13),
                borderRadius: AppRadius.brPill,
              ),
              child: Text(
                item.trailing!,
                style: AppText.caption.copyWith(
                  fontSize: 10.5,
                  color: tone,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bar(AssistantBar bar) {
    final tone = toneColor(bar.tone);
    final gradient = switch (bar.tone) {
      AssistantTone.success => AppGradients.mint,
      AssistantTone.warning => AppGradients.amber,
      AssistantTone.danger => AppGradients.rose,
      _ => LinearGradient(colors: [tone.withValues(alpha: 0.75), tone]),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                bar.label,
                style: AppText.cardTitle.copyWith(fontSize: 12.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              bar.valueLabel ?? bar.value.toStringAsFixed(0),
              style: AppText.caption.copyWith(
                fontSize: 11.5,
                color: tone,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        GradientBar(percent: bar.value, gradient: gradient, height: 7),
      ],
    );
  }
}
