import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

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

  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initData();
  }

  Future<void> _initData() async {
    try {
      videoId = VideoId(videoUrl);
      var video = await yt.videos.get(videoId!);
      var manifest = await yt.videos.streamsClient.getManifest(videoId!);
      var audioStreamInfo = manifest.audioOnly.withHighestBitrate();

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

      if (fileExists) {
        await _audioPlayer.setFilePath(localFilePath!);
      } else {
        await _audioPlayer.setUrl(audioUrl!);
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
      await _audioPlayer.setUrl(audioUrl!); // Switch back to streaming
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
        final currentPosition = _audioPlayer.position;
        final playing = _audioPlayer.playing;

        await _audioPlayer.setFilePath(localFilePath!);
        await _audioPlayer.seek(currentPosition);
        if (playing) await _audioPlayer.play();

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
    _audioPlayer.dispose();
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
                            final newPosition = _audioPlayer.position - const Duration(seconds: 10);
                            _audioPlayer.seek(newPosition < Duration.zero ? Duration.zero : newPosition);
                          },
                        ),
                      ),
                      StreamBuilder<PlayerState>(
                        stream: _audioPlayer.playerStateStream,
                        builder: (context, snapshot) {
                          final playerState = snapshot.data;
                          final processingState = playerState?.processingState;
                          final playing = playerState?.playing;

                          if (processingState == ProcessingState.loading ||
                              processingState == ProcessingState.buffering) {
                            return Container(
                              margin: const EdgeInsets.all(8.0),
                              width: 64.0,
                              height: 64.0,
                              child: const CircularProgressIndicator(),
                            );
                          } else if (playing != true) {
                            return Semantics(
                              label: 'Oynat',
                              button: true,
                              child: IconButton(
                                icon: const Icon(Icons.play_circle_filled),
                                iconSize: 80,
                                color: Theme.of(context).colorScheme.primary,
                                onPressed: _audioPlayer.play,
                              ),
                            );
                          } else if (processingState != ProcessingState.completed) {
                            return Semantics(
                              label: 'Duraklat',
                              button: true,
                              child: IconButton(
                                icon: const Icon(Icons.pause_circle_filled),
                                iconSize: 80,
                                color: Theme.of(context).colorScheme.primary,
                                onPressed: _audioPlayer.pause,
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
                                onPressed: () => _audioPlayer.seek(Duration.zero),
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
                            final newPosition = _audioPlayer.position + const Duration(seconds: 10);
                            final duration = _audioPlayer.duration ?? Duration.zero;
                            _audioPlayer.seek(newPosition > duration ? duration : newPosition);
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
}
