import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';

class LiveMediaScreen extends StatefulWidget {
  const LiveMediaScreen({super.key});

  @override
  State<LiveMediaScreen> createState() => _LiveMediaScreenState();
}

class _LiveMediaScreenState extends State<LiveMediaScreen> {
  List<Map<String, String>> radioList = [];
  List<Map<String, String>> tvList = [];
  bool isLoadingRadios = true;
  bool isLoadingTvs = true;

  int? _playingRadioIndex;

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  int? _playingTvIndex;

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    _fetchRadios();
    _fetchTvs();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> _fetchRadios() async {
    final List<Map<String, String>> predefinedRadios = [
      {'name': 'Alem FM', 'url': 'http://scturkmedya.radyotvonline.com/stream/80/'},
      {'name': 'Best FM', 'url': 'http://46.20.7.126/bestfm'},
      {'name': 'JoyTürk', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/JOY_TURK_SC'},
      {'name': 'Kral FM', 'url': 'https://kralfm.radyotvonline.net/kralfm'},
      {'name': 'Metro FM', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/METRO_FM_SC'},
      {'name': 'PowerTürk', 'url': 'https://listen.powerapp.com.tr/powerturk/mpeg/icecast.audio'},
      {'name': 'Radyo Fenomen', 'url': 'https://listen.radyofenomen.com/fenomen/128/icecast.audio'},
      {'name': 'Süper FM', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/SUPER_FM_SC'},
      {'name': 'TRT FM', 'url': 'http://trtcanlifm-lh.akamaihd.net/i/TRTFM_1@182346/master.m3u8'},
      {'name': 'Virgin Radio', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/VIRGIN_RADIO_SC'}
    ];

    predefinedRadios.sort((a, b) => a['name']!.compareTo(b['name']!));

    setState(() {
      radioList = predefinedRadios;
      isLoadingRadios = false;
    });
  }

  Future<void> _fetchTvs() async {
    final List<Map<String, String>> predefinedTvs = [
      {'name': 'ATV', 'url': 'https://video.haber7.com/video_player/livestream/atv.m3u8'},
      {'name': 'CNN Türk', 'url': 'https://live.dogannet.tv/S2/HLS_LIVE/cnnturk/cnnturk.m3u8'},
      {'name': 'HaberTürk', 'url': 'https://ciner-live.ercdn.net/haberturk/haberturk.m3u8'},
      {'name': 'Kanal D', 'url': 'https://live.dogannet.tv/S1/HLS_LIVE/kanaldnp/track_4000/chunklist.m3u8'},
      {'name': 'NTV', 'url': 'https://ntv-live-nmd1.sozcu.com.tr/out/v1/a29e4ba6f5ed42fe8bd320dae278f24b/index.m3u8'},
      {'name': 'Now TV', 'url': 'https://tr-now.ercdn.net/now/now_720p.m3u8'},
      {'name': 'Show TV', 'url': 'https://ciner-live.ercdn.net/showtv/showtv.m3u8'},
      {'name': 'Star TV', 'url': 'https://dogus-live.ercdn.net/startv/startv_720p.m3u8'},
      {'name': 'TRT 1', 'url': 'https://tv-trt1.medya.trt.com.tr/master_720.m3u8'},
      {'name': 'TV8', 'url': 'https://tv8-live.ercdn.net/tv8/tv8_720p.m3u8'}
    ];

    predefinedTvs.sort((a, b) => a['name']!.compareTo(b['name']!));

    setState(() {
      tvList = predefinedTvs;
      isLoadingTvs = false;
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _playRadio(int index) async {
    try {
      if (_playingRadioIndex == index) {
        if (audioHandler.player.playing) {
          await audioHandler.pause();
        } else {
          await audioHandler.play();
        }
        setState(() {});
        return;
      }

      // Stop TV if playing
      _stopTv();

      setState(() {
        _playingRadioIndex = index;
      });
      await audioHandler.stop();
      final item = MediaItem(
        id: radioList[index]['url']!,
        title: radioList[index]['name']!,
        artist: 'Blind Social Live Radio',
      );
      await audioHandler.setUrl(radioList[index]['url']!, mediaItem: item);
      await audioHandler.play();
    } catch (e) {
      debugPrint("Radio Play Error: $e");
    }
  }

  void _stopRadio() {
    audioHandler.stop();
    setState(() {
      _playingRadioIndex = null;
    });
  }

  Future<void> _playTv(int index) async {
    try {
      if (_playingTvIndex == index) {
        // Just expanding/collapsing logic handles play state
        return;
      }

      // Stop radio if playing
      _stopRadio();

      // Stop previous TV
      _stopTv();

      setState(() {
        _playingTvIndex = index;
      });

      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(tvList[index]['url']!));
      await _videoPlayerController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: true,
        isLive: true,
        showControls: false, // We'll use custom controls below the player
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
    } catch (e) {
      debugPrint("TV Play Error: $e");
    }
  }

  void _stopTv() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    setState(() {
      _playingTvIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Canlı Yayın')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildRadioSection(),
          const SizedBox(height: 20),
          _buildTvSection(),
        ],
      ),
    );
  }

  Widget _buildRadioSection() {
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
            if (isLoadingRadios)
              const Center(child: CircularProgressIndicator())
            else if (radioList.isEmpty)
              const Center(child: Text("Radyo kanalları bulunamadı."))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: radioList.length,
                itemBuilder: (context, index) {
                  final isPlaying = _playingRadioIndex == index;
                  return StreamBuilder<PlaybackState>(
                    stream: audioHandler.playbackState,
                    builder: (context, snapshot) {
                      final state = snapshot.data;
                      final playing = state?.playing ?? false;
                      final isAudioPlaying = isPlaying && playing;

                      return ExpansionTile(
                        leading: const Icon(Icons.headset),
                        title: Text(radioList[index]['name']!, style: const TextStyle(fontSize: 18)),
                        trailing: Icon(isAudioPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 36, color: Theme.of(context).colorScheme.secondary),
                        onExpansionChanged: (expanded) {
                          if (expanded) {
                            _playRadio(index);
                          }
                        },
                        children: [
                          if (isPlaying)
                            Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Semantics(
                                    label: isAudioPlaying ? "Radyoyu Durdur" : "Radyoyu Başlat",
                                    button: true,
                                    child: IconButton(
                                      icon: Icon(isAudioPlaying ? Icons.pause : Icons.play_arrow),
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      iconSize: 40,
                                      onPressed: () => _playRadio(index),
                                    ),
                                  ),
                                  Semantics(
                                    label: "Yayını Kapat",
                                    button: true,
                                    child: IconButton(
                                      icon: const Icon(Icons.stop),
                                      color: Theme.of(context).colorScheme.error,
                                      iconSize: 40,
                                      onPressed: _stopRadio,
                                    ),
                                  ),
                                ],
                              ),
                            )
                        ],
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTvSection() {
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
            if (isLoadingTvs)
              const Center(child: CircularProgressIndicator())
            else if (tvList.isEmpty)
              const Center(child: Text("Televizyon kanalları bulunamadı."))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tvList.length,
                itemBuilder: (context, index) {
                  final isPlaying = _playingTvIndex == index;

                  return ExpansionTile(
                    leading: const Icon(Icons.live_tv),
                    title: Text(tvList[index]['name']!, style: const TextStyle(fontSize: 18)),
                    trailing: Icon(isPlaying ? Icons.tv_off : Icons.play_arrow, size: 36, color: Theme.of(context).colorScheme.secondary),
                    onExpansionChanged: (expanded) {
                      if (expanded) {
                        _playTv(index);
                      } else if (isPlaying) {
                        _stopTv();
                      }
                    },
                    children: [
                      if (isPlaying)
                        Column(
                          children: [
                            Container(
                              height: 200,
                              color: Colors.black,
                              child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                                  ? Chewie(controller: _chewieController!)
                                  : const Center(child: CircularProgressIndicator()),
                            ),
                            Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Semantics(
                                    label: "Televizyonu Durdur/Başlat",
                                    button: true,
                                    child: IconButton(
                                      icon: Icon(
                                        _videoPlayerController?.value.isPlaying ?? false
                                            ? Icons.pause
                                            : Icons.play_arrow
                                      ),
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      iconSize: 40,
                                      onPressed: () {
                                        if (_videoPlayerController != null) {
                                          if (_videoPlayerController!.value.isPlaying) {
                                            _videoPlayerController!.pause();
                                          } else {
                                            _videoPlayerController!.play();
                                          }
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                  Semantics(
                                    label: "Yayını Kapat",
                                    button: true,
                                    child: IconButton(
                                      icon: const Icon(Icons.stop),
                                      color: Theme.of(context).colorScheme.error,
                                      iconSize: 40,
                                      onPressed: _stopTv,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        )
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
