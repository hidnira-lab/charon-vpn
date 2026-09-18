import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/design.dart';

/// Restyled per Milestone 6.6, wired to real totals in Milestone 12, chart
/// wired to a real (session-only) throughput history in Milestone 15.
/// "Total Down"/"Total Up" are the current calendar month's running totals
/// from `TrafficStore` (persisted, survives app restart, resets each month).
/// "Uptime"/"Sessions" stay placeholders, that's session-history tracking
/// nobody asked for yet. `downHistory`/`upHistory` are a rolling in-memory
/// window (not a real 24h history - that'd mean persisting 86400 one-second
/// samples across restarts, nobody asked for that either), reset whenever
/// the tunnel disconnects, same lifetime as the live Mbps readouts.
/// Log console (relocated from Milestone 6.1) lives below, unchanged.
class TelemetryTab extends StatelessWidget {
  const TelemetryTab({
    super.key,
    required this.logs,
    required this.scrollController,
    required this.monthlyTxBytes,
    required this.monthlyRxBytes,
    required this.downHistory,
    required this.upHistory,
  });

  final List<String> logs;
  final ScrollController scrollController;
  final int monthlyTxBytes;
  final int monthlyRxBytes;
  final List<double> downHistory;
  final List<double> upHistory;

  static const _quotaGb = 1200;

  String _formatGb(int bytes) => (bytes / 1e9).toStringAsFixed(2);

  void _copyLogs(BuildContext context) {
    Clipboard.setData(ClipboardData(text: logs.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log disalin ke clipboard.')),
    );
  }

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
                SectionHeader(
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
                  style: TextStyle(fontFamily: CharonFonts.mono, fontSize: 12, color: CharonColors.muted),
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
                          Text('THROUGHPUT / SESSION', style: techLabel(fontSize: 13, color: CharonColors.muted)),
                          const Spacer(),
                          _LegendDot(color: CharonColors.primaryBright, label: 'Down'),
                          const SizedBox(width: 12),
                          _LegendDot(color: CharonColors.caution, label: 'Up'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ThroughputChart(downHistory: downHistory, upHistory: upHistory),
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
                    const Spacer(),
                    IconButton(
                      icon: Icon(LucideIcons.copy, size: 16, color: CharonColors.muted),
                      tooltip: 'Copy semua log',
                      visualDensity: VisualDensity.compact,
                      onPressed: logs.isEmpty ? null : () => _copyLogs(context),
                    ),
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontFamily: CharonFonts.mono, fontSize: 11, color: CharonColors.muted)),
      ],
    );
  }
}

class _ThroughputChart extends StatelessWidget {
  const _ThroughputChart({required this.downHistory, required this.upHistory});

  final List<double> downHistory;
  final List<double> upHistory;

  List<FlSpot> _spots(List<double> history) => [
        for (var i = 0; i < history.length; i++) FlSpot(i.toDouble(), history[i]),
      ];

  @override
  Widget build(BuildContext context) {
    if (downHistory.isEmpty && upHistory.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'Belum ada data — connect dulu buat mulai ngumpulin throughput sesi ini.',
            style: TextStyle(color: CharonColors.muted, fontSize: 12),
          ),
        ),
      );
    }
    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: CharonColors.steel, strokeWidth: 1),
          ),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: _spots(downHistory),
              color: CharonColors.primaryBright,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: CharonColors.primaryBright.withValues(alpha: 0.15)),
            ),
            LineChartBarData(
              spots: _spots(upHistory),
              color: CharonColors.caution,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
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
                  Text(unit, style: TextStyle(fontFamily: CharonFonts.mono, fontSize: 12, color: CharonColors.muted)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
