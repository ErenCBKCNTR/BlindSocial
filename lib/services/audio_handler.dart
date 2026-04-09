import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'radio_proxy_server.dart';

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ));
    });
  }

  AudioPlayer get player => _player;

  @override
  Future<void> play() async {
    final currentId = mediaItem.value?.id;
    if (currentId != null && currentId.startsWith('http') && !currentId.startsWith('http://127.0.0.1')) {
      // It's a remote URL, start proxy
      await radioProxyServer.start(currentId);
      final proxyUrl = 'http://127.0.0.1:${radioProxyServer.port}';
      // We must only update the player's URL, not the MediaItem's ID
      // To prevent re-fetching unnecessarily, check if it's already set to proxyUrl
      if (_player.playing) {
          // Already playing
      } else {
          try {
             await _player.setUrl(proxyUrl);
          } catch (e) {
             // Ignore
          }
      }
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  Future<void> setUrl(String url, {MediaItem? mediaItem}) async {
    if (mediaItem != null) {
      this.mediaItem.add(mediaItem);
    }

    // Check if it's a remote URL to proxy
    if (url.startsWith('http') && !url.startsWith('http://127.0.0.1')) {
       await radioProxyServer.start(url);
       final proxyUrl = 'http://127.0.0.1:${radioProxyServer.port}';
       await _player.setUrl(proxyUrl);
    } else {
       await _player.setUrl(url);
    }
  }

  Future<void> setFilePath(String path, {MediaItem? mediaItem}) async {
    if (mediaItem != null) {
      this.mediaItem.add(mediaItem);
    }
    await _player.setFilePath(path);
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'rewind') {
      final newPosition = _player.position - const Duration(seconds: 10);
      _player.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
    } else if (name == 'fastForward') {
      final newPosition = _player.position + const Duration(seconds: 10);
      final duration = _player.duration ?? Duration.zero;
      _player.seek(newPosition > duration ? duration : newPosition);
    }
    super.customAction(name, extras);
  }

  @override
  Future<void> rewind() async {
    await customAction('rewind');
  }

  @override
  Future<void> fastForward() async {
    await customAction('fastForward');
  }
}

late MyAudioHandler audioHandler;

Future<MyAudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.cabukcan.blindsocial.audio',
      androidNotificationChannelName: 'Audio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
