import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:blind_social/services/audio_cache_manager.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String path;
  FakePathProviderPlatform(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return path;
  }
}

void main() {
  late Directory tempDir;
  late HttpServer mockServer;
  late String mockServerUrl;

  setUpAll(() async {
    mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    mockServerUrl = 'http://${mockServer.address.address}:${mockServer.port}';

    mockServer.listen((HttpRequest request) {
      if (request.uri.path == '/success.mp3') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('mock audio data')
          ..close();
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      }
    });
  });

  tearDownAll(() async {
    await mockServer.close();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audio_cache_test');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('AudioCacheManager', () {
    test('getCachedAudioPath returns path if file exists', () async {
      final safeFileName = 'test_audio';
      final file = File('${tempDir.path}/$safeFileName.mp3');
      await file.writeAsString('dummy content');

      final path = await AudioCacheManager.getCachedAudioPath('http://dummy.url', 'test audio!');
      expect(path, file.path);
    });

    test('getCachedAudioPath returns null if file does not exist', () async {
      final path = await AudioCacheManager.getCachedAudioPath('http://dummy.url', 'nonexistent');
      expect(path, isNull);
    });

    test('deleteAudio returns true and deletes file if it exists', () async {
      final safeFileName = 'to_delete';
      final file = File('${tempDir.path}/$safeFileName.mp3');
      await file.writeAsString('dummy content');
      expect(await file.exists(), isTrue);

      final result = await AudioCacheManager.deleteAudio('http://dummy.url', 'to delete');
      expect(result, isTrue);
      expect(await file.exists(), isFalse);
    });

    test('deleteAudio returns false if file does not exist', () async {
      final result = await AudioCacheManager.deleteAudio('http://dummy.url', 'nonexistent');
      expect(result, isFalse);
    });

    test('getDownloadedFiles returns list of downloaded mp3s', () async {
      await File('${tempDir.path}/file_one.mp3').writeAsString('1');
      await File('${tempDir.path}/file_two.mp3').writeAsString('2');
      await File('${tempDir.path}/not_audio.txt').writeAsString('3');

      final files = await AudioCacheManager.getDownloadedFiles();
      expect(files.length, 2);

      final titles = files.map((e) => e['title']).toList();
      expect(titles, containsAll(['file one', 'file two']));

      final paths = files.map((e) => e['localPath']).toList();
      expect(paths, containsAll([
        '${tempDir.path}/file_one.mp3',
        '${tempDir.path}/file_two.mp3',
      ]));
    });

    test('downloadAudio returns existing file path if already downloaded', () async {
      final safeFileName = 'existing';
      final file = File('${tempDir.path}/$safeFileName.mp3');
      await file.writeAsString('dummy content');

      final path = await AudioCacheManager.downloadAudio('$mockServerUrl/success.mp3', 'existing');
      expect(path, file.path);
    });

    test('downloadAudio downloads and returns path on success', () async {
      final safeFileName = 'new_download';
      final file = File('${tempDir.path}/$safeFileName.mp3');
      expect(await file.exists(), isFalse);

      final path = await AudioCacheManager.downloadAudio('$mockServerUrl/success.mp3', 'new download');
      expect(path, file.path);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), 'mock audio data');
    });

    test('downloadAudio returns null on failure', () async {
      final path = await AudioCacheManager.downloadAudio('$mockServerUrl/fail.mp3', 'fail download');
      expect(path, isNull);
    });
  });
}
