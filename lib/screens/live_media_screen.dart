import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class LiveMediaScreen extends StatefulWidget {
  const LiveMediaScreen({super.key});

  @override
  State<LiveMediaScreen> createState() => _LiveMediaScreenState();
}

class _LiveMediaScreenState extends State<LiveMediaScreen> {
  final List<Map<String, String>> radioList = [
    {'name': 'TRT FM', 'url': 'https://trtcanlifm-s3.mncdn.com/trtfm/trtfm.stream/playlist.m3u8'},
    {'name': 'Kral FM', 'url': 'http://46.20.3.204:80/kralfm'},
    {'name': 'JoyTürk', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/JOY_TURK_SC'},
    {'name': 'NTV Radyo', 'url': 'http://ntvradyo.medyacdn.com/ntvradyo/ntvradyo_1/playlist.m3u8'},
    {'name': 'TRT Spor', 'url': 'https://trtcanlifm-s3.mncdn.com/trtsporradyo/trtsporradyo.stream/playlist.m3u8'},
    {'name': 'TRT Müzik', 'url': 'https://tv-trtmuzik.medya.trt.com.tr/master.m3u8'},
    {'name': 'Süper FM', 'url': 'https://listen.karnaval.com/superfm128.mp3'},
    {'name': 'Alem FM', 'url': 'http://scturkey.com:8010/;stream.mp3'},
  ];

  final List<Map<String, String>> tvList = [
    {'name': 'TRT 1', 'url': 'https://tv-trt1.medya.trt.com.tr/master.m3u8'},
    {'name': 'TRT Haber', 'url': 'https://tv-trthaber.medya.trt.com.tr/master.m3u8'},
    {'name': 'TRT Belgesel', 'url': 'https://tv-trtbelgesel.medya.trt.com.tr/master.m3u8'},
    {'name': 'HaberTürk', 'url': 'https://ciner-live.daioncdn.net/haberturk/haberturk.m3u8'},
  ];

  late AudioPlayer _audioPlayer;
  int? _playingRadioIndex;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudioSession();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playRadio(int index) async {
    try {
      if (_playingRadioIndex == index) {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
        setState(() {});
        return;
      }

      setState(() {
        _playingRadioIndex = index;
      });
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(radioList[index]['url']!);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Radio Play Error: \$e");
    }
  }

  void _openTvPlayer(BuildContext context, String title, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvPlayerScreen(title: title, url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Canlı Yayın')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildRadioCard(),
            const SizedBox(height: 20),
            _buildTvCard(),
          ],
        ),
      ),
      bottomNavigationBar: _playingRadioIndex != null ? _buildMiniPlayer() : null,
    );
  }

  Widget _buildMiniPlayer() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                radioList[_playingRadioIndex!]['name']!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: _audioPlayer.playing ? "Radyoyu Durdur" : "Radyoyu Başlat",
                  button: true,
                  child: IconButton(
                    icon: Icon(_audioPlayer.playing ? Icons.pause : Icons.play_arrow),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    iconSize: 32,
                    onPressed: () {
                      if (_audioPlayer.playing) {
                        _audioPlayer.pause();
                      } else {
                        _audioPlayer.play();
                      }
                      setState(() {});
                    },
                  ),
                ),
                Semantics(
                  label: "Yayını Kapat",
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.stop),
                    color: Theme.of(context).colorScheme.error,
                    iconSize: 32,
                    onPressed: () {
                      _audioPlayer.stop();
                      setState(() {
                        _playingRadioIndex = null;
                      });
                    },
                  ),
                ),
                Semantics(
                  label: "Arka Plana Al",
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    iconSize: 32,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.radio, size: 40, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text('Radyo Dinle', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(radioList.length, (index) {
              final isPlaying = _playingRadioIndex == index && _audioPlayer.playing;
              return ListTile(
                leading: const Icon(Icons.headset),
                title: Text(radioList[index]['name']!, style: const TextStyle(fontSize: 18)),
                trailing: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 36, color: Theme.of(context).colorScheme.secondary),
                onTap: () => _playRadio(index),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTvCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.tv, size: 40, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text('Televizyon İzle', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(tvList.length, (index) {
              return ListTile(
                leading: const Icon(Icons.live_tv),
                title: Text(tvList[index]['name']!, style: const TextStyle(fontSize: 18)),
                trailing: Icon(Icons.play_arrow, size: 36, color: Theme.of(context).colorScheme.secondary),
                onTap: () => _openTvPlayer(context, tvList[index]['name']!, tvList[index]['url']!),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class TvPlayerScreen extends StatefulWidget {
  final String title;
  final String url;
  const TvPlayerScreen({super.key, required this.title, required this.url});

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await _videoPlayerController.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: true,
      isLive: true,
      fullScreenByDefault: true,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
    setState(() {});
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      backgroundColor: Colors.black,
      body: Center(
        child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(),
      ),
    );
  }
}
