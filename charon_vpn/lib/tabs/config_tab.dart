import 'package:flutter/material.dart';

import '../design/design.dart';

/// Restyled per Milestone 6.4, light mode toggle added in Milestone 13. Only
/// "Auto-connect on launch" and "Light mode" are wired to real behavior —
/// the other three rows mirror the reference layout but have no logic
/// behind them (notifications/launch-at-startup/telemetry aren't
/// implemented); the caption below says so explicitly.
class ConfigTab extends StatefulWidget {
  const ConfigTab({
    super.key,
    required this.autoConnect,
    required this.onAutoConnectChanged,
    required this.lightMode,
    required this.onLightModeChanged,
  });

  final bool autoConnect;
  final ValueChanged<bool> onAutoConnectChanged;
  final bool lightMode;
  final ValueChanged<bool> onLightModeChanged;

  @override
  State<ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends State<ConfigTab> {
  bool _notify = true;
  bool _launchAtStartup = false;
  bool _telemetry = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(index: '07', title: 'Settings', desc: 'General preferences.'),
          const SizedBox(height: 24),
          UnitPlate(
            code: 'CFG-00',
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingRow(
                  title: 'Auto-connect on launch',
                  desc: 'Start xray + tunnel automatically when the app opens.',
                  value: widget.autoConnect,
                  onChanged: widget.onAutoConnectChanged,
                ),
                Divider(height: 1, color: CharonColors.steel),
                _SettingRow(
                  title: 'Light mode',
                  desc: 'Switch the console palette from dark to light.',
                  value: widget.lightMode,
                  onChanged: widget.onLightModeChanged,
                ),
                Divider(height: 1, color: CharonColors.steel),
                _SettingRow(
                  title: 'Desktop notifications',
                  desc: 'Alert on connect, drop, and reconnect events.',
                  value: _notify,
                  onChanged: (v) => setState(() => _notify = v),
                ),
                Divider(height: 1, color: CharonColors.steel),
                _SettingRow(
                  title: 'Launch at startup',
                  desc: 'Start Charon minimized when the system boots.',
                  value: _launchAtStartup,
                  onChanged: (v) => setState(() => _launchAtStartup = v),
                ),
                Divider(height: 1, color: CharonColors.steel),
                _SettingRow(
                  title: 'Anonymous telemetry',
                  desc: 'Share aggregated diagnostics to improve routing.',
                  value: _telemetry,
                  onChanged: (v) => setState(() => _telemetry = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Notifications, launch-at-startup, and telemetry are placeholders — not wired up yet.',
            style: TextStyle(color: CharonColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text(
            'Charon VPN · xray-core (bundled)',
            style: TextStyle(fontFamily: CharonFonts.mono, fontSize: 11, color: CharonColors.muted),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.title, required this.desc, required this.value, required this.onChanged});

  final String title;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CharonColors.foreground),
                ),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 13, color: CharonColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          RockerToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
