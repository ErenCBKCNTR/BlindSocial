import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_social/services/audio_progress_manager.dart';

void main() {
  test('Benchmark audio progress', () async {
    SharedPreferences.setMockInitialValues({
      for (var i = 0; i < 1000; i++) 'audio_progress_url_$i': i * 1000,
    });

    // Warmup
    await AudioProgressManager.getProgress('url_0');

    final watchSequential = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      await AudioProgressManager.getProgress('url_$i');
    }
    watchSequential.stop();
    print('Sequential time: ${watchSequential.elapsedMicroseconds} us');

    // Warmup 2
    final prefs = await SharedPreferences.getInstance();

    final watchBatch = Stopwatch()..start();
    final Map<String, Duration> result = {};
    for (var i = 0; i < 1000; i++) {
      final id = 'url_$i';
      final millis = prefs.getInt('audio_progress_$id');
      result[id] = millis != null ? Duration(milliseconds: millis) : Duration.zero;
    }
    watchBatch.stop();
    print('Batch time: ${watchBatch.elapsedMicroseconds} us');
  });
}
