import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Tracks bytes relayed through the tunnel against the server's monthly
/// quota. Samples arrive as a cumulative counter that resets only on a full
/// app restart (see `AppEvent::TrafficSample` in charon-core) - this store
/// turns that into a running total that survives app restarts within the
/// same calendar month, and rolls over to zero at the start of a new month.
class TrafficStore {
  static const _fileName = 'traffic_usage.json';
  static const _saveInterval = Duration(seconds: 10);

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  String? _month;
  int _txBytes = 0;
  int _rxBytes = 0;
  int? _lastSeenTx;
  int? _lastSeenRx;
  bool _loaded = false;
  DateTime? _lastSave;

  static String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final file = await _file();
    if (!await file.exists()) return;
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _month = data['month'] as String?;
      _txBytes = data['txBytes'] as int? ?? 0;
      _rxBytes = data['rxBytes'] as int? ?? 0;
    } catch (_) {
      // Corrupt file - start fresh rather than blocking telemetry entirely.
    }
  }

  /// Current month's running totals, without waiting for a new sample -
  /// used to show a real number on first load, before the tunnel connects.
  Future<(int, int)> loadTotals() async {
    await _ensureLoaded();
    if (_month != _currentMonth()) return (0, 0);
    return (_txBytes, _rxBytes);
  }

  /// Feeds a new cumulative sample from `CharonEvent.trafficSample`, returns
  /// the running (txBytes, rxBytes) total for the current month.
  Future<(int, int)> recordSample(int cumulativeTx, int cumulativeRx) async {
    await _ensureLoaded();
    final month = _currentMonth();
    if (_month != month) {
      _month = month;
      _txBytes = 0;
      _rxBytes = 0;
      _lastSeenTx = null;
      _lastSeenRx = null;
    }
    // A smaller cumulative value than last seen means the process restarted
    // (tun2proxy's own counter resets to zero) - treat the new value itself
    // as the delta instead of going negative.
    final lastTx = _lastSeenTx;
    final lastRx = _lastSeenRx;
    final deltaTx = (lastTx == null || cumulativeTx < lastTx) ? cumulativeTx : cumulativeTx - lastTx;
    final deltaRx = (lastRx == null || cumulativeRx < lastRx) ? cumulativeRx : cumulativeRx - lastRx;
    _txBytes += deltaTx;
    _rxBytes += deltaRx;
    _lastSeenTx = cumulativeTx;
    _lastSeenRx = cumulativeRx;

    final now = DateTime.now();
    if (_lastSave == null || now.difference(_lastSave!) >= _saveInterval) {
      _lastSave = now;
      await _save();
    }
    return (_txBytes, _rxBytes);
  }

  Future<void> _save() async {
    final file = await _file();
    await file.writeAsString(jsonEncode({'month': _month, 'txBytes': _txBytes, 'rxBytes': _rxBytes}));
  }
}
