import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'radio_proxy_server.dart';

class BroadcastRecordManager {
  static const String _prefsKey = 'saved_broadcasts';

  // State
  bool _isRecording = false;
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

      _fileSink = _currentFile!.openWrite();

      // Tell proxy to forward chunks to our file sink
      radioProxyServer.startRecording(_fileSink!);

    } catch (e) {
      _isRecording = false;
      await _fileSink?.close();
      _fileSink = null;
    }
  }

  Future<Map<String, dynamic>?> stopRecording(String stationName) async {
    if (!_isRecording) return null;

    // Stop receiving chunks from proxy instantly
    radioProxyServer.stopRecording();

    return await _finishRecording(stationName);
  }

  Future<Map<String, dynamic>?> _finishRecording(
    String stationName, {
    bool failed = false,
  }) async {
    if (!_isRecording) return null;
    _isRecording = false;

    // Anında durdurup veriyi dosyaya yazıp sink'i kapatıyoruz
    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;

    if (failed || _currentFile == null || _startTime == null) {
      if (_currentFile != null && _currentFile!.existsSync()) {
        _currentFile!.deleteSync();
      }
      return null;
    }

    final wallClockDuration = DateTime.now().difference(_startTime!).inSeconds;

    // Because the proxy fetches the historical burst BEFORE startRecording is called,
    // the bytes written to the file are ONLY those received during the wallClockDuration.
    // Therefore, no mathematical trimming is needed anymore!
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
