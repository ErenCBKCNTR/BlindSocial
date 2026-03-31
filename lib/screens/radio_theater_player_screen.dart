import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

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
  late YoutubePlayerController _controller;
  String? _videoId;

  @override
  void initState() {
    super.initState();
    _videoId = YoutubePlayerController.convertUrlToId(widget.url);

    _controller = YoutubePlayerController.fromVideoId(
      videoId: _videoId ?? '',
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        loop: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Radyo Tiyatrosu Oynatıcı')),
        body: const Center(child: Text('Geçersiz video bağlantısı')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Radyo Tiyatrosu Oynatıcı')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            YoutubePlayer(
              controller: _controller,
              aspectRatio: 16 / 9,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () async {
                    final currentPos = await _controller.currentTime;
                    _controller.seekTo(seconds: currentPos - 10, allowSeekAhead: true);
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
                TextButton(
                  onPressed: () async {
                    final state = await _controller.playerState;
                    if (state == PlayerState.playing) {
                      _controller.pauseVideo();
                    } else {
                      _controller.playVideo();
                    }
                  },
                  child: Text(
                    'Başlat / Duraklat',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final currentPos = await _controller.currentTime;
                    _controller.seekTo(seconds: currentPos + 10, allowSeekAhead: true);
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
          ],
        ),
      ),
    );
  }
}
