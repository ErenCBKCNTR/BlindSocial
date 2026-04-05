import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalErrorLogger {
  static const String _logKey = 'local_error_logs';

  /// Saves an error log locally using SharedPreferences.
  /// This is a synchronous-friendly approach to ensure logs are written
  /// even before an unexpected crash completely kills the app.
  static Future<void> logError(String message, String stackTrace) async {
    try {
      // Note: Native Android/iOS OS-level crashes (e.g. SecurityException from MediaProjection)
      // instantly kill the Dart VM before any asynchronous operations can complete.
      // Thus, SharedPreferences may not catch the very last log if the crash is severe enough.
      // We process this asynchronously, but acknowledge this limitation for OS-level fatal signals.
      final prefs = await SharedPreferences.getInstance();

      final currentLogsStr = prefs.getStringList(_logKey) ?? [];

      final newLog = {
        'timestamp': DateTime.now().toIso8601String(),
        'errorMessage': message,
        'stackTrace': stackTrace,
      };

      // Add the new log at the beginning (newest first)
      currentLogsStr.insert(0, jsonEncode(newLog));

      // Limit to last 100 logs to prevent storage bloat
      if (currentLogsStr.length > 100) {
        currentLogsStr.removeLast();
      }

      await prefs.setStringList(_logKey, currentLogsStr);
    } catch (e) {
      // Intentionally ignoring errors here to avoid infinite loops
      // if SharedPreferences itself crashes.
    }
  }

  /// Retrieves all saved error logs.
  static Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsStr = prefs.getStringList(_logKey) ?? [];

      return logsStr.map((log) => jsonDecode(log) as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  /// Clears all saved error logs.
  static Future<void> clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logKey);
    } catch (e) {
      // Ignored
    }
  }
}
