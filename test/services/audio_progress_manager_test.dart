import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_social/services/audio_progress_manager.dart';

void main() {
  setUp(() {
    // Isolate storage state and ensure deterministic behavior before each test
    SharedPreferences.setMockInitialValues({});
  });

  group('AudioProgressManager', () {
    const testId = 'test_audio_123';

    test('getProgress returns Duration.zero when no progress is saved', () async {
      final progress = await AudioProgressManager.getProgress(testId);
      expect(progress, Duration.zero);
    });

    test('saveProgress saves the progress correctly', () async {
      const positionToSave = Duration(milliseconds: 15000); // 15 seconds

      await AudioProgressManager.saveProgress(testId, positionToSave);

      final savedProgress = await AudioProgressManager.getProgress(testId);
      expect(savedProgress, positionToSave);

      // Verify internal state using SharedPreferences directly to be thorough
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('audio_progress_$testId'), 15000);
    });

    test('saveProgress overwrites existing progress', () async {
      const initialPosition = Duration(milliseconds: 5000);
      const newPosition = Duration(milliseconds: 25000);

      await AudioProgressManager.saveProgress(testId, initialPosition);
      final firstProgress = await AudioProgressManager.getProgress(testId);
      expect(firstProgress, initialPosition);

      await AudioProgressManager.saveProgress(testId, newPosition);
      final updatedProgress = await AudioProgressManager.getProgress(testId);
      expect(updatedProgress, newPosition);
    });

    test('clearProgress removes the saved progress', () async {
      const positionToSave = Duration(milliseconds: 10000);
      await AudioProgressManager.saveProgress(testId, positionToSave);

      // Verify it was saved
      final savedProgress = await AudioProgressManager.getProgress(testId);
      expect(savedProgress, positionToSave);

      // Clear it
      await AudioProgressManager.clearProgress(testId);

      // Verify it fell back to Duration.zero
      final clearedProgress = await AudioProgressManager.getProgress(testId);
      expect(clearedProgress, Duration.zero);

      // Verify internal state
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('audio_progress_$testId'), isFalse);
    });
  });
}
