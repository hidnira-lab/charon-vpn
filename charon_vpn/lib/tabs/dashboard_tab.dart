import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/design.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.state,
    required this.blocked,
    required this.hasProfile,
    required this.activeProfileName,
    required this.activeProfileIp,
    required this.sessionLabel,
    required this.downMbps,
    required this.upMbps,
    required this.latencyMs,
    required this.onToggle,
  });

  final ConnState state;
  final bool blocked;
  final bool hasProfile;
  final String? activeProfileName;
  final String? activeProfileIp;
  final String sessionLabel;
  final double downMbps;
  final double upMbps;
  final int? latencyMs;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final connected = state == ConnState.connected;
    final pulsing = state == ConnState.connecting || state == ConnState.reconnecting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            index: '01',
            title: 'Control Deck',
            desc: 'Primary tunnel command. Blue signals a secure, active link.',
          ),
          const SizedBox(height: 24),
          if (!hasProfile) ...[
            HazardBanner(
              tone: HazardTone.caution,
              child: const Text('NO SERVER PROFILE SELECTED — OPEN NODES TO ADD ONE'),
            ),
            const SizedBox(height: 24),
          ],
          // Diverges from the Figma Make reference on purpose: our kill
          // switch only actually blocks egress after xray crashes while the
          // TUN adapter survives, never while merely idle/disconnected —
          // showing this banner in the idle case would be a false safety
          // claim (see CLAUDE.md "Milestone 8" notes).
          if (blocked) ...[
            HazardBanner(
              tone: HazardTone.critical,
              child: const Text('KILL SWITCH ACTIVE — INTERNET BLOCKED UNTIL XRAY RECONNECTS'),
            ),
            const SizedBox(height: 24),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final power = _PowerPlate(state: state, pulsing: pulsing, onToggle: onToggle);
              final info = _InfoColumn(
                connected: connected,
                activeProfileName: activeProfileName,
                activeProfileIp: activeProfileIp,
                sessionLabel: sessionLabel,
                downMbps: downMbps,
                upMbps: upMbps,
                latencyMs: latencyMs,
              );
              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: power),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: info),
                  ],
                );
              }
              return Column(children: [power, const SizedBox(height: 24), info]);
            },
          ),
        ],
      ),
    );
  }
}

class _StateMeta {
  const _StateMeta(this.color, this.label, this.sub, this.action);

  final Color color;
  final String label;
  final String sub;
  final String action;
}

_StateMeta _stateMeta(ConnState state) => switch (state) {
      ConnState.connected => const _StateMeta(CharonColors.primaryBright, 'CONNECTED', 'Tunnel secure', 'DISENGAGE'),
      ConnState.connecting =>
        _StateMeta(CharonColors.caution, 'CONNECTING', 'Negotiating VLESS-Reality…', 'STANDBY'),
      ConnState.reconnecting =>
        _StateMeta(CharonColors.caution, 'RECONNECTING', 'Link dropped — restoring', 'STANDBY'),
      ConnState.disconnected =>
        _StateMeta(CharonColors.steel, 'DISCONNECTED', 'Traffic unprotected', 'ENGAGE'),
    };

class _PowerPlate extends StatelessWidget {
  const _PowerPlate({required this.state, required this.pulsing, required this.onToggle});

  final ConnState state;
  final bool pulsing;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final meta = _stateMeta(state);
    return UnitPlate(
      code: 'PWR-00',
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (pulsing || state == ConnState.connected) _PulseRing(color: meta.color),
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: pulsing ? null : onToggle,
                    child: Container(
                      width: 128,
                      height: 128,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CharonColors.surface2,
                        border: Border.all(color: meta.color, width: 2),
                        boxShadow: state == ConnState.connected
                            ? [BoxShadow(color: meta.color.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: -8)]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.power, size: 40, color: meta.color),
                          const SizedBox(height: 6),
                          Text(meta.action, style: techLabel(fontSize: 11, color: meta.color)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(meta.label, style: techLabel(fontSize: 20, color: meta.color)),
          const SizedBox(height: 4),
          Text(
            meta.sub,
            style: TextStyle(fontFamily: CharonFonts.mono, fontSize: 11, color: CharonColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.color});

  final Color color;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Opacity(
          opacity: (1 - t) * 0.6,
          child: Transform.scale(
            scale: 0.8 + t * 0.7,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color, width: 2)),
            ),
          ),
        );
      },
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.connected,
    required this.activeProfileName,
    required this.activeProfileIp,
    required this.sessionLabel,
    required this.downMbps,
    required this.upMbps,
    required this.latencyMs,
  });

  final bool connected;
  final String? activeProfileName;
  final String? activeProfileIp;
  final String sessionLabel;
  final double downMbps;
  final double upMbps;
  final int? latencyMs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UnitPlate(
          code: 'LNK-01',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.activity, size: 16, color: CharonColors.primaryBright),
                  const SizedBox(width: 8),
                  Text('LINK TELEMETRY', style: techLabel(fontSize: 13, color: CharonColors.muted)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 28,
                runSpacing: 16,
                children: [
                  Readout(
                    label: 'Egress IP',
                    value: connected ? (activeProfileIp ?? '—') : '—',
                    tone: ReadoutTone.primary,
                  ),
                  Readout(label: 'Session', value: connected ? sessionLabel : '00:00:00'),
                  Readout(label: 'Protocol', value: 'VLESS', unit: 'Reality'),
                  Readout(
                    label: 'Latency',
                    value: connected && latencyMs != null ? '$latencyMs' : '—',
                    unit: 'ms',
                  ),
                  Readout(
                    label: 'Down',
                    value: connected ? downMbps.toStringAsFixed(1) : '—',
                    unit: 'Mbps',
                  ),
                  Readout(
                    label: 'Up',
                    value: connected ? upMbps.toStringAsFixed(1) : '—',
                    unit: 'Mbps',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        UnitPlate(
          code: 'SRV-02',
          active: true,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: CharonColors.surface2, border: Border.all(color: CharonColors.steel)),
                child: const Icon(LucideIcons.server, color: CharonColors.primaryBright),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activeProfileName ?? 'No profile selected', style: techLabel(fontSize: 16)),
                    if (activeProfileIp != null)
                      Text(
                        activeProfileIp!,
                        style: TextStyle(fontFamily: CharonFonts.mono, fontSize: 11, color: CharonColors.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
