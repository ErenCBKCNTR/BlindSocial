import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  late AudioPlayer _audioPlayer;
  int? _playingRadioIndex;

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  int? _playingTvIndex;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudioSession();
    _fetchRadios();
    _fetchTvs();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> _fetchRadios() async {
    try {
      final response = await http.get(Uri.parse('http://de1.api.radio-browser.info/json/stations/search?countrycode=TR&limit=20'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          radioList = data.map((item) {
            return {
              'name': (item['name'] ?? 'İsimsiz Radyo').toString().trim(),
              'url': item['url'].toString()
            };
          }).toList();
          isLoadingRadios = false;
        });
      } else {
        setState(() {
          isLoadingRadios = false;
        });
      }
    } catch (e) {
      debugPrint("Radio fetch error: $e");
      setState(() {
        isLoadingRadios = false;
      });
    }
  }

  Future<void> _fetchTvs() async {
    try {
      final response = await http.get(Uri.parse('https://iptv-org.github.io/iptv/countries/tr.m3u'));
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        List<Map<String, String>> parsedList = [];
        String? currentName;

        for (final line in lines) {
          if (line.startsWith('#EXTINF:')) {
            final commaIndex = line.indexOf(',');
            if (commaIndex != -1) {
              currentName = line.substring(commaIndex + 1).trim();
            }
          } else if (line.isNotEmpty && !line.startsWith('#')) {
            if (currentName != null) {
              parsedList.add({
                'name': currentName,
                'url': line.trim(),
              });
              currentName = null;
            }
          }
        }

        setState(() {
          tvList = parsedList.take(20).toList(); // Limit to 20 for performance
          isLoadingTvs = false;
        });
      } else {
        setState(() {
          isLoadingTvs = false;
        });
      }
    } catch (e) {
      debugPrint("TV fetch error: $e");
      setState(() {
        isLoadingTvs = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
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

      // Stop TV if playing
      _stopTv();

      setState(() {
        _playingRadioIndex = index;
      });
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(radioList[index]['url']!);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Radio Play Error: $e");
    }
  }

  void _stopRadio() {
    _audioPlayer.stop();
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
                  final isAudioPlaying = isPlaying && _audioPlayer.playing;

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
