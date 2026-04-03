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

    final wallClockDuration = DateTime.now().difference(_startTime!).inSeconds;
    int audioFileDurationSeconds = 0;

    try {
      final player = AudioPlayer();
      final duration = await player.setFilePath(_currentFile!.path);
      audioFileDurationSeconds = duration?.inSeconds ?? 0;
      await player.dispose();
    } catch (e) {
      audioFileDurationSeconds = wallClockDuration;
    }

    // If the audio file duration is significantly larger than the wall clock duration,
    // it implies an initial historical burst buffer was downloaded. We trim it mathematically.
    if (audioFileDurationSeconds > wallClockDuration && wallClockDuration > 0) {
      try {
        final fileSize = await _currentFile!.length();
        final bytesPerSecond = fileSize / audioFileDurationSeconds;
        final durationToTrim = audioFileDurationSeconds - wallClockDuration;
        final bytesToTrim = (bytesPerSecond * durationToTrim).toInt();

        if (bytesToTrim < fileSize && bytesToTrim > 0) {
          final tempFile = File('${_currentFile!.path}.tmp');
          final sink = tempFile.openWrite();
          await _currentFile!.openRead(bytesToTrim).pipe(sink);
          await sink.close();
          await tempFile.rename(_currentFile!.path);
        }
      } catch (e) {
        // Ignore trimming errors
      }
    }

    int finalDuration = wallClockDuration;

    // Only save if duration > 0 (e.g. at least 1 second)
    if (finalDuration < 1) {
      if (_currentFile!.existsSync()) {
        _currentFile!.deleteSync();
      }
      return null;
    }

    final recordMeta = {
      'stationName': stationName,
      'filePath': _currentFile!.path,
      'timestamp': _startTime!.millisecondsSinceEpoch,
      'durationInSeconds': finalDuration,
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
