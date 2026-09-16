import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'colors.dart';
import 'fonts.dart';

class CharonNavDestination {
  const CharonNavDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Mirrors the `NAV` array in the Figma Make reference (`App.tsx`). Screen
/// content behind each destination lands in Milestones 6.1-6.7.
const charonNavDestinations = [
  CharonNavDestination(icon: LucideIcons.activity, label: 'DECK'),
  CharonNavDestination(icon: LucideIcons.server, label: 'NODES'),
  CharonNavDestination(icon: LucideIcons.split, label: 'SPLIT'),
  CharonNavDestination(icon: LucideIcons.shield, label: 'FAILSAFE'),
  CharonNavDestination(icon: LucideIcons.barChart3, label: 'TELEMETRY'),
  CharonNavDestination(icon: LucideIcons.smartphone, label: 'UNITS'),
  CharonNavDestination(icon: LucideIcons.settings, label: 'CONFIG'),
];

const _desktopBreakpoint = 900.0;

/// Adaptive navigation shell: a fixed sidebar on wide (desktop) windows, an
/// app bar + slide-in drawer on narrow (mobile) windows. Optional
/// [sidebarFooter]/[drawerFooter] slots let later milestones inject
/// state-dependent widgets (theme toggle, connection status) without
/// touching this file again.
class CharonNavShell extends StatefulWidget {
  const CharonNavShell({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.body,
    this.sidebarFooter,
    this.drawerFooter,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final Widget? sidebarFooter;
  final Widget? drawerFooter;

  @override
  State<CharonNavShell> createState() => _CharonNavShellState();
}

class _CharonNavShellState extends State<CharonNavShell> {
  bool _drawerOpen = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return constraints.maxWidth >= _desktopBreakpoint ? _buildDesktop() : _buildMobile();
      },
    );
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: CharonColors.background,
      body: Row(
        children: [
          Container(
            width: 240,
            decoration: const BoxDecoration(
              color: CharonColors.surface2,
              border: Border(right: BorderSide(color: CharonColors.steel)),
            ),
            child: Column(
              children: [
                const _Brand(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (var i = 0; i < charonNavDestinations.length; i++)
                        _NavTile(
                          destination: charonNavDestinations[i],
                          selected: i == widget.selectedIndex,
                          onTap: () => widget.onSelect(i),
                        ),
                    ],
                  ),
                ),
                ?widget.sidebarFooter,
              ],
            ),
          ),
          Expanded(child: widget.body),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: CharonColors.background,
      appBar: AppBar(
        backgroundColor: CharonColors.surface2,
        elevation: 0,
        title: const _BrandCompact(),
        actions: [
          IconButton(
            tooltip: 'Open menu',
            icon: const Icon(LucideIcons.menu, color: CharonColors.foreground),
            onPressed: () => setState(() => _drawerOpen = true),
          ),
        ],
      ),
      body: Stack(
        children: [
          widget.body,
          if (_drawerOpen) ...[
            GestureDetector(
              onTap: () => setState(() => _drawerOpen = false),
              child: Container(color: CharonColors.background.withValues(alpha: 0.7)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 260,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: CharonColors.surface2,
                  border: Border(left: BorderSide(color: CharonColors.steel)),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('NAVIGATION', style: techLabel(fontSize: 13, color: CharonColors.muted)),
                            IconButton(
                              tooltip: 'Close menu',
                              icon: const Icon(LucideIcons.x, color: CharonColors.muted, size: 18),
                              onPressed: () => setState(() => _drawerOpen = false),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (var i = 0; i < charonNavDestinations.length; i++)
                              _NavTile(
                                destination: charonNavDestinations[i],
                                selected: i == widget.selectedIndex,
                                onTap: () {
                                  widget.onSelect(i);
                                  setState(() => _drawerOpen = false);
                                },
                              ),
                          ],
                        ),
                      ),
                      ?widget.drawerFooter,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.destination, required this.selected, required this.onTap});

  final CharonNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? CharonColors.primaryBright : CharonColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? CharonColors.surface : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(width: 2, height: 16, color: selected ? CharonColors.primaryBright : Colors.transparent),
                const SizedBox(width: 10),
                Icon(destination.icon, size: 16, color: color),
                const SizedBox(width: 10),
                Text(destination.label, style: techLabel(fontSize: 13, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CharonColors.steel))),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: CharonColors.surface,
              border: Border.all(color: CharonColors.primaryBright),
            ),
            child: const Icon(LucideIcons.cpu, size: 20, color: CharonColors.primaryBright),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CHARON', style: techLabel(fontSize: 20)),
              const Text(
                'VLESS · REALITY',
                style: TextStyle(
                  fontFamily: CharonFonts.mono,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: CharonColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandCompact extends StatelessWidget {
  const _BrandCompact();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: CharonColors.surface,
            border: Border.all(color: CharonColors.primaryBright),
          ),
          child: const Icon(LucideIcons.cpu, size: 16, color: CharonColors.primaryBright),
        ),
        const SizedBox(width: 8),
        Text('CHARON', style: techLabel(fontSize: 16)),
      ],
    );
  }
}
