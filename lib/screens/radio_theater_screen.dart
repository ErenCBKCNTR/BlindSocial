import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/audio_handler.dart';

class RadioTheaterScreen extends StatefulWidget {
  const RadioTheaterScreen({super.key});

  @override
  State<RadioTheaterScreen> createState() => _RadioTheaterScreenState();
}

class _RadioTheaterScreenState extends State<RadioTheaterScreen> {
  final yt = YoutubeExplode();
  final String videoUrl = 'https://youtu.be/fXoTvUoZcBw?si=lahsgn9pTwbR7tga';

  bool isLoading = true;
  String videoTitle = 'Radyo Tiyatrosu Yükleniyor...';
  String? audioUrl;
  VideoId? videoId;

  bool isDownloading = false;
  bool isDownloaded = false;
  double downloadProgress = 0.0;
  String? localFilePath;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      videoId = VideoId(videoUrl);
      var video = await yt.videos.get(videoId!);
      var manifest = await yt.videos.streamsClient.getManifest(videoId!);
      StreamInfo audioStreamInfo;
      try {
        audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      } catch (e) {
        audioStreamInfo = manifest.muxed.withHighestBitrate();
      }

      final dir = await getApplicationDocumentsDirectory();
      localFilePath = '${dir.path}/${videoId!.value}.m4a';

      final file = File(localFilePath!);
      bool fileExists = await file.exists();

      if (mounted) {
        setState(() {
          videoTitle = video.title;
          audioUrl = audioStreamInfo.url.toString();
          isDownloaded = fileExists;
          isLoading = false;
        });
      }

      final item = MediaItem(
        id: audioUrl!,
        title: video.title,
        artist: 'Blind Social',
        artUri: Uri.parse('https://img.youtube.com/vi/${videoId!.value}/0.jpg'),
      );

      if (fileExists) {
        await audioHandler.setFilePath(localFilePath!, mediaItem: item);
      } else {
        await audioHandler.setUrl(audioUrl!, mediaItem: item);
      }
    } catch (e) {
      debugPrint("Error fetching YouTube info: $e");
      if (mounted) {
        setState(() {
          videoTitle = 'Hata: Video bilgisi alınamadı.';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleDownload() async {
    if (localFilePath == null || audioUrl == null) return;

    final file = File(localFilePath!);

    if (isDownloaded) {
      await file.delete();
      setState(() {
        isDownloaded = false;
        downloadProgress = 0.0;
      });
      final item = MediaItem(
        id: audioUrl!,
        title: videoTitle,
        artist: 'Blind Social',
      );
      await audioHandler.setUrl(audioUrl!, mediaItem: item); // Switch back to streaming
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya cihazdan silindi. Çevrimiçi dinlemeye dönüldü.')),
        );
      }
    } else {
      setState(() {
        isDownloading = true;
      });

      try {
        final request = http.Request('GET', Uri.parse(audioUrl!));
        final response = await http.Client().send(request);

        final contentLength = response.contentLength;
        int bytesDownloaded = 0;

        final sink = file.openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          bytesDownloaded += chunk.length;
          if (contentLength != null && mounted) {
            setState(() {
              downloadProgress = bytesDownloaded / contentLength;
            });
          }
        }
        await sink.close();

        setState(() {
          isDownloaded = true;
          isDownloading = false;
        });

        // Switch to playing from local file
        final currentPosition = audioHandler.player.position;
        final playing = audioHandler.player.playing;

        final item = MediaItem(
          id: localFilePath!,
          title: videoTitle,
          artist: 'Blind Social',
        );

        await audioHandler.setFilePath(localFilePath!, mediaItem: item);
        await audioHandler.seek(currentPosition);
        if (playing) await audioHandler.play();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İndirme tamamlandı! Artık çevrimdışı dinleyebilirsiniz.')),
          );
        }
      } catch (e) {
        debugPrint("Download error: $e");
        setState(() {
          isDownloading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İndirme sırasında bir hata oluştu.')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    yt.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Radyo Tiyatrosu')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.radio,
                    size: 100,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    videoTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (isDownloaded)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.offline_pin, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Çevrimdışı Dinleniyor',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  const SizedBox(height: 40),
                  StreamBuilder<Duration>(
                    stream: audioHandler.player.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final duration = audioHandler.player.duration ?? Duration.zero;

                      return Column(
                        children: [
                          Slider(
                            value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble()),
                            max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                            onChanged: (value) {
                              audioHandler.seek(Duration(milliseconds: value.round()));
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position)),
                              Text(_formatDuration(duration)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Semantics(
                        label: '10 saniye geri sar',
                        button: true,
                        child: IconButton(
                          iconSize: 50,
                          icon: const Icon(Icons.replay_10),
                          color: Theme.of(context).colorScheme.secondary,
                          onPressed: () {
                            audioHandler.rewind();
                          },
                        ),
                      ),
                      StreamBuilder<PlaybackState>(
                        stream: audioHandler.playbackState,
                        builder: (context, snapshot) {
                          final state = snapshot.data;
                          final playing = state?.playing ?? false;
                          final processingState = state?.processingState ?? AudioProcessingState.idle;

                          if (processingState == AudioProcessingState.loading ||
                              processingState == AudioProcessingState.buffering) {
                            return Container(
                              margin: const EdgeInsets.all(8.0),
                              width: 64.0,
                              height: 64.0,
                              child: const CircularProgressIndicator(),
                            );
                          } else if (!playing) {
                            return Semantics(
                              label: 'Oynat',
                              button: true,
                              child: IconButton(
                                icon: const Icon(Icons.play_circle_filled),
                                iconSize: 80,
                                color: Theme.of(context).colorScheme.primary,
                                onPressed: audioHandler.play,
                              ),
                            );
                          } else if (processingState != AudioProcessingState.completed) {
                            return Semantics(
                              label: 'Duraklat',
                              button: true,
                              child: IconButton(
                                icon: const Icon(Icons.pause_circle_filled),
                                iconSize: 80,
                                color: Theme.of(context).colorScheme.primary,
                                onPressed: audioHandler.pause,
                              ),
                            );
                          } else {
                            return Semantics(
                              label: 'Tekrar Oynat',
                              button: true,
                              child: IconButton(
                                icon: const Icon(Icons.replay),
                                iconSize: 80,
                                color: Theme.of(context).colorScheme.primary,
                                onPressed: () => audioHandler.seek(Duration.zero),
                              ),
                            );
                          }
                        },
                      ),
                      Semantics(
                        label: '10 saniye ileri sar',
                        button: true,
                        child: IconButton(
                          iconSize: 50,
                          icon: const Icon(Icons.forward_10),
                          color: Theme.of(context).colorScheme.secondary,
                          onPressed: () {
                            audioHandler.fastForward();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  if (isDownloading) ...[
                    const Text('İndiriliyor...'),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: downloadProgress),
                    Text('${(downloadProgress * 100).toStringAsFixed(1)}%'),
                  ] else
                    ElevatedButton.icon(
                      icon: Icon(isDownloaded ? Icons.delete_outline : Icons.download),
                      label: Text(
                        isDownloaded ? 'Çevrimdışı listemden çıkar' : 'Çevrimdışı Dinle',
                        style: const TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDownloaded ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                        foregroundColor: isDownloaded ? Theme.of(context).colorScheme.onError : Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _toggleDownload,
                    ),
                ],
              ),
            ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }
}
