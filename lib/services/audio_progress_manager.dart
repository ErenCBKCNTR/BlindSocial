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
}
