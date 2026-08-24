import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';

class AppDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AppDestination({
    required this.icon,
    required this.label,
    this.selectedIcon = Icons.circle,
  });
}

/// Responsive shell with smooth animations
class AppShell extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<AppDestination> destinations;
  final List<Widget> tabs;
  final Color accent;
  final Widget? floatingActionButton;
  final double desktopRailBreakpoint;

  const AppShell({
    super.key,
    required this.index,
    required this.onChanged,
    required this.destinations,
    required this.tabs,
    this.accent = AppColors.primary,
    this.floatingActionButton,
    this.desktopRailBreakpoint = 720,
  });

  Widget _content() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey<int>(index), child: tabs[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= desktopRailBreakpoint;
        return Scaffold(
          body: isDesktop
              ? Row(
                  children: [
                    _buildRail(context),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: _content()),
                  ],
                )
              : _content(),
          bottomNavigationBar: isDesktop ? null : _buildMobileNav(),
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }

  Widget _buildRail(BuildContext context) {
    return NavigationRail(
      selectedIndex: index,
      onDestinationSelected: onChanged,
      backgroundColor: Colors.white,
      extended: true,
      minExtendedWidth: 190,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, accent.withValues(alpha: 0.65)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white),
        ),
      ),
      selectedIconTheme: IconThemeData(color: accent),
      unselectedIconTheme: const IconThemeData(color: AppColors.outline),
      selectedLabelTextStyle: TextStyle(color: accent, fontWeight: FontWeight.bold),
      unselectedLabelTextStyle: const TextStyle(color: AppColors.outline),
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
      trailing: const Spacer(),
    );
  }

  Widget _buildMobileNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < destinations.length; i++)
                _MobileNavItem(
                  icon: destinations[i].icon,
                  label: destinations[i].label,
                  isSelected: index == i,
                  accent: accent,
                  onTap: () => onChanged(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? accent : AppColors.outline,
                key: ValueKey(isSelected),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ).animate().fadeIn(duration: 200.ms).slideX(begin: -0.15),
            ],
          ],
        ),
      ),
    );
  }
}
