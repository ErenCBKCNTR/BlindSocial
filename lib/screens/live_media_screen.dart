import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'live_radio_player_screen.dart';
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

  Player? _player;
  VideoController? _videoController;
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
      {'name': 'JoyTürk', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/JOY_TURK_SC'},
      {'name': 'Joy FM', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/JOY_FM_SC'},
      {'name': 'Kafa Radyo', 'url': 'https://moondigitaledge.radyotvonline.net/kafaradyo/playlist.m3u8'},
      {'name': 'Metro FM', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/METRO_FM_SC'},
      {'name': 'NTV Radyo', 'url': 'https://moondigitaledge.radyotvonline.net/ntvradyo/playlist.m3u8'},
      {'name': 'Pal FM', 'url': 'https://moondigitaledge.radyotvonline.net/palfm/playlist.m3u8'},
      {'name': 'PowerTürk', 'url': 'https://listen.powerapp.com.tr/powerturk/mpeg/icecast.audio'},
      {'name': 'Süper FM', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/SUPER_FM_SC'},
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
      {'name': 'TRT 1', 'url': 'https://tv-trt1.medya.trt.com.tr/master_720.m3u8'},
      {'name': 'TRT Haber', 'url': 'https://tv-trthaber.medya.trt.com.tr/master_720.m3u8'},
      {'name': 'TRT Müzik', 'url': 'https://tv-trtmuzik.medya.trt.com.tr/master_720.m3u8'},
      {'name': 'TRT Çocuk', 'url': 'https://tv-trtcocuk.medya.trt.com.tr/master_720.m3u8'},
      {'name': 'TRT Kurdî', 'url': 'https://tv-trtkurdi.medya.trt.com.tr/master_720.m3u8'},
      {'name': 'TRT Türk', 'url': 'https://tv-trtturk.medya.trt.com.tr/master_720.m3u8'},
      {'name': 'TRT Avaz', 'url': 'https://tv-trtavaz.medya.trt.com.tr/master_720.m3u8'},
      {'name': 'TRT World', 'url': 'https://tv-trtworld.medya.trt.com.tr/master_720.m3u8'}
    ];

    predefinedTvs.sort((a, b) => a['name']!.compareTo(b['name']!));

    setState(() {
      tvList = predefinedTvs;
      isLoadingTvs = false;
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }


  Future<void> _playTv(int index) async {
    try {
      if (_playingTvIndex == index) {
        // Just expanding/collapsing logic handles play state
        return;
      }

      // Stop radio if playing
      audioHandler.stop();

      // Stop previous TV
      _stopTv();

      setState(() {
        _playingTvIndex = index;
      });

      _player = Player();
      _videoController = VideoController(_player!);

      await _player!.open(Media(tvList[index]['url']!));
      await _player!.play();

      setState(() {});
    } catch (e) {
      debugPrint("TV Play Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yayın şu an kullanılamıyor')),
        );
      }
      _stopTv();
    }
  }

  void _stopTv() {
    _player?.dispose();
    _player = null;
    _videoController = null;
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
                  return ListTile(
                    leading: const Icon(Icons.headset),
                    title: Text(radioList[index]['name']!, style: const TextStyle(fontSize: 18)),
                    trailing: Icon(Icons.chevron_right, size: 36, color: Theme.of(context).colorScheme.secondary),
                    onTap: () {
                      _stopTv();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LiveRadioPlayerScreen(radio: radioList[index]),
                        ),
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
                              child: _videoController != null
                                  ? Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Video(
                                          controller: _videoController!,
                                          controls: NoVideoControls,
                                        ),
                                        StreamBuilder<bool>(
                                          stream: _player?.stream.buffering,
                                          builder: (context, snapshot) {
                                            final isBuffering = snapshot.data ?? true;
                                            if (isBuffering) {
                                              return const CircularProgressIndicator();
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ],
                                    )
                                  : const Center(child: CircularProgressIndicator()),
                            ),
                            Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  StreamBuilder<bool>(
                                    stream: _player?.stream.playing,
                                    builder: (context, snapshot) {
                                      final playing = snapshot.data ?? false;
                                      return Semantics(
                                        label: playing ? "Televizyonu Durdur" : "Televizyonu Başlat",
                                        button: true,
                                        child: IconButton(
                                          icon: Icon(
                                            playing ? Icons.pause : Icons.play_arrow
                                          ),
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          iconSize: 40,
                                          onPressed: () {
                                            if (_player != null) {
                                              _player!.playOrPause();
                                            }
                                          },
                                        ),
                                      );
                                    },
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
