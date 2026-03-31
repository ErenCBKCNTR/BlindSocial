import 'package:flutter/material.dart';
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
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  // Converts a standard Google Drive view link to a direct download link
  // e.g., https://drive.google.com/file/d/FILE_ID/view?usp=sharing
  // -> https://drive.google.com/uc?export=download&id=FILE_ID
  String _convertToDirectLink(String driveLink) {
    // Linkin içinden ID kısmını ayıklar
    RegExp regExp = RegExp(r"id=([a-zA-Z0-9_-]+)|/d/([a-zA-Z0-9_-]+)");
    Match? match = regExp.firstMatch(driveLink);

    if (match != null) {
      String fileId = match.group(1) ?? match.group(2)!;
      return "https://drive.google.com/uc?export=download&id=$fileId";
    }
    return driveLink;
  }

  Future<void> _initAudio() async {
    final directAudioUrl = _convertToDirectLink(widget.url);

    try {
      final mediaItem = MediaItem(
        id: directAudioUrl,
        title: widget.title,
        artist: 'Blind Social Sesli Kitap / Tiyatro',
      );

      await audioHandler.stop();
      await audioHandler.setUrl(directAudioUrl, mediaItem: mediaItem);
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
          _errorMessage = "Ses dosyası oynatılamadı. Lütfen Google Drive bağlantısının 'Herkese Açık' (Bağlantıya sahip olan herkes) olarak ayarlandığından emin olun.";
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
      appBar: AppBar(title: const Text('Oynatıcı')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
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
                      Container(
                        height: 250,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Icon(
                          Icons.headphones,
                          size: 100,
                          color: Theme.of(context).colorScheme.primary,
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
