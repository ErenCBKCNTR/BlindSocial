import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class AudioCacheManager {
  static Future<String?> getCachedAudioPath(String url, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      // Remove any invalid characters from filename
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final file = File('${dir.path}/$safeFileName.mp3');

      if (await file.exists()) {
        return file.path;
      }
      return null;
    } catch (e) {
      debugPrint("Error checking cache: $e");
      return null;
    }
  }

  static Future<String?> downloadAudio(String url, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final file = File('${dir.path}/$safeFileName.mp3');

      if (await file.exists()) {
        return file.path; // Already downloaded
      }

      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        final sink = file.openWrite();
        await response.stream.pipe(sink);
        await sink.close();
        return file.path;
      } else {
        debugPrint("Download failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Error downloading audio: $e");
      return null;
    }
  }
}
