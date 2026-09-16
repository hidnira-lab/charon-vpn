import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/design.dart';

/// Restyled per Milestone 6.6. Traffic stats/chart are placeholders — the
/// FFI plumbing for real throughput numbers was explicitly deferred back in
/// Milestone 10 (see CLAUDE.md). Log console (relocated from Milestone 6.1)
/// lives below, unchanged in behavior.
class TelemetryTab extends StatelessWidget {
  const TelemetryTab({super.key, required this.logs, required this.scrollController});

  final List<String> logs;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  index: '05',
                  title: 'Telemetry',
                  desc: '24-hour throughput and session diagnostics.',
                ),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(label: 'Total Down', unit: 'GB'),
                    _StatCard(label: 'Total Up', unit: 'GB'),
                    _StatCard(label: 'Uptime', unit: '%'),
                    _StatCard(label: 'Sessions', unit: ''),
                  ],
                ),
                const SizedBox(height: 12),
                UnitPlate(
                  code: 'GRF-01',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.activity, size: 16, color: CharonColors.primaryBright),
                          const SizedBox(width: 8),
                          Text('THROUGHPUT / 24H', style: techLabel(fontSize: 13, color: CharonColors.muted)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Chart belum tersedia — nunggu Milestone 10 (traffic stats) yang sebelumnya '
                        'di-defer.',
                        style: TextStyle(color: CharonColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(LucideIcons.terminal, size: 16, color: CharonColors.primaryBright),
                    const SizedBox(width: 8),
                    Text('DEBUG LOG', style: techLabel(fontSize: 13, color: CharonColors.muted)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black87, border: Border.all(color: CharonColors.steel)),
              child: ListView.builder(
                controller: scrollController,
                itemCount: logs.length,
                itemBuilder: (context, i) => Text(
                  logs[i],
                  style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.unit});

  final String label;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: UnitPlate(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(), style: techLabel(fontSize: 10, color: CharonColors.muted)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  '—',
                  style: TextStyle(fontFamily: CharonFonts.mono, fontSize: 22, color: CharonColors.primaryBright),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(unit, style: const TextStyle(fontFamily: CharonFonts.mono, fontSize: 12, color: CharonColors.muted)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
