import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/colors.dart';
import '../../theme/tokens.dart';
import 'doodle_icons.dart';
import 'foundation.dart';

class AppNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Optional doodle glyph. When set it replaces the Material icons.
  final DoodleKind? doodle;

  const AppNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.doodle,
  });
}

/// Hand-rolled bottom navigation.
///
/// Why not `BottomNavigationBar`: this bar animates an accent pill behind the
/// active item, keeps the label baseline steady, and can render one slot as a
/// gradient **AI orb** ([aiIndex]) — a detail that reads as designed rather
/// than default.
///
/// [items] always contains *every* destination (including the AI one), so
/// [index] and [onChanged] use stable destination indices and inserting the
/// orb never shifts a tap target.
class AppBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<AppNavItem> items;
  final AppRoleStyle role;

  /// Destination rendered as the AI orb instead of a normal tile.
  final int? aiIndex;
  final bool aiBusy;

  const AppBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
    this.role = AppRoleStyle.student,
    this.aiIndex,
    this.aiBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          boxShadow: [
            BoxShadow(
              color: role.accent.withValues(alpha: 0.10),
              blurRadius: 26,
              spreadRadius: -4,
              offset: const Offset(0, -8),
            ),
          ],
          border: Border(
            top: BorderSide(color: AppColors.hairlineBorder.withValues(alpha: 0.9)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 5),
            child: Row(
              children: [
                for (int i = 0; i < items.length; i++)
                  Expanded(
                    child: i == aiIndex
                        // `heightFactor: 1` keeps this slot exactly as tall as
                        // the orb. A bare `Center`/`Align` expands to the
                        // tallest constraint it is handed, so inside this Row
                        // it grew the bar to the full height of the screen and
                        // `crossAxisAlignment: center` then parked every tab in
                        // the middle of the display. Keep the factor.
                        ? Align(
                            alignment: Alignment.center,
                            heightFactor: 1,
                            child: NavAiAction(
                              busy: aiBusy,
                              selected: index == i,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onChanged(i);
                              },
                            ),
                          )
                        : _NavTile(
                            item: items[i],
                            role: role,
                            selected: index == i,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onChanged(i);
                            },
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final AppNavItem item;
  final AppRoleStyle role;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.emphasized,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: selected ? role.accent.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: AppRadius.brMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.06 : 1,
                    duration: AppMotion.base,
                    curve: AppMotion.springy,
                    child: AnimatedSwitcher(
                      duration: AppMotion.fast,
                      child: item.doodle != null
                          ? DoodleIcon(
                              key: ValueKey(selected),
                              kind: item.doodle!,
                              size: 26,
                              color:
                                  selected ? role.accent : AppColors.inkFaint,
                              filled: selected,
                            )
                          : Icon(
                              selected ? item.selectedIcon : item.icon,
                              key: ValueKey(selected),
                              size: 22,
                              color:
                                  selected ? role.accent : AppColors.inkFaint,
                            ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      bottom: -7,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: role.accent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: AppMotion.fast,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? role.accent : AppColors.inkFaint,
                ),
                child: Text(item.label, maxLines: 1, overflow: TextOverflow.clip),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The AI copilot action that occupies one slot of the nav bar.
class NavAiAction extends StatelessWidget {
  final VoidCallback onTap;
  final bool busy;
  final bool selected;

  const NavAiAction({
    super.key,
    required this.onTap,
    this.busy = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Ask AI',
      child: Pressable(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1 : 0.94,
              duration: AppMotion.base,
              curve: AppMotion.springy,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.ai,
                  boxShadow: AppShadows.glow(
                    AppColors.primary,
                    strength: selected ? 0.50 : 0.34,
                  ),
                  border: Border.all(color: Colors.white, width: selected ? 3 : 2.4),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 23),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              busy ? 'Thinking' : 'Ask AI',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.primary : AppColors.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
