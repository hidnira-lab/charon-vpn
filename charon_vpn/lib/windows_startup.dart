import 'dart:io';

const _taskName = 'CharonVPN';

/// Registers/removes a Task Scheduler entry (not a registry Run key) so the
/// app launches at logon already elevated, without a UAC prompt on every
/// boot - the TUN adapter needs an elevated process, and a task configured
/// with "run with highest privileges" gets auto-elevated silently for an
/// admin account. Creating that kind of task itself requires the *creating*
/// process to already be elevated, which is fine here since this app always
/// runs as administrator anyway (needed for the TUN adapter regardless).
///
/// Returns an error message on failure (e.g. "Access is denied" if somehow
/// called from a non-elevated process), or null on success.
Future<String?> setLaunchAtStartup(bool enabled) async {
  if (!enabled) {
    await Process.run('schtasks', ['/delete', '/tn', _taskName, '/f']);
    return null;
  }
  final exe = Platform.resolvedExecutable;
  final result = await Process.run('schtasks', [
    '/create',
    '/tn',
    _taskName,
    '/tr',
    '"$exe" --minimized',
    '/sc',
    'onlogon',
    '/rl',
    'highest',
    '/f',
  ]);
  if (result.exitCode == 0) return null;
  final stderr = (result.stderr as String).trim();
  return stderr.isNotEmpty ? stderr : 'schtasks exited with code ${result.exitCode}';
}
