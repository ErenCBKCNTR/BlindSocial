import 'package:flutter/material.dart';
import 'package:blind_social/theme/app_fonts.dart';
import 'package:audio_session/audio_session.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'live_radio_player_screen.dart';
import '../services/audio_handler.dart';
import '../services/broadcast_record_manager.dart';

class LiveMediaScreen extends StatefulWidget {
  const LiveMediaScreen({super.key});

  @override
  State<LiveMediaScreen> createState() => _LiveMediaScreenState();
}

class _LiveMediaScreenState extends State<LiveMediaScreen> {
  List<Map<String, String>> radioList = [];
  List<Map<String, String>> tvList = [];
  List<Map<String, dynamic>> savedRecords = [];
  bool isLoadingRadios = true;
  bool isLoadingTvs = true;

  Player? _player;
  Player? _recordPlayer;
  String? _playingRecordPath;
  VideoController? _videoController;
  int? _playingTvIndex;

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    _fetchRadios();
    _fetchTvs();
    _fetchSavedRecords();
    _recordPlayer = Player();
    _recordPlayer?.stream.completed.listen((completed) {
      if (completed && mounted) {
        setState(() {
          _playingRecordPath = null;
        });
      }
    });
  }

  Future<void> _fetchSavedRecords() async {
    final records = await broadcastRecordManager.getSavedRecords();
    setState(() {
      savedRecords = records;
    });
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> _fetchRadios() async {
    final List<Map<String, String>> predefinedRadios = [
      {'name': 'Alem FM', 'url': 'https://scturkmedya.radyotvonline.com/stream/80/'},
      {'name': 'JoyTürk', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/JOY_TURK_SC'},
      {'name': 'Joy FM', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/JOY_FM_SC'},
      {'name': 'Metro FM', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/METRO_FM_SC'},
      {'name': 'Pal FM', 'url': 'https://moondigitaledge.radyotvonline.net/palfm/playlist.m3u8'},
      {'name': 'PowerTürk', 'url': 'https://listen.powerapp.com.tr/powerturk/mpeg/icecast.audio'},
      {'name': 'Süper FM', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/SUPER_FM_SC'},
      {'name': 'Virgin Radio', 'url': 'https://playerservices.streamtheworld.com/api/livestream-redirect/VIRGIN_RADIO_SC'},
      {'name': 'Radyo D', 'url': 'https://17733.live.streamtheworld.com/RADYO_D.mp3'},
      {'name': 'Show Radyo', 'url': 'http://46.20.7.104:8020/stream'}
    ];

    predefinedRadios.sort((a, b) => a['name']!.compareTo(b['name']!));

    setState(() {
      radioList = predefinedRadios;
      isLoadingRadios = false;
    });
  }

  Future<void> _fetchTvs() async {
    final List<Map<String, String>> predefinedTvs = [
      {'name': 'TRT 1', 'url': 'https://trt.daioncdn.net/trt-1/master.m3u8?app=web'},
      {'name': 'ATV', 'url': 'http://89.187.191.41/ATV-HD-TR/video.m3u8'},
      {'name': 'Kanal D', 'url': 'https://demiroren.daioncdn.net/kanald/kanald.m3u8?app=kanald_web&ce=3'},
      {'name': 'Show TV', 'url': 'https://jmp2.uk/plu-5db6a697d5f34a000934cd13.m3u8'},
      {'name': 'Star TV', 'url': 'https://viamotionhsi.netplus.ch/live/eds/startv/browser-HLS8/startv.m3u8'}
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
    _recordPlayer?.dispose();
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
      body: RefreshIndicator(
        onRefresh: _fetchSavedRecords,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildRadioSection(),
            const SizedBox(height: 20),
            _buildTvSection(),
            const SizedBox(height: 20),
            _buildSavedRecordsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedRecordsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(Icons.mic, size: 40, color: Theme.of(context).colorScheme.primary),
        title: Text('Kaydedilen Yayınlar', style: TextStyle(fontSize: AppFonts.size(24), fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        onExpansionChanged: (expanded) {
          if (expanded) {
            _fetchSavedRecords();
          }
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: savedRecords.isEmpty
                ? const Center(child: Text("Henüz kaydedilmiş bir yayın yok."))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: savedRecords.length,
                    itemBuilder: (context, index) {
                      final record = savedRecords[index];
                      final stationName = record['stationName'];
                      final filePath = record['filePath'];
                      final durationSeconds = record['durationInSeconds'] as int;
                      final timestamp = record['timestamp'] as int;

                      final isPlaying = _playingRecordPath == filePath;

                      final durationStr = "${durationSeconds ~/ 60}:${(durationSeconds % 60).toString().padLeft(2, '0')}";
                      final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(timestamp));

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(stationName, style: TextStyle(fontSize: AppFonts.size(18), fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(dateStr, style: TextStyle(fontSize: AppFonts.size(14), color: Colors.grey)),
                                    Text("Süre: $durationStr", style: TextStyle(fontSize: AppFonts.size(14), color: Colors.grey)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_fill, size: 36, color: Theme.of(context).colorScheme.secondary),
                                onPressed: () async {
                                  if (isPlaying) {
                                    await _recordPlayer?.stop();
                                    setState(() {
                                      _playingRecordPath = null;
                                    });
                                  } else {
                                    _stopTv();
                                    audioHandler.stop();
                                    await _recordPlayer?.open(Media('file://$filePath'));
                                    await _recordPlayer?.play();
                                    setState(() {
                                      _playingRecordPath = filePath;
                                    });
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.share, size: 30),
                                onPressed: () {
                                  Share.shareXFiles([XFile(filePath)], subject: '$stationName Radyo Kaydı ($dateStr)');
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  if (isPlaying) {
                                    await _recordPlayer?.stop();
                                    setState(() {
                                      _playingRecordPath = null;
                                    });
                                  }
                                  await broadcastRecordManager.deleteRecord(filePath);
                                  _fetchSavedRecords();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(Icons.radio, size: 40, color: Theme.of(context).colorScheme.primary),
        title: Text('Radyo Kanalları', style: TextStyle(fontSize: AppFonts.size(24), fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: isLoadingRadios
                ? const Center(child: CircularProgressIndicator())
                : radioList.isEmpty
                    ? const Center(child: Text("Radyo kanalları bulunamadı."))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: radioList.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.headset),
                            title: Text(radioList[index]['name']!, style: TextStyle(fontSize: AppFonts.size(18))),
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
          ),
        ],
      ),
    );
  }

  Widget _buildTvSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(Icons.tv, size: 40, color: Theme.of(context).colorScheme.primary),
        title: Text('Televizyon Kanalları', style: TextStyle(fontSize: AppFonts.size(24), fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: isLoadingTvs
                ? const Center(child: CircularProgressIndicator())
                : tvList.isEmpty
                    ? const Center(child: Text("Televizyon kanalları bulunamadı."))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tvList.length,
                        itemBuilder: (context, index) {
                          final isPlaying = _playingTvIndex == index;

                          return ExpansionTile(
                            leading: const Icon(Icons.live_tv),
                            title: Text(tvList[index]['name']!, style: TextStyle(fontSize: AppFonts.size(18))),
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
                                                    if (snapshot.data == true) {
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
                                              return TextButton.icon(
                                                icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 30),
                                                label: Text(playing ? "Durdur" : "Başlat"),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                                onPressed: () {
                                                  if (_player != null) {
                                                    _player!.playOrPause();
                                                  }
                                                },
                                              );
                                            },
                                          ),
                                          TextButton.icon(
                                            icon: const Icon(Icons.stop, size: 30),
                                            label: const Text("Kapat"),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Theme.of(context).colorScheme.error,
                                            ),
                                            onPressed: _stopTv,
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
          ),
        ],
      ),
    );
  }
}
