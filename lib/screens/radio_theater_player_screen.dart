import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../services/audio_handler.dart';

class RadioTheaterPlayerScreen extends StatefulWidget {
  final String url;
  final String title;

  const RadioTheaterPlayerScreen({super.key, required this.url, required this.title});

  @override
  State<RadioTheaterPlayerScreen> createState() => _RadioTheaterPlayerScreenState();
}

class _RadioTheaterPlayerScreenState extends State<RadioTheaterPlayerScreen> {
  String? _currentlyPlayingId;
  bool _isPlaying = false;
  bool _isLoading = false;
  String _currentTitle = '';

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadedFilePath;
  bool _isDownloaded = false;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;

  @override
  void initState() {
    super.initState();
    _listenToPlayerState();
    _checkInitialStateAndPlay();
  }

  Future<void> _checkInitialStateAndPlay() async {
    final videoId = _extractVideoId(widget.url) ?? widget.url;
    final currentItem = audioHandler.mediaItem.value;

    // If this theater is already playing, just update UI state and do not restart
    if (currentItem != null && currentItem.title == widget.title) {
      setState(() {
        _currentlyPlayingId = videoId;
        _currentTitle = widget.title;
      });
      await _checkLocalFile(videoId);
      return;
    }

    _playTheater(widget.url, widget.title);
  }

  @override
  void dispose() {
    _playbackStateSubscription?.cancel();
    super.dispose();
  }

  void _listenToPlayerState() {
    _playbackStateSubscription = audioHandler.playbackState.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isLoading = state.processingState == AudioProcessingState.loading || state.processingState == AudioProcessingState.buffering;
        });
      }
    });
  }

  String? _extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }

    if (uri.host.contains('youtube.com')) {
      if (uri.path.contains('/v/') || uri.path.contains('/embed/')) {
        return uri.pathSegments.last;
      }
      return uri.queryParameters['v'];
    }

    return null;
  }

  Future<String?> _fetchPipedAudioUrl(String videoId) async {
    final endpoints = [
      'https://api.piped.private.coffee',
      'https://piped.video',
      'https://piped.incognito.com',
      'https://pipedapi.smnz.de',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http.get(Uri.parse('$endpoint/streams/$videoId'));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final audioStreams = data['audioStreams'] as List<dynamic>?;
          if (audioStreams != null && audioStreams.isNotEmpty) {
            audioStreams.sort((a, b) => (b['bitrate'] ?? 0).compareTo(a['bitrate'] ?? 0));
            final bestStream = audioStreams.firstWhere(
              (s) => s['format'] == 'M4A' || s['format'] == 'WEBM',
              orElse: () => audioStreams.first,
            );
            return bestStream['url'] as String?;
          }
        }
      } catch (e) {
        debugPrint('Piped API Error with $endpoint: $e');
        continue;
      }
    }
    return null;
  }

  Future<void> _checkLocalFile(String videoId) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$videoId.m4a';
    final file = File(path);
    final exists = await file.exists();
    if (mounted) {
      setState(() {
        _downloadedFilePath = exists ? path : null;
        _isDownloaded = exists;
      });
    }
  }

  Future<void> _playTheater(String url, String title) async {
    final videoId = _extractVideoId(url) ?? url;

    if (_currentlyPlayingId == videoId) {
      if (_isPlaying) {
        await audioHandler.pause();
      } else {
        await audioHandler.play();
      }
      return;
    }

    setState(() {
      _currentlyPlayingId = videoId;
      _currentTitle = title;
      _isLoading = true;
    });

    await _checkLocalFile(videoId);

    String? streamUrl;

    if (_isDownloaded && _downloadedFilePath != null) {
      streamUrl = _downloadedFilePath;
    } else {
      streamUrl = await _fetchPipedAudioUrl(videoId);
    }

    if (streamUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ses akışı alınamadı, API yanıt vermiyor.')),
        );
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final item = MediaItem(
      id: streamUrl,
      title: title,
      artist: 'Radyo Tiyatrosu',
      artUri: Uri.parse('https://img.youtube.com/vi/$videoId/0.jpg'),
    );

    if (_isDownloaded && _downloadedFilePath != null) {
        await audioHandler.setFilePath(_downloadedFilePath!, mediaItem: item);
    } else {
        await audioHandler.setUrl(streamUrl, mediaItem: item);
    }
    await audioHandler.play();
  }

  Future<void> _toggleDownload() async {
    if (_currentlyPlayingId == null) return;

    final videoId = _currentlyPlayingId!;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$videoId.m4a';
    final file = File(path);

    if (_isDownloaded) {
      await file.delete();
      setState(() {
        _isDownloaded = false;
        _downloadedFilePath = null;
        _downloadProgress = 0.0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya cihazdan silindi.')),
        );
      }
    } else {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      final yt = YoutubeExplode();
      try {
        final manifest = await yt.videos.streamsClient.getManifest(videoId);
        final audioOnlyStreams = manifest.audioOnly;

        if (audioOnlyStreams.isEmpty) {
          throw Exception("No audio streams found");
        }

        // Try to find the highest bitrate m4a (mp4 container)
        final streamInfo = audioOnlyStreams.withHighestBitrate();
        final stream = yt.videos.streamsClient.get(streamInfo);

        final contentLength = streamInfo.size.totalBytes;
        int bytesDownloaded = 0;
        final sink = file.openWrite();

        await for (final chunk in stream) {
          sink.add(chunk);
          bytesDownloaded += chunk.length;
          if (contentLength > 0 && mounted) {
            setState(() {
              _downloadProgress = bytesDownloaded / contentLength;
            });
          }
        }
        await sink.close();

        setState(() {
          _isDownloaded = true;
          _isDownloading = false;
          _downloadedFilePath = path;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İndirme tamamlandı! Artık çevrimdışı dinleyebilirsiniz.')),
          );
        }
      } catch (e) {
        debugPrint("Download error: $e");
        setState(() {
          _isDownloading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İndirme sırasında bir hata oluştu.')),
          );
        }
        if (await file.exists()) {
          await file.delete();
        }
      } finally {
        yt.close();
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Radyo Tiyatrosu Oynatıcı')),
      body: _currentlyPlayingId == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                   ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.network(
                        'https://img.youtube.com/vi/$_currentlyPlayingId/0.jpg',
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 250,
                          color: Colors.grey[800],
                          child: const Center(child: Icon(Icons.radio, size: 80)),
                        ),
                      ),
                   ),
                  const SizedBox(height: 24),
                  Text(
                    _currentTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(position), style: const TextStyle(fontSize: 16)),
                                Text(_formatDuration(duration), style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          audioHandler.rewind();
                        },
                        child: Text(
                          '< 10 Saniye',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(),
                        )
                      else
                        TextButton(
                          onPressed: () {
                            if (_isPlaying) {
                              audioHandler.pause();
                            } else {
                              audioHandler.play();
                            }
                          },
                          child: Text(
                            _isPlaying ? 'Durdur' : 'Oynat',
                            style: TextStyle(
                              fontSize: 24,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: () {
                          audioHandler.fastForward();
                        },
                        child: Text(
                          '10 Saniye >',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_isDownloading) ...[
                    const Text('İndiriliyor...', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _downloadProgress),
                  ] else
                    ElevatedButton.icon(
                      icon: Icon(_isDownloaded ? Icons.delete_outline : Icons.download),
                      label: Text(
                        _isDownloaded ? 'Çevrimdışı listemden çıkar' : 'Çevrimdışı Dinle',
                        style: const TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDownloaded ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                        foregroundColor: _isDownloaded ? Theme.of(context).colorScheme.onError : Theme.of(context).colorScheme.onPrimary,
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
