import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../state/school_provider.dart';
import '../theme/colors.dart';

/// Compact school identity header: logo (with fallback icon), school name and
/// motto. Watches the shared school profile so an admin edit reflects
/// everywhere instantly. Used at the top of student/teacher dashboards.
class SchoolHeader extends ConsumerWidget {
  final bool compact;
  final Color? textColor;
  final bool showMotto;

  const SchoolHeader({
    super.key,
    this.compact = false,
    this.textColor,
    this.showMotto = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(schoolProvider);
    final profile = state.profile;

    // Fire a load once per session if nothing is cached yet.
    if (profile == null && !state.isLoading) {
      Future.microtask(() => ref.read(schoolProvider.notifier).load());
    }

    final name = profile?.schoolName ?? 'School';
    final motto = showMotto ? profile?.motto : null;
    final logoUrl = profile?.logoUrlFor(ApiConfig.activeBaseUrl);
    final color = textColor ?? AppColors.onSurface;

    Widget logo;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      logo = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          logoUrl,
          width: compact ? 38 : 46,
          height: compact ? 38 : 46,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackLogo(compact: compact, color: color),
        ),
      );
    } else {
      logo = _fallbackLogo(compact: compact, color: color);
    }

    return Row(
      children: [
        logo,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 17 : 20,
                  height: 1.1,
                ),
              ),
              if (motto != null && motto.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  motto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.75),
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallbackLogo({required bool compact, required Color color}) {
    return Container(
      width: compact ? 38 : 46,
      height: compact ? 38 : 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF192A88)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
    );
  }
}
