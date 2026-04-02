import 'package:flutter/material.dart';
import 'package:blind_social/theme/app_fonts.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';

class LiveRadioPlayerScreen extends StatefulWidget {
  final Map<String, String> radio;

  const LiveRadioPlayerScreen({super.key, required this.radio});

  @override
  State<LiveRadioPlayerScreen> createState() => _LiveRadioPlayerScreenState();
}

class _LiveRadioPlayerScreenState extends State<LiveRadioPlayerScreen> {
  @override
  void initState() {
    super.initState();
    _playRadio();
  }

  Future<void> _playRadio() async {
    try {
      final currentUrl = widget.radio['url']!;

      // If already playing this radio, do nothing
      if (audioHandler.mediaItem.value?.id == currentUrl) {
        if (!audioHandler.player.playing) {
          await audioHandler.play();
        }
        return;
      }

      await audioHandler.stop();
      final item = MediaItem(
        id: currentUrl,
        title: widget.radio['name']!,
        artist: 'Blind Social Live Radio',
      );
      await audioHandler.setUrl(currentUrl, mediaItem: item);
      await audioHandler.play();
    } catch (e) {
      debugPrint("Radio Play Error: $e");
    }
  }

  void _stopRadio() {
    audioHandler.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.radio['name']!)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 30),
            Text(
              widget.radio['name']!,
              style: TextStyle(
                fontSize: AppFonts.size(28),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Canlı Yayın',
              style: TextStyle(
                fontSize: AppFonts.size(18),
                color: Theme.of(context).colorScheme.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            StreamBuilder<PlaybackState>(
              stream: audioHandler.playbackState,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final playing = state?.playing ?? false;
                final processingState = state?.processingState ?? AudioProcessingState.idle;

                final isLoading = processingState == AudioProcessingState.loading ||
                    processingState == AudioProcessingState.buffering;

                if (isLoading) {
                  return const Center(
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                return Center(
                  child: TextButton.icon(
                    icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 40),
                    label: Text(playing ? "Radyoyu Durdur" : "Radyoyu Başlat", style: TextStyle(fontSize: AppFonts.size(18))),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    onPressed: () {
                      if (playing) {
                        _stopRadio();
                      } else {
                        _playRadio();
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
