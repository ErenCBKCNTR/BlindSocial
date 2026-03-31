import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';

class RadioTheaterPlayerScreen extends StatefulWidget {
  final String url;
  final String title;

  const RadioTheaterPlayerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<RadioTheaterPlayerScreen> createState() => _RadioTheaterPlayerScreenState();
}

class _RadioTheaterPlayerScreenState extends State<RadioTheaterPlayerScreen> {
  String? _videoId;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPlaying = false;

  final List<String> _pipedInstances = [
    'https://api.piped.private.coffee',
    'https://pipedapi.lunar.icu',
    'https://pipedapi.kavin.rocks',
    'https://piped-api.garudalinux.org',
    'https://pipedapi.drgns.space',
  ];

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  String? _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtube.com')) {
        return uri.queryParameters['v'];
      } else if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.first;
      }
    } catch (e) {
      debugPrint('Error parsing URL: $e');
    }
    return null;
  }

  Future<void> _initAudio() async {
    _videoId = _extractVideoId(widget.url);
    if (_videoId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Geçersiz YouTube bağlantısı.";
        });
      }
      return;
    }

    // Attempt to fetch audio stream from multiple Piped API instances
    String? audioUrl;
    for (final instance in _pipedInstances) {
      try {
        debugPrint('Trying Piped instance: $instance');
        final response = await http
            .get(Uri.parse('$instance/streams/$_videoId'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['audioStreams'] != null && data['audioStreams'].isNotEmpty) {
            final audioStreams = List<Map<String, dynamic>>.from(data['audioStreams']);
            // Prefer m4a for compatibility
            audioStreams.sort((a, b) => (b['bitrate'] as int? ?? 0).compareTo(a['bitrate'] as int? ?? 0));
            final bestStream = audioStreams.firstWhere(
              (stream) => stream['codec'] == 'm4a',
              orElse: () => audioStreams.first,
            );
            audioUrl = bestStream['url'];
            if (audioUrl != null) break;
          }
        }
      } catch (e) {
        debugPrint('Failed instance $instance: $e');
      }
    }

    if (audioUrl == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Ses akışı alınamadı, sunucular yanıt vermiyor.";
        });
      }
      return;
    }

    try {
      final mediaItem = MediaItem(
        id: audioUrl,
        title: widget.title,
        artist: 'Blind Social Radyo Tiyatrosu',
        artUri: Uri.parse('https://img.youtube.com/vi/$_videoId/0.jpg'),
      );

      await audioHandler.stop();
      await audioHandler.setUrl(audioUrl, mediaItem: mediaItem);
      await audioHandler.play();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = true;
        });
      }

      // Listen to player state to update UI play/pause icon correctly
      audioHandler.playbackState.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });

    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Oynatılırken bir hata oluştu: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    audioHandler.stop();
    super.dispose();
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 18, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Image.network(
                          'https://img.youtube.com/vi/$_videoId/0.jpg',
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
                        widget.title,
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
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () {
                              audioHandler.rewind();
                            },
                            child: Text(
                              '10 Saniye Geriye Al',
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              if (_isPlaying) {
                                audioHandler.pause();
                              } else {
                                audioHandler.play();
                              }
                            },
                            child: Text(
                              _isPlaying ? 'Duraklat' : 'Başlat',
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
                              '10 Saniye İleri Sar',
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
