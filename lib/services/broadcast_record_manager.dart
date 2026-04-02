import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';

class BroadcastRecordManager {
  static const String _prefsKey = 'saved_broadcasts';

  // State
  bool _isRecording = false;
  http.Client? _httpClient;
  StreamSubscription? _streamSubscription;
  File? _currentFile;
  IOSink? _fileSink;
  DateTime? _startTime;

  bool get isRecording => _isRecording;

  Future<void> startRecording(String url, String stationName) async {
    if (_isRecording) return;
    _isRecording = true;
    _startTime = DateTime.now();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = stationName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final timestamp = _startTime!.millisecondsSinceEpoch;
      _currentFile = File('${dir.path}/record_${safeName}_$timestamp.mp3');

      _httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await _httpClient!.send(request);

      // Stream to file using IOSink
      _fileSink = _currentFile!.openWrite();
      _streamSubscription = response.stream.listen(
        (chunk) {
          _fileSink?.add(chunk);
        },
        onDone: () => _finishRecording(stationName),
        onError: (e) {
          _finishRecording(stationName, failed: true);
        },
        cancelOnError: true,
      );
    } catch (e) {
      _isRecording = false;
      _fileSink?.close();
      _fileSink = null;
      _streamSubscription?.cancel();
      _streamSubscription = null;
      _httpClient?.close();
      _httpClient = null;
    }
  }

  Future<Map<String, dynamic>?> stopRecording(String stationName) async {
    if (!_isRecording) return null;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    // Do not close _httpClient here to avoid triggering onError in stream subscription
    return await _finishRecording(stationName);
  }

  Future<Map<String, dynamic>?> _finishRecording(
    String stationName, {
    bool failed = false,
  }) async {
    if (!_isRecording) return null;
    _isRecording = false;
    await _fileSink?.close();
    _fileSink = null;

    // Close http client after file stream is fully closed
    _httpClient?.close();
    _httpClient = null;

    if (failed || _currentFile == null || _startTime == null) {
      if (_currentFile != null && _currentFile!.existsSync()) {
        _currentFile!.deleteSync();
      }
      return null;
    }

    int actualDurationSeconds = 0;

    try {
      final player = AudioPlayer();
      final duration = await player.setFilePath(_currentFile!.path);
      actualDurationSeconds = duration?.inSeconds ?? 0;
      await player.dispose();
    } catch (e) {
      // Fallback to wall-clock time if audio duration extraction fails
      actualDurationSeconds = DateTime.now().difference(_startTime!).inSeconds;
    }

    // Only save if duration > 0 (e.g. at least 1 second)
    if (actualDurationSeconds < 1) {
      if (_currentFile!.existsSync()) {
        _currentFile!.deleteSync();
      }
      return null;
    }

    final recordMeta = {
      'stationName': stationName,
      'filePath': _currentFile!.path,
      'timestamp': _startTime!.millisecondsSinceEpoch,
      'durationInSeconds': actualDurationSeconds,
    };

    await _saveRecordMeta(recordMeta);
    return recordMeta;
  }

  Future<void> _saveRecordMeta(Map<String, dynamic> meta) async {
    final prefs = await SharedPreferences.getInstance();
    final existingData = prefs.getStringList(_prefsKey) ?? [];
    existingData.add(jsonEncode(meta));
    await prefs.setStringList(_prefsKey, existingData);
  }

  Future<List<Map<String, dynamic>>> getSavedRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_prefsKey) ?? [];
    return data
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList()
        .reversed
        .toList();
  }

  Future<void> deleteRecord(String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) {
      file.deleteSync();
    }

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_prefsKey) ?? [];

    final updatedData = data.where((e) {
      final meta = jsonDecode(e) as Map<String, dynamic>;
      return meta['filePath'] != filePath;
    }).toList();

    await prefs.setStringList(_prefsKey, updatedData);
  }
}

// Singleton instance
final broadcastRecordManager = BroadcastRecordManager();
