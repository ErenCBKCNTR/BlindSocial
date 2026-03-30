import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class RadioTheaterScreen extends StatefulWidget {
  const RadioTheaterScreen({super.key});

  @override
  State<RadioTheaterScreen> createState() => _RadioTheaterScreenState();
}

class _RadioTheaterScreenState extends State<RadioTheaterScreen> {
  YoutubePlayerController? _ytController;
  String? _currentlyPlayingId;
  bool _isPlaying = false;
  String _currentTitle = '';

  @override
  void dispose() {
    _ytController?.close();
    super.dispose();
  }

  void _playTheater(String url, String title) {
    final videoId = YoutubePlayerController.convertUrlToId(url) ?? url;
    if (_currentlyPlayingId == videoId) {
      if (_isPlaying) {
        _ytController?.pauseVideo();
      } else {
        _ytController?.playVideo();
      }
      return;
    }

    _ytController?.close();

    setState(() {
      _currentlyPlayingId = videoId;
      _currentTitle = title;
      _isPlaying = false; // Will be true when ready
    });

    _ytController = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: false,
        showVideoAnnotations: false,
        playsInline: true,
        pointerEvents: PointerEvents.none,
      ),
    );

    _ytController!.listen((event) {
      if (mounted) {
        if (event.playerState == PlayerState.playing && !_isPlaying) {
          // Setting playback quality is handled via Javascript in iframe on web
          // Not directly supported by youtube_player_iframe in native setPlaybackQuality,
          // but avoiding high-res video loading by keeping the size minimal usually helps.
          setState(() {
            _isPlaying = true;
          });
        } else if (event.playerState == PlayerState.paused && _isPlaying) {
          setState(() {
            _isPlaying = false;
          });
        }
      }
    });
  }

  void _stopPlayer() {
    _ytController?.stopVideo();
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Radyo Tiyatrosu')),
      body: Column(
        children: [
          // Hidden Youtube Player to play only audio and satisfy Talkback
          if (_ytController != null)
            SizedBox(
              width: 1.0,
              height: 1.0,
              child: YoutubePlayer(controller: _ytController!),
            ),

          if (_currentlyPlayingId != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Column(
                children: [
                  Text(
                    'Şu an çalıyor: $_currentTitle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(_isPlaying ? 'Durdur' : 'Başlat'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () {
                          if (_isPlaying) {
                            _ytController?.pauseVideo();
                          } else {
                            _ytController?.playVideo();
                          }
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.stop),
                        label: const Text('Kapat'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: _stopPlayer,
                      ),
                    ],
                  ),
                ],
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('radio_theaters')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Tiyatro bulunamadı.'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'Bilinmeyen Tiyatro';
                    final url = data['url'] ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.radio),
                        title: Text(title),
                        onTap: () => _playTheater(url, title),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
