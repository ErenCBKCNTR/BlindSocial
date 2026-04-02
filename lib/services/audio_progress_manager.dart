import 'package:shared_preferences/shared_preferences.dart';

class AudioProgressManager {
  static const String _prefix = 'audio_progress_';

  // Save the current playback position in milliseconds
  static Future<void> saveProgress(String id, Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$id', position.inMilliseconds);
  }

  // Load the saved playback position
  static Future<Duration> getProgress(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('$_prefix$id');
    return millis != null ? Duration(milliseconds: millis) : Duration.zero;
  }

  // Clear the saved playback position
  static Future<void> clearProgress(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$id');
  }

  // Load the saved playback position for multiple items efficiently
  static Future<Map<String, Duration>> getMultipleProgress(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Duration> results = {};
    for (final id in ids) {
      final millis = prefs.getInt('$_prefix$id');
      results[id] = millis != null ? Duration(milliseconds: millis) : Duration.zero;
    }
    return results;
  }
}
