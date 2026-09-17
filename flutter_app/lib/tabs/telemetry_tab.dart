import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/design.dart';

/// Restyled per Milestone 6.6, wired to real totals in Milestone 12. "Total
/// Down"/"Total Up" are the current calendar month's running totals from
/// `TrafficStore` (persisted, survives app restart, resets each month) -
/// "Uptime"/"Sessions" stay placeholders, that's session-history tracking
/// nobody asked for yet. The historical chart is still not implemented
/// (needs a time-series buffer + a real chart widget, out of scope for
/// Milestone 12's "live numbers" ask) - only the instant readouts landed.
/// Log console (relocated from Milestone 6.1) lives below, unchanged.
class TelemetryTab extends StatelessWidget {
  const TelemetryTab({
    super.key,
    required this.logs,
    required this.scrollController,
    required this.monthlyTxBytes,
    required this.monthlyRxBytes,
  });

  final List<String> logs;
  final ScrollController scrollController;
  final int monthlyTxBytes;
  final int monthlyRxBytes;

  static const _quotaGb = 1200;

  String _formatGb(int bytes) => (bytes / 1e9).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final totalGb = (monthlyTxBytes + monthlyRxBytes) / 1e9;
    final quotaPct = (totalGb / _quotaGb * 100).clamp(0, 999);
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
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(label: 'Total Down', unit: 'GB', value: _formatGb(monthlyRxBytes)),
                    _StatCard(label: 'Total Up', unit: 'GB', value: _formatGb(monthlyTxBytes)),
                    const _StatCard(label: 'Uptime', unit: '%'),
                    const _StatCard(label: 'Sessions', unit: ''),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Bulan ini: ${totalGb.toStringAsFixed(2)} GB / $_quotaGb GB kuota '
                  '(${quotaPct.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontFamily: CharonFonts.mono, fontSize: 12, color: CharonColors.muted),
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
                        'Chart belum tersedia — total & live throughput udah real (lihat stat card di atas '
                        'dan Dashboard), grafik historis-nya sendiri belum digarap.',
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
  const _StatCard({required this.label, required this.unit, this.value = '—'});

  final String label;
  final String unit;
  final String value;

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
                Text(
                  value,
                  style: const TextStyle(fontFamily: CharonFonts.mono, fontSize: 22, color: CharonColors.primaryBright),
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
