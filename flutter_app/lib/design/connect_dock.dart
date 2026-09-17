import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'colors.dart';
import 'conn_state.dart';
import 'fonts.dart';

/// Persistent bottom bar for mobile layouts (Milestone 13) — lets the user
/// engage/disengage from any tab without switching to Dashboard first.
/// Desktop has no equivalent; the sidebar already keeps Dashboard one click
/// away. Mirrors `ConnectDock` in the Figma Make reference (`App.tsx`).
class ConnectDock extends StatelessWidget {
  const ConnectDock({super.key, required this.state, required this.onToggle});

  final ConnState state;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final pulsing = state == ConnState.connecting || state == ConnState.reconnecting;
    final color = switch (state) {
      ConnState.connected => CharonColors.primaryBright,
      ConnState.disconnected => CharonColors.steel,
      ConnState.connecting || ConnState.reconnecting => CharonColors.caution,
    };
    final label = switch (state) {
      ConnState.connected => 'DISENGAGE',
      ConnState.disconnected => 'ENGAGE',
      ConnState.connecting || ConnState.reconnecting => 'STANDBY',
    };
    final desc = switch (state) {
      ConnState.connected => 'Tunnel secure · VLESS-Reality',
      ConnState.disconnected => 'Traffic unprotected',
      ConnState.connecting || ConnState.reconnecting => 'Negotiating link…',
    };

    return Container(
      decoration: BoxDecoration(color: CharonColors.surface2, border: Border(top: BorderSide(color: CharonColors.steel))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _GlowDot(color: color, pulsing: pulsing || state == ConnState.connected),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.name.toUpperCase(), style: techLabel(fontSize: 13, color: color)),
                    Text(
                      desc,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: CharonFonts.mono, fontSize: 10, color: CharonColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: pulsing ? null : onToggle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color, width: 2),
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: Icon(LucideIcons.power, size: 16, color: color),
                label: Text(label, style: techLabel(fontSize: 12, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small solid dot with a breathing glow, mirroring the reference's
/// `.glow-pulse` CSS keyframes (opacity 1↔0.55, shadow blur 6↔14px).
class _GlowDot extends StatefulWidget {
  const _GlowDot({required this.color, required this.pulsing});

  final Color color;
  final bool pulsing;

  @override
  State<_GlowDot> createState() => _GlowDotState();
}

class _GlowDotState extends State<_GlowDot> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulsing) return _dot(1, 6);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _dot(1 - _controller.value * 0.45, 6 + _controller.value * 8),
    );
  }

  Widget _dot(double opacity, double blur) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [BoxShadow(color: widget.color, blurRadius: blur)],
        ),
      ),
    );
  }
}
