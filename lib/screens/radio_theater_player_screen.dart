import 'dart:async';
import 'package:blind_social/theme/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';
import '../services/audio_cache_manager.dart';
import '../services/audio_progress_manager.dart';
import '../services/audio_favorites_manager.dart';

class RadioTheaterPlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? localForcePath;

  const RadioTheaterPlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.localForcePath,
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

  double _currentSpeed = 1.0;
  bool _isDownloading = false;
  String? _localPath;
  Duration _lastSavedPosition = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playbackStateSubscription;
  bool _isFavorite = false;

  Future<void> _initAudio() async {
    final directAudioUrl = _convertToDirectLink(widget.url);

    try {
      if (widget.localForcePath != null) {
        _localPath = widget.localForcePath;
      } else {
        // Check if file is already downloaded
        _localPath = await AudioCacheManager.getCachedAudioPath(directAudioUrl, widget.title);
      }

      final playUrl = _localPath != null ? 'file://$_localPath' : directAudioUrl;

      final mediaItem = MediaItem(
        id: playUrl,
        title: widget.title,
        artist: 'Blind Social Sesli Kitap / Tiyatro',
      );

      await audioHandler.stop();
      await audioHandler.setUrl(playUrl, mediaItem: mediaItem);

      // Load saved progress
      _lastSavedPosition = await AudioProgressManager.getProgress(widget.url);
      if (_lastSavedPosition > Duration.zero) {
        await audioHandler.seek(_lastSavedPosition);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Play immediately but don't await the Future
      audioHandler.play();

      // Periodically save progress
      _positionSubscription = audioHandler.player.positionStream.listen((position) {
        if (position.inSeconds % 10 == 0) {
          AudioProgressManager.saveProgress(widget.url, position);
        }
      });

      // Load favorite status
      _isFavorite = await AudioFavoritesManager.isFavorite(widget.url);

      // Listen to player state to update UI play/pause icon correctly
      _playbackStateSubscription = audioHandler.playbackState.listen((state) {
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
    _positionSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    audioHandler.stop();
    super.dispose();
  }

  void _changeSpeed() {
    setState(() {
      if (_currentSpeed == 1.0) {
        _currentSpeed = 1.25;
      } else if (_currentSpeed == 1.25) {
        _currentSpeed = 1.5;
      } else if (_currentSpeed == 1.5) {
        _currentSpeed = 2.0;
      } else {
        _currentSpeed = 1.0;
      }
      audioHandler.player.setSpeed(_currentSpeed);
    });
  }

  Future<void> _downloadOffline() async {
    setState(() {
      _isDownloading = true;
    });

    final directAudioUrl = _convertToDirectLink(widget.url);
    final path = await AudioCacheManager.downloadAudio(directAudioUrl, widget.title);

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _localPath = path;
      });

      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiyatro çevrimdışı dinleme için kaydedildi.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İndirme sırasında bir hata oluştu.')),
        );
      }
    }
  }

  Future<void> _deleteOffline() async {
    if (_localPath == null) return;

    final success = await AudioCacheManager.deleteAudio(widget.url, widget.title);

    if (success && mounted) {
      setState(() {
        _localPath = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tiyatro çevrimdışı dinleme listenizden çıkarıldı.')),
      );
      // Fallback url dynamically updates via play mechanism or user backs out
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }

  Future<void> _toggleFavorite() async {
    await AudioFavoritesManager.toggleFavorite(widget.url);
    if (mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oynatıcı'),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : null,
            ),
            tooltip: 'Favorilere Ekle/Çıkar',
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(fontSize: AppFonts.size(18), color: Colors.red),
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
                          image: const DecorationImage(
                            image: AssetImage('assets/images/radio_cover.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: AppFonts.size(22),
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
                                    Text(_formatDuration(position), style: TextStyle(fontSize: AppFonts.size(16))),
                                    Text(_formatDuration(duration), style: TextStyle(fontSize: AppFonts.size(16))),
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
                          TextButton.icon(
                            onPressed: _changeSpeed,
                            icon: const Icon(Icons.speed, size: 20),
                            label: Text(
                              'Hız: ${_currentSpeed}x',
                              style: TextStyle(
                                fontSize: AppFonts.size(16),
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_localPath == null)
                            _isDownloading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : TextButton.icon(
                                    onPressed: _downloadOffline,
                                    icon: const Icon(Icons.download, size: 20),
                                    label: Text(
                                      'Çevrimdışı Dinlemek İçin İndir',
                                      style: TextStyle(
                                        fontSize: AppFonts.size(16),
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                          else
                            TextButton.icon(
                              onPressed: _deleteOffline,
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              label: Text(
                                'İndirilen Kaynağı Sil',
                                style: TextStyle(
                                  fontSize: AppFonts.size(16),
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                audioHandler.rewind();
                              },
                              child: Text(
                                '10 Saniye Geri',
                                style: TextStyle(
                                  fontSize: AppFonts.size(16),
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
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
                                  fontSize: AppFonts.size(20),
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                audioHandler.fastForward();
                              },
                              child: Text(
                                '10 Saniye İleri',
                                style: TextStyle(
                                  fontSize: AppFonts.size(16),
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
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
