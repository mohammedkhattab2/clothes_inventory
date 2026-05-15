import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:clothes_inventory/core/theme/theme_cubit.dart';
import 'package:clothes_inventory/features/auth/domain/auth_user.dart';
import 'package:clothes_inventory/services/auth/session_service.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const double _sidebarWidth = 290;
  static const double _navListHorizontalPadding = 14;
  static const double _navListVerticalPadding = 8;
  static const double _navTileOuterHeight = 52;
  static const double _activeBeamHeight = 34;

  Offset _parallaxOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _selectedIndex(location);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    final themeMode = context.watch<ThemeCubit>().state;
    final beamColors = _beamGradientForIndex(
      selectedIndex,
      colorScheme,
      isDarkMode,
    );
    final beamGlow = beamColors.last;
    final sidebarGradientColors = [
      colorScheme.surfaceContainerHighest.withValues(
        alpha: isDarkMode ? 0.95 : 0.9,
      ),
      colorScheme.surfaceContainerHigh.withValues(
        alpha: isDarkMode ? 0.92 : 0.88,
      ),
      colorScheme.surface,
    ];

    final destinations = <_NavDestination>[
      _NavDestination(
        label: 'Dashboard'.tr(),
        icon: Icons.space_dashboard_outlined,
        selectedIcon: Icons.space_dashboard,
      ),
      _NavDestination(
        label: 'Products'.tr(),
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
      ),
      _NavDestination(
        label: 'Sales'.tr(),
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale,
      ),
      _NavDestination(
        label: 'Purchases'.tr(),
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping,
      ),
      _NavDestination(
        label: 'Invoices'.tr(),
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
      ),
      _NavDestination(
        label: 'Inventory'.tr(),
        icon: Icons.warehouse_outlined,
        selectedIcon: Icons.warehouse,
      ),
      _NavDestination(
        label: 'Accounts'.tr(),
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet,
      ),
      _NavDestination(
        label: 'Expenses'.tr(),
        icon: Icons.receipt_outlined,
        selectedIcon: Icons.receipt,
      ),
      _NavDestination(
        label: 'Statement'.tr(),
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
      ),
      _NavDestination(
        label: 'Settings'.tr(),
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
      _NavDestination(
        label: 'Users'.tr(),
        icon: Icons.manage_accounts_outlined,
        selectedIcon: Icons.manage_accounts,
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: _sidebarWidth,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: sidebarGradientColors,
              ),
              border: Border(
                right: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.85),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(
                    alpha: isDarkMode ? 0.24 : 0.08,
                  ),
                  blurRadius: 18,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return MouseRegion(
                  onHover: (event) {
                    final center = Offset(
                      constraints.maxWidth / 2,
                      constraints.maxHeight / 2,
                    );
                    final dx =
                        ((event.localPosition.dx - center.dx) / center.dx)
                            .clamp(-1.0, 1.0);
                    final dy =
                        ((event.localPosition.dy - center.dy) / center.dy)
                            .clamp(-1.0, 1.0);
                    setState(() {
                      _parallaxOffset = Offset(dx * 14, dy * 12);
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      _parallaxOffset = Offset.zero;
                    });
                  },
                  child: SafeArea(
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          top: -60 + (_parallaxOffset.dy * 0.45),
                          right: -40 + (_parallaxOffset.dx * 0.55),
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primary.withValues(
                                alpha: 0.14,
                              ),
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          bottom: -50 - (_parallaxOffset.dy * 0.35),
                          left: -30 - (_parallaxOffset.dx * 0.45),
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.tertiary.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                18,
                                20,
                                14,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: colorScheme.surface.withValues(
                                    alpha: isDarkMode ? 0.3 : 0.8,
                                  ),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _AnimatedBrandBadge(
                                      isDarkMode: isDarkMode,
                                      colorScheme: colorScheme,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Clothes Inventory POS',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: colorScheme.onSurface,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Smart control panel'.tr(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, navConstraints) {
                                  final navHeight =
                                      navConstraints.maxHeight -
                                      (_navListVerticalPadding * 2);
                                  const minGap = 8.0;
                                  const preferredGap = 16.0;
                                  final itemsHeight =
                                      destinations.length * _navTileOuterHeight;
                                  final availableForGaps =
                                      navHeight - itemsHeight;
                                  final computedGap = destinations.length > 1
                                      ? (availableForGaps /
                                                (destinations.length - 1))
                                            .clamp(minGap, preferredGap)
                                      : 0.0;

                                  final needsScroll =
                                      availableForGaps <
                                      ((destinations.length - 1) * minGap);
                                  final effectiveGap = needsScroll
                                      ? minGap
                                      : computedGap;

                                  final beamTop =
                                      _navListVerticalPadding +
                                      (selectedIndex *
                                          (_navTileOuterHeight +
                                              effectiveGap)) +
                                      ((_navTileOuterHeight -
                                              _activeBeamHeight) /
                                          2);

                                  return Stack(
                                    children: [
                                      AnimatedPositioned(
                                        duration: const Duration(
                                          milliseconds: 260,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        top: beamTop,
                                        left: _navListHorizontalPadding - 8,
                                        child: Container(
                                          width: 4,
                                          height: _activeBeamHeight,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: beamColors,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: beamGlow.withValues(
                                                  alpha: 0.45,
                                                ),
                                                blurRadius: 12,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (needsScroll)
                                        ListView.separated(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                _navListHorizontalPadding,
                                            vertical: _navListVerticalPadding,
                                          ),
                                          itemCount: destinations.length,
                                          separatorBuilder: (context, index) {
                                            return const SizedBox(
                                              height: minGap,
                                            );
                                          },
                                          itemBuilder: (context, index) {
                                            final destination =
                                                destinations[index];
                                            final selected =
                                                selectedIndex == index;
                                            return _SidebarNavTile(
                                              label: destination.label,
                                              icon: selected
                                                  ? destination.selectedIcon
                                                  : destination.icon,
                                              selected: selected,
                                              colorScheme: colorScheme,
                                              selectedGradient:
                                                  _beamGradientForIndex(
                                                    index,
                                                    colorScheme,
                                                    isDarkMode,
                                                  ),
                                              index: index,
                                              onTap: () =>
                                                  _goToIndex(context, index),
                                            );
                                          },
                                        )
                                      else
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                _navListHorizontalPadding,
                                            vertical: _navListVerticalPadding,
                                          ),
                                          child: Column(
                                            children: [
                                              for (
                                                var index = 0;
                                                index < destinations.length;
                                                index++
                                              ) ...[
                                                _SidebarNavTile(
                                                  label:
                                                      destinations[index].label,
                                                  icon: selectedIndex == index
                                                      ? destinations[index]
                                                            .selectedIcon
                                                      : destinations[index]
                                                            .icon,
                                                  selected:
                                                      selectedIndex == index,
                                                  colorScheme: colorScheme,
                                                  selectedGradient:
                                                      _beamGradientForIndex(
                                                        index,
                                                        colorScheme,
                                                        isDarkMode,
                                                      ),
                                                  index: index,
                                                  onTap: () => _goToIndex(
                                                    context,
                                                    index,
                                                  ),
                                                ),
                                                if (index <
                                                    destinations.length - 1)
                                                  SizedBox(
                                                    height: effectiveGap,
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ValueListenableBuilder<AuthUser?>(
                                    valueListenable: getIt<SessionService>()
                                        .currentUserListenable,
                                    builder: (context, user, _) {
                                      if (user == null) {
                                        return const SizedBox.shrink();
                                      }
                                      return Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          color: colorScheme.surface.withValues(
                                            alpha: isDarkMode ? 0.26 : 0.78,
                                          ),
                                          border: Border.all(
                                            color: colorScheme.outlineVariant,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.fullName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        colorScheme.onSurface,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${user.username} • ${_roleLabel(user.role)}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: colorScheme.surface.withValues(
                                        alpha: isDarkMode ? 0.26 : 0.78,
                                      ),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          themeMode == ThemeMode.dark
                                              ? Icons.dark_mode_outlined
                                              : themeMode == ThemeMode.light
                                              ? Icons.light_mode_outlined
                                              : Icons.brightness_6_outlined,
                                          color: colorScheme.onSurface,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Theme'.tr(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: colorScheme.onSurface,
                                                ),
                                          ),
                                        ),
                                        PopupMenuButton<ThemeMode>(
                                          tooltip: 'Theme Mode'.tr(),
                                          icon: Icon(
                                            Icons.tune_rounded,
                                            color: colorScheme.onSurface,
                                          ),
                                          onSelected: context
                                              .read<ThemeCubit>()
                                              .setThemeMode,
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: ThemeMode.system,
                                              child: Text('System'.tr()),
                                            ),
                                            PopupMenuItem(
                                              value: ThemeMode.light,
                                              child: Text('Light'.tr()),
                                            ),
                                            PopupMenuItem(
                                              value: ThemeMode.dark,
                                              child: Text('Dark'.tr()),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        getIt<SessionService>().logout();
                                      },
                                      icon: const Icon(Icons.switch_account),
                                      label: Text('Switch user'.tr()),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/products')) return 1;
    if (location.startsWith('/sales')) return 2;
    if (location.startsWith('/purchases')) return 3;
    if (location.startsWith('/invoices')) return 4;
    if (location.startsWith('/inventory')) return 5;
    if (location.startsWith('/accounts')) return 6;
    if (location.startsWith('/expenses')) return 7;
    if (location.startsWith('/statement')) return 8;
    if (location.startsWith('/settings')) return 9;
    if (location.startsWith('/users')) return 10;
    return 0;
  }

  List<Color> _beamGradientForIndex(
    int index,
    ColorScheme colorScheme,
    bool isDarkMode,
  ) {
    final accents = <Color>[
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
      colorScheme.inversePrimary,
      colorScheme.primaryContainer,
      colorScheme.secondaryContainer,
      colorScheme.tertiaryContainer,
    ];
    final base = accents[index % accents.length];
    final start = Color.lerp(base, Colors.white, isDarkMode ? 0.22 : 0.12)!;
    final end = Color.lerp(base, Colors.black, isDarkMode ? 0.18 : 0.1)!;
    return [start, end];
  }

  void _goToIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        return;
      case 1:
        context.go('/products');
        return;
      case 2:
        context.go('/sales');
        return;
      case 3:
        context.go('/purchases');
        return;
      case 4:
        final path = GoRouterState.of(context).uri.path;
        if (path.startsWith('/invoices')) {
          return;
        }
        if (path.startsWith('/purchases')) {
          context.go('/invoices?tab=purchases');
          return;
        }
        if (path.startsWith('/sales')) {
          context.go('/invoices?tab=sales');
          return;
        }
        context.go('/invoices');
        return;
      case 5:
        context.go('/inventory');
        return;
      case 6:
        context.go('/accounts');
        return;
      case 7:
        context.go('/expenses');
        return;
      case 8:
        context.go('/statement');
        return;
      case 9:
        context.go('/settings');
        return;
      case 10:
        context.go('/users');
        return;
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return 'Owner'.tr();
      case UserRole.manager:
        return 'Manager'.tr();
      case UserRole.cashier:
        return 'Cashier'.tr();
      case UserRole.purchaser:
        return 'Purchaser'.tr();
    }
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _SidebarNavTile extends StatefulWidget {
  const _SidebarNavTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.colorScheme,
    required this.selectedGradient,
    required this.index,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ColorScheme colorScheme;
  final List<Color> selectedGradient;
  final int index;
  final VoidCallback onTap;

  @override
  State<_SidebarNavTile> createState() => _SidebarNavTileState();
}

class _SidebarNavTileState extends State<_SidebarNavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hoverColor = widget.colorScheme.primaryContainer.withValues(
      alpha: isDarkMode ? 0.32 : 0.5,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (widget.index * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((1 - value) * -14, 0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            child: SizedBox(
              height: 44,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: widget.selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.selectedGradient,
                        )
                      : null,
                  color: widget.selected
                      ? null
                      : _hovered
                      ? hoverColor
                      : widget.colorScheme.surface.withValues(
                          alpha: isDarkMode ? 0.28 : 0.62,
                        ),
                  border: Border.all(
                    color: widget.selected
                        ? widget.colorScheme.primary.withValues(alpha: 0.35)
                        : _hovered
                        ? widget.colorScheme.outline.withValues(alpha: 0.75)
                        : widget.colorScheme.outlineVariant.withValues(
                            alpha: 0.75,
                          ),
                  ),
                  boxShadow: widget.selected
                      ? [
                          BoxShadow(
                            color: widget.selectedGradient.last.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 16,
                            spreadRadius: 1,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : _hovered
                      ? [
                          BoxShadow(
                            color:
                                (isDarkMode
                                        ? widget.colorScheme.shadow
                                        : widget.selectedGradient.first)
                                    .withValues(
                                      alpha: isDarkMode ? 0.24 : 0.12,
                                    ),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      scale: _hovered ? 1.08 : 1,
                      child: Icon(
                        widget.icon,
                        size: 22,
                        color: widget.selected
                            ? widget.colorScheme.onPrimary
                            : widget.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: widget.selected
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: widget.selected
                              ? widget.colorScheme.onPrimary
                              : widget.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (widget.selected)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.colorScheme.onPrimary.withValues(
                            alpha: 0.92,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedBrandBadge extends StatefulWidget {
  const _AnimatedBrandBadge({
    required this.isDarkMode,
    required this.colorScheme,
  });

  final bool isDarkMode;
  final ColorScheme colorScheme;

  @override
  State<_AnimatedBrandBadge> createState() => _AnimatedBrandBadgeState();
}

class _AnimatedBrandBadgeState extends State<_AnimatedBrandBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = 1 + (t * 0.06);
        final angle = (t - 0.5) * 0.06;

        return Transform.rotate(
          angle: angle,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: 54,
        height: 54,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Color.lerp(widget.colorScheme.primary, Colors.white, 0.2)!,
              widget.colorScheme.tertiary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.colorScheme.primary.withValues(
                alpha: widget.isDarkMode ? 0.35 : 0.24,
              ),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Image.asset('assets/icon/app_icon.png', fit: BoxFit.contain),
      ),
    );
  }
}
