import 'dart:async';
import 'package:blind_social/theme/app_fonts.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:blind_social/widgets/custom_bottom_sheet.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:flutter/semantics.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

const String liveKitUrl = 'wss://bs-app-l1mgfyed.livekit.cloud';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final AudioRecorder? audioRecorder;
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final FirebaseStorage? storage;
  final FirebaseFunctions? functions;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.audioRecorder,
    this.auth,
    this.firestore,
    this.storage,
    this.functions,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  late final _auth = widget.auth ?? FirebaseAuth.instance;
  final _scrollController = ScrollController();
  late final _audioRecorder = widget.audioRecorder ?? AudioRecorder();
  final _audioPlayer = AudioPlayer();

  String? _cachedDisplayName;
  String? _cachedTtl;

  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDuration = 0;

  final List<int> _receivedMediaBytes = [];
  Timer? _recordTimer;

  Room? _room;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isJoining = false;
  String _statusMessage = "";

  late final Stream<DocumentSnapshot> _roomStream;
  late final Stream<QuerySnapshot> _messagesStream;
  String? _currentlyPlayingMessageId;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isSending = false;


  // Media Streaming State
  String? _selectedMediaFileName;
  String? _selectedMediaFilePath; // Required for reading file
  bool _isMediaPlaying = false;
  double _mediaVolume = 0.85;
  double _mediaProgress = 0.0;
  // Microphone Settings State
  bool _isPTTMode = false;
  bool _echoCancellation = true;
  bool _noiseSuppression = true;
  bool _autoGain = true;
  double _voiceGain = 1.0;
  double _vadSensitivity = 0.5;

  // Participant Volumes
  final Map<String, double> _participantVolumes = {};

  @override
  void initState() {
    _speech = stt.SpeechToText();
    super.initState();
    _loadMicrophoneSettings();
    WidgetsBinding.instance.addObserver(this);
    // ⚡ Bolt: Cache Firestore streams in initState rather than build() to prevent
    // re-subscribing and fetching all historical documents on every widget rebuild
    // (e.g., when typing a message).
    _roomStream = (widget.firestore ?? FirebaseFirestore.instance)
        .collection('chat_rooms')
        .doc(widget.roomId)
        .snapshots();

    final now = Timestamp.now();
    // Use `now` for the initial server query to prevent downloading the entire
    // history of expired messages, saving significant read operations.
    _messagesStream = (widget.firestore ?? FirebaseFirestore.instance)
        .collection('chat_rooms')
        .doc(widget.roomId)
        .collection('messages')
        .where('expires_at', isGreaterThan: now)
        .orderBy('expires_at', descending: true)
        .snapshots();
    _addParticipant();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        if (mounted) {
          setState(() {
            _currentlyPlayingMessageId = null;
          });
        }
      }
    });
  }

  Future<void> _loadMicrophoneSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isPTTMode = prefs.getBool('mic_ptt_mode') ?? false;
        _echoCancellation = prefs.getBool('mic_echo_cancellation') ?? true;
        _noiseSuppression = prefs.getBool('mic_noise_suppression') ?? true;
        _autoGain = prefs.getBool('mic_auto_gain') ?? true;
        _voiceGain = prefs.getDouble('mic_voice_gain') ?? 1.0;
        _vadSensitivity = prefs.getDouble('mic_vad_sensitivity') ?? 0.5;
      });
    }
  }



  Future<void> _addParticipant() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final roomRef = (widget.firestore ?? FirebaseFirestore.instance)
        .collection('chat_rooms')
        .doc(widget.roomId);

    await (widget.firestore ?? FirebaseFirestore.instance).runTransaction((
      transaction,
    ) async {
      final snapshot = await transaction.get(roomRef);
      final userDoc = await transaction.get(
        (widget.firestore ?? FirebaseFirestore.instance)
            .collection('users')
            .doc(user.uid),
      );

      if (!snapshot.exists) return;

      final userData = userDoc.data() ?? {};
      final displayName = userData['display_preference'] == 'fullName'
          ? userData['fullName'] ?? 'Anonim'
          : userData['username'] ?? 'Anonim';

      if (mounted) {
        setState(() {
          _cachedDisplayName = displayName;
        });
      }

      transaction.update(roomRef, {
        'currentParticipants': FieldValue.increment(1),
      });

      final participantRef = roomRef.collection('participants').doc(user.uid);

      transaction.set(participantRef, {
        'uid': user.uid,
        'displayName': displayName,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _removeParticipant() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final roomRef = (widget.firestore ?? FirebaseFirestore.instance)
        .collection('chat_rooms')
        .doc(widget.roomId);

    try {
      await roomRef.update({'currentParticipants': FieldValue.increment(-1)});
      final participantRef = roomRef.collection('participants').doc(user.uid);
      await participantRef.delete();
    } catch (e) {
      debugPrint('Participant remove error: $e');
    }
  }

  Future<String> _fetchLiveKitToken() async {
    final user = _auth.currentUser;
    final identity =
        _cachedDisplayName ??
        user?.uid ??
        'anonymous_${DateTime.now().millisecondsSinceEpoch}';

    final functions =
        widget.functions ??
        FirebaseFunctions.instanceFor(region: 'us-central1');
    final httpsCallable = functions.httpsCallable('generateLiveKitToken');

    if (FirebaseAuth.instance.currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.authStateChanges().firstWhere(
          (user) => user != null,
        );
      }
    }

    await FirebaseAuth.instance.currentUser?.getIdToken(true);
    print('CURRENT UID: ${FirebaseAuth.instance.currentUser?.uid}');

    final response = await httpsCallable.call({
      'room': widget.roomId,
      'identity': identity,
    });

    return response.data['token'] as String;
  }

  Future<void> _joinVoiceChannel() async {
    if (_isJoining) return;

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Mikrofon izni verilmedi. Sesli sohbete katılmak için lütfen izin verin.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      if (_room != null) {
        await _room!.disconnect();
      }

      final token = await _fetchLiveKitToken();
      _room = Room();

      await _room!.connect(liveKitUrl, token);

      _room!.events.listen((event) {
        switch (event) {
          case ParticipantConnectedEvent(:final participant):
            if (mounted) {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${participant.identity} sesli kanala katıldı.',
                  ),
                ),
              );
              SystemSound.play(SystemSoundType.click);
            }
          case ParticipantDisconnectedEvent(:final participant):
            if (mounted) {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${participant.identity} sesli kanaldan ayrıldı.',
                  ),
                ),
              );
              SystemSound.play(SystemSoundType.click);
            }
          case ActiveSpeakersChangedEvent():
            if (mounted) {
              setState(() {});
            }
          case TrackMutedEvent() || TrackUnmutedEvent():
            if (mounted) {
              setState(() {});
            }
        }
      });

      // Apply correct initial microphone state with options
      if (_isPTTMode) {
        // Start muted in PTT mode
        await _setMicrophoneEnabled(false);
      } else {
        // Start unmuted in VAD mode
        await _setMicrophoneEnabled(true);
      }

      setState(() {
        _isJoined = true;
        _isJoining = false;
        _statusMessage = "${widget.roomName} odasına başarıyla bağlanıldı";
      });

      // Play audio cue
      SystemSound.play(SystemSoundType.click);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.roomName} odasına başarıyla bağlanıldı'),
          ),
        );
      }
    } catch (e) {
      debugPrint('LiveKit connection error: $e');
      setState(() {
        _isJoining = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı Hatası: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _leaveVoiceChannel() async {
    await _room?.disconnect();
    // Play audio cue
    SystemSound.play(SystemSoundType.click);
    setState(() {
      _isJoined = false;
      _statusMessage = "Sesli kanaldan ayrılındı.";
    });
  }

  Future<void> _setMicrophoneEnabled(bool enabled) async {
    if (_room?.localParticipant == null) return;

    // We update LiveKit AudioCaptureOptions based on settings when enabling the mic
    final audioOptions = AudioCaptureOptions(
      echoCancellation: _echoCancellation,
      noiseSuppression: _noiseSuppression,
      autoGainControl: _autoGain,
    );

    // According to memory: "To dynamically apply changes to audio filters like echo cancellation,
    // noise suppression, or gain in LiveKit, pass an updated AudioCaptureOptions object directly
    // to localParticipant.setMicrophoneEnabled(enabled, audioCaptureOptions: ...)".
    // If the mic is ALREADY enabled and we are just updating settings, we might need to
    // disable and re-enable it quickly to force the hardware parameters to apply.
    if (_room!.localParticipant!.isMicrophoneEnabled() && enabled) {
      await _room!.localParticipant!.setMicrophoneEnabled(false);
    }

    await _room!.localParticipant!.setMicrophoneEnabled(
      enabled,
      audioCaptureOptions: audioOptions,
    );

    if (mounted) {
      setState(() {
        _isMuted = !enabled;
        _statusMessage = _isMuted ? "Mikrofon kapatıldı" : "Mikrofon açıldı";
      });
    }
  }



  void _showMicrophoneSettingsModal() {
    CustomBottomSheet.show(
      context: context,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mikrofon ve Ses Ayarları',
                    style: TextStyle(
                      fontSize: AppFonts.size(22),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bas Konuş & Ses Aktivasyonu Butonları
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: 'Bas-Konuş Modu',
                          selected: _isPTTMode,
                          child: ElevatedButton(
                            onPressed: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('mic_ptt_mode', true);
                              setModalState(() => _isPTTMode = true);
                              setState(() => _isPTTMode = true);
                              if (_isJoined) _setMicrophoneEnabled(false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isPTTMode
                                  ? Colors.amber
                                  : Theme.of(context).colorScheme.surface,
                              foregroundColor: _isPTTMode
                                  ? Colors.black
                                  : Theme.of(context).colorScheme.onSurface,
                              side: BorderSide(
                                color: _isPTTMode
                                    ? Colors.transparent
                                    : Colors.grey,
                              ),
                            ),
                            child: const Text('Bas-Konuş'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          label: 'Ses Aktivasyonu Modu',
                          selected: !_isPTTMode,
                          child: ElevatedButton(
                            onPressed: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('mic_ptt_mode', false);
                              setModalState(() => _isPTTMode = false);
                              setState(() => _isPTTMode = false);
                              if (_isJoined) _setMicrophoneEnabled(true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: !_isPTTMode
                                  ? Colors.amber
                                  : Theme.of(context).colorScheme.surface,
                              foregroundColor: !_isPTTMode
                                  ? Colors.black
                                  : Theme.of(context).colorScheme.onSurface,
                              side: BorderSide(
                                color: !_isPTTMode
                                    ? Colors.transparent
                                    : Colors.grey,
                              ),
                            ),
                            child: const Text('Ses Aktivasyonu'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Eko İptali
                  Semantics(
                    toggled: _echoCancellation,
                    label: 'Eko İptali. Hoparlör yankısını önler.',
                    child: ExcludeSemantics(
                      child: SwitchListTile(
                        title: const Text('Eko İptali'),
                        value: _echoCancellation,
                        activeColor: Colors.amber,
                        onChanged: (val) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('mic_echo_cancellation', val);
                          setModalState(() => _echoCancellation = val);
                          setState(() => _echoCancellation = val);
                          // Canlı güncelleme
                          if (_isJoined && !_isMuted)
                            _setMicrophoneEnabled(true);
                        },
                      ),
                    ),
                  ),

                  // Gürültü Bastırma
                  Semantics(
                    toggled: _noiseSuppression,
                    label: 'Gürültü Bastırma. Arka plan seslerini azaltır.',
                    child: ExcludeSemantics(
                      child: SwitchListTile(
                        title: const Text('Gürültü Bastırma'),
                        value: _noiseSuppression,
                        activeColor: Colors.amber,
                        onChanged: (val) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('mic_noise_suppression', val);
                          setModalState(() => _noiseSuppression = val);
                          setState(() => _noiseSuppression = val);
                          if (_isJoined && !_isMuted)
                            _setMicrophoneEnabled(true);
                        },
                      ),
                    ),
                  ),

                  // Otomatik Kazanç
                  Semantics(
                    toggled: _autoGain,
                    label: 'Otomatik Ses Kazancı. Ses seviyesini dengeler.',
                    child: ExcludeSemantics(
                      child: SwitchListTile(
                        title: const Text('Otomatik Ses Kazancı'),
                        value: _autoGain,
                        activeColor: Colors.amber,
                        onChanged: (val) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('mic_auto_gain', val);
                          setModalState(() => _autoGain = val);
                          setState(() => _autoGain = val);
                          if (_isJoined && !_isMuted)
                            _setMicrophoneEnabled(true);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Ses Kazancı Slider
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Ses Kazancı',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppFonts.size(16),
                        ),
                      ),
                    ),
                  ),
                  Slider(
                    value: _voiceGain,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.amber,
                    semanticFormatterCallback: (double value) =>
                        'Ses Kazancı: Yüzde ${(value * 100).round()}',
                    onChanged: (val) {
                      setModalState(() => _voiceGain = val);
                    },
                    onChangeEnd: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('mic_voice_gain', val);
                      setState(() => _voiceGain = val);
                    },
                  ),

                  // VAD Hassasiyeti Slider
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'VAD Hassasiyeti',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppFonts.size(16),
                        ),
                      ),
                    ),
                  ),
                  Slider(
                    value: _vadSensitivity,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.amber,
                    semanticFormatterCallback: (double value) =>
                        'VAD Hassasiyeti: Yüzde ${(value * 100).round()}',
                    onChanged: (val) {
                      setModalState(() => _vadSensitivity = val);
                    },
                    onChangeEnd: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('mic_vad_sensitivity', val);
                      setState(() => _vadSensitivity = val);
                    },
                  ),

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _removeParticipant();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeParticipant();
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordTimer?.cancel();
    _room?.disconnect();
    super.dispose();
  }


  Future<void> _pickMediaFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedMediaFilePath = result.files.single.path;
          _selectedMediaFileName = result.files.single.name;
          _isMediaPlaying = false;
          _mediaProgress = 0.0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Medya dosyası seçildi: $_selectedMediaFileName')),
          );
        }
      }
    } catch (e) {
      debugPrint('File picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medya dosyası seçilirken hata oluştu.')),
        );
      }
    }
  }
  Future<void> _playMediaFile() async {
    if (_selectedMediaFilePath == null || _room?.localParticipant == null) return;

    setState(() {
      _isMediaPlaying = true;
    });

    try {
      final file = File(_selectedMediaFilePath!);
      if (!file.existsSync()) return;

      // Mock streaming duration setup
      const chunkSize = 1024 * 16; // 16 KB chunks
      final bytes = await file.readAsBytes();

      // We process streaming in a separate async flow to not block UI
      _streamMedia(bytes, chunkSize);

    } catch (e) {
      debugPrint('Error playing media: $e');
      setState(() {
        _isMediaPlaying = false;
      });
    }
  }

  Future<void> _streamMedia(Uint8List bytes, int chunkSize) async {
    int offset = 0;
    while (_isMediaPlaying && offset < bytes.length) {
      int end = offset + chunkSize;
      if (end > bytes.length) end = bytes.length;
      final chunk = bytes.sublist(offset, end);

      try {
        await _room?.localParticipant?.publishData(chunk, topic: 'media_stream');
      } catch (e) {
        debugPrint('Media stream error: $e');
      }

      offset = end;
      if (mounted) {
        setState(() {
          _mediaProgress = offset / bytes.length;
        });
      }
      // Simple delay to simulate streaming rate
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (offset >= bytes.length) {
      _stopMediaFile();
    }
  }

  Future<void> _pauseMediaFile() async {
    setState(() {
      _isMediaPlaying = false;
    });
  }

  Future<void> _stopMediaFile() async {
    setState(() {
      _isMediaPlaying = false;
      _mediaProgress = 0.0;
    });
    await _audioPlayer.stop();
    await _room?.localParticipant?.publishData(utf8.encode('media_stream_stop'), topic: 'media_control');
  }

  Future<void> _playReceivedMedia() async {
    if (_receivedMediaBytes.isEmpty) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/received_media_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await file.writeAsBytes(_receivedMediaBytes);
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('Error playing received media: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/record_${DateTime.now().millisecondsSinceEpoch}.m4a';

        final config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
        );

        await _audioRecorder.start(config, path: path);

        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordDuration = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!_isPaused) {
            setState(() {
              _recordDuration++;
            });
            if (_recordDuration >= 60) {
              _stopRecording();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Recording error: $e');
    }
  }

  Future<void> _pauseRecording() async {
    if (_isRecording && !_isPaused) {
      await _audioRecorder.pause();
      setState(() {
        _isPaused = true;
      });
    }
  }

  Future<void> _resumeRecording() async {
    if (_isRecording && _isPaused) {
      await _audioRecorder.resume();
      setState(() {
        _isPaused = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        _uploadVoiceMessage(path);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesli mesaj gönderilemedi hata')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesli mesaj gönderilemedi hata')),
        );
      }
    }

    if (_recordDuration >= 60) {
      // ignore: deprecated_member_use
      SemanticsService.announce(
        'Maksimum kayıt süresi olan 60 saniyeye ulaşıldı. Kayıt durduruldu ve gönderiliyor.',
        TextDirection.ltr,
      );
    }
  }

  Future<void> _uploadVoiceMessage(String path) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _statusMessage = "Sesli mesaj yükleniyor...";
    });

    try {
      // Fetch numeric IDs for naming convention
      String userNumericId = '';
      final userDoc = await (widget.firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()!['numericId'] != null) {
        userNumericId = userDoc.data()!['numericId'].toString();
      } else {
        userNumericId = 'UnknownUser';
      }

      String roomNumericId = '';
      final roomDoc = await (widget.firestore ?? FirebaseFirestore.instance)
          .collection('chat_rooms')
          .doc(widget.roomId)
          .get();
      if (roomDoc.exists && roomDoc.data()!['numericId'] != null) {
        roomNumericId = roomDoc.data()!['numericId'].toString();
      } else {
        roomNumericId = 'UnknownRoom';
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${roomNumericId}_U${userNumericId}_$timestamp.m4a';

      final ref = (widget.storage ?? FirebaseStorage.instance)
          .ref()
          .child('recordings')
          .child(roomNumericId)
          .child(fileName);

      await ref.putFile(File(path));
      final url = await ref.getDownloadURL();

      await _sendMessage(
        type: 'audio',
        audioUrl: url,
        duration: _recordDuration,
      );

      setState(() {
        _statusMessage = "Sesli mesaj gönderildi.";
      });
    } catch (e) {
      debugPrint('Upload error: $e');
      setState(() {
        _statusMessage = "Sesli mesaj yüklenirken hata oluştu.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _deleteMessage(String messageId, String? audioUrl) async {
    try {
      await (widget.firestore ?? FirebaseFirestore.instance)
          .collection('chat_rooms')
          .doc(widget.roomId)
          .collection('messages')
          .doc(messageId)
          .delete();

      if (audioUrl != null) {
        final ref =
            widget.storage?.refFromURL(audioUrl) ??
            FirebaseStorage.instance.refFromURL(audioUrl);
        await ref.delete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesaj silinirken bir hata oluştu.')),
        );
      }
    }
  }

  Future<void> _sendMessage({
    String type = 'text',
    String? audioUrl,
    int? duration,
  }) async {
    if (_isSending) return;

    final messageText = _messageController.text.trim();
    if (type == 'text' && messageText.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isSending = true;
    });

    if (_cachedDisplayName == null) {
      final userDoc = await (widget.firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() as Map<String, dynamic>;
      _cachedDisplayName = userData['display_preference'] == 'fullName'
          ? userData['fullName']
          : userData['username'];
    }

    if (_cachedTtl == null) {
      final roomDoc = await (widget.firestore ?? FirebaseFirestore.instance)
          .collection('chat_rooms')
          .doc(widget.roomId)
          .get();
      final roomData = roomDoc.data() as Map<String, dynamic>;
      _cachedTtl = roomData['ttl'] ?? '24h';
    }

    final displayName = _cachedDisplayName ?? 'Anonim';
    final ttl = _cachedTtl ?? '24h';

    DateTime expiresAt = DateTime.now();
    if (ttl == '24h') {
      expiresAt = expiresAt.add(const Duration(hours: 24));
    } else if (ttl == '3d') {
      expiresAt = expiresAt.add(const Duration(days: 3));
    } else if (ttl == '7d') {
      expiresAt = expiresAt.add(const Duration(days: 7));
    }

    try {
      await (widget.firestore ?? FirebaseFirestore.instance)
          .collection('chat_rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
            'text': type == 'text' ? messageText : '',
            'type': type,
            'audioUrl': audioUrl,
            'duration': duration,
            'senderId': user.uid,
            'senderName': displayName,
            'timestamp': FieldValue.serverTimestamp(),
            'expires_at': Timestamp.fromDate(expiresAt),
          });

      if (type == 'text') _messageController.clear();
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showParticipantList() {
    CustomBottomSheet.show(
      context: context,
      child: StreamBuilder<QuerySnapshot>(
        stream: (widget.firestore ?? FirebaseFirestore.instance)
            .collection('chat_rooms')
            .doc(widget.roomId)
            .collection('participants')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final participants = snapshot.data!.docs;

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Katılımcılar',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: AppFonts.size(24),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Katılımcılar listesini kapat',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final pDoc = participants[index];
                    final p = pDoc.data() as Map<String, dynamic>;
                    final name = p['displayName'] ?? 'Anonim';
                    final uid = pDoc.id;
                    final isMe = uid == _auth.currentUser?.uid;

                    return StreamBuilder<DocumentSnapshot>(
                      // ⚡ Bolt: Use the already cached _roomStream instead of creating N streams per participant
                      stream: _roomStream,
                      builder: (context, roomSnap) {
                        final isCreator =
                            roomSnap.hasData &&
                            (roomSnap.data!.data()
                                    as Map<String, dynamic>?)?['creatorId'] ==
                                _auth.currentUser?.uid;

                        return ListTile(
                          leading: Icon(
                            Icons.person,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          title: Text(
                            name + (isMe ? ' (Sen)' : ''),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: AppFonts.size(18),
                            ),
                          ),
                          trailing: (isCreator && !isMe)
                              ? IconButton(
                                  icon: Icon(
                                    Icons.mic_off,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Susturma özelliği eklenecektir.',
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteRoom() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Odayı Sil',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        content: Text(
          'Bu odayı kalıcı olarak silmek istediğinize emin misiniz?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () async {
              await (widget.firestore ?? FirebaseFirestore.instance)
                  .collection('chat_rooms')
                  .doc(widget.roomId)
                  .delete();
              if (context.mounted) {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // leave chat screen
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('SİL'),
          ),
        ],
      ),
    );
  }

  void _showRoomDescription() {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          future: (widget.firestore ?? FirebaseFirestore.instance)
              .collection('chat_rooms')
              .doc(widget.roomId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(content: Text('Yükleniyor...'));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const AlertDialog(
                content: Text('Oda açıklaması bulunamadı.'),
              );
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final description =
                data['description'] ?? 'Oda açıklaması bulunamadı.';
            final isCreator = data['creatorId'] == _auth.currentUser?.uid;

            return AlertDialog(
              title: Text('${widget.roomName} isimli odanın açıklaması'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              content: Text(
                description,
                style: TextStyle(fontSize: AppFonts.size(18), height: 1.5),
              ),
              actions: [
                if (isCreator)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _editRoomDescription(description);
                    },
                    child: const Text('Açıklamayı Düzenle'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kapat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editRoomDescription(String currentDescription) {
    final TextEditingController controller = TextEditingController(
      text:
          currentDescription == 'Oda açıklaması bulunamadı.' ||
              currentDescription == 'Bu oda için henüz bir açıklama eklenmemiş.'
          ? ''
          : currentDescription,
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Oda Açıklamasını Düzenle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    maxLength: 240,
                    decoration: const InputDecoration(
                      hintText: 'Oda açıklamasını buraya yazın...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                        size: 30,
                      ),
                      tooltip: _isListening
                          ? 'Dinleniyor... Kapatmak için dokunun'
                          : 'Dikte için dokunun',
                      onPressed: () async {
                        if (!_isListening) {
                          bool available = await _speech.initialize(
                            onStatus: (val) {
                              if (val == 'done' || val == 'notListening') {
                                if (mounted) {
                                  setModalState(() => _isListening = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sesli yazma durduruldu'),
                                    ),
                                  );
                                  SemanticsService.announce(
                                    'Sesli yazma durduruldu',
                                    TextDirection.ltr,
                                  );
                                }
                              }
                            },
                            onError: (val) {
                              if (mounted) {
                                setModalState(() => _isListening = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sesli yazma durduruldu'),
                                  ),
                                );
                                SemanticsService.announce(
                                  'Sesli yazma durduruldu',
                                  TextDirection.ltr,
                                );
                              }
                            },
                          );
                          if (available) {
                            if (mounted) {
                              setModalState(() => _isListening = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sesli yazma başlatıldı'),
                                ),
                              );
                              SemanticsService.announce(
                                'Sesli yazma başlatıldı',
                                TextDirection.ltr,
                              );
                            }
                            _speech.listen(
                              localeId: 'tr_TR',
                              onResult: (val) {
                                if (mounted) {
                                  setModalState(() {
                                    controller.text = val.recognizedWords;
                                  });
                                }
                              },
                            );
                          }
                        } else {
                          if (mounted) {
                            setModalState(() => _isListening = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sesli yazma durduruldu'),
                              ),
                            );
                            SemanticsService.announce(
                              'Sesli yazma durduruldu',
                              TextDirection.ltr,
                            );
                          }
                          _speech.stop();
                        }
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (_isListening) _speech.stop();
                    _isListening = false;
                    Navigator.pop(context);
                  },
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () async {
                    if (_isListening) _speech.stop();
                    _isListening = false;
                    final newDescription = controller.text.trim();
                    await (widget.firestore ?? FirebaseFirestore.instance)
                        .collection('chat_rooms')
                        .doc(widget.roomId)
                        .update({'description': newDescription});
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label:
              '${widget.roomName}. Oda açıklamasını görüntülemek için dokunun.',
          button: true,
          child: GestureDetector(
            onTap: _showRoomDescription,
            child: Text(widget.roomName),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, size: 30),
            onPressed: _showRoomDescription,
            tooltip: 'Oda Açıklaması',
          ),
          IconButton(
            icon: Icon(Icons.people, size: 30),
            onPressed: _showParticipantList,
            tooltip: 'Katılımcıları Gör',
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: _roomStream,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                if (data['creatorId'] == _auth.currentUser?.uid) {
                  return IconButton(
                    icon: Icon(
                      Icons.delete_forever,
                      color: Theme.of(context).colorScheme.error,
                      size: 30,
                    ),
                    onPressed: _confirmDeleteRoom,
                    tooltip: 'Odayı Sil',
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Voice Chat Controls
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.onPrimary,
            child: Column(
              children: [
                if (!_isJoined)
                  ElevatedButton.icon(
                    onPressed: _isJoining ? null : _joinVoiceChannel,
                    icon: _isJoining
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Icon(Icons.volume_up, size: 30),
                    label: Text(
                      _isJoining ? 'Katılınıyor...' : 'Sesli Kanala Katıl',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          // Ayarlar Butonu (Flex: 1)
                          Expanded(
                            flex: 1,
                            child: Tooltip(
                              message: "Mikrofon ayarları",
                              child: ElevatedButton(
                                onPressed: _showMicrophoneSettingsModal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[800],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: const CircleBorder(),
                                ),
                                child: const ExcludeSemantics(
                                  child: Icon(Icons.settings, size: 28),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Sustur/Konuş Butonu (Flex: 3)
                          Expanded(
                            flex: 3,
                            child: Tooltip(
                              message: "Mikrofonu Sustur/Aç",
                              child: Semantics(
                                onTapHint: "Mikrofonu açar veya kapatır",
                                label: (!_isMuted) ? "Mikrofon açık, susturmak için dokunun" : "Mikrofon kapalı, konuşmak için dokunun",
                                button: true,
                                child: GestureDetector(
                                  onTapDown: _isPTTMode
                                      ? (_) => _setMicrophoneEnabled(true)
                                      : null,
                                  onTapUp: _isPTTMode
                                      ? (_) => _setMicrophoneEnabled(false)
                                      : null,
                                  onTapCancel: _isPTTMode
                                      ? () => _setMicrophoneEnabled(false)
                                      : null,
                                  onTap: !_isPTTMode
                                      ? () {
                                          _setMicrophoneEnabled(_isMuted);
                                        }
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (!_isMuted) ? Colors.amber : Colors.grey[700],
                                      borderRadius: BorderRadius.circular(
                                        30,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ExcludeSemantics(
                                          child: Icon(
                                            (!_isMuted) ? Icons.mic : Icons.mic_off,
                                            size: 30,
                                            color: (!_isMuted) ? Colors.black : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          (!_isMuted) ? 'Sustur' : 'Konuş',
                                          style: TextStyle(
                                            color: (!_isMuted) ? Colors.black : Colors.white,
                                            fontSize: AppFonts.size(18),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Ayrıl Butonu (Flex: 2)
                          Expanded(
                            flex: 2,
                            child: Tooltip(
                              message: "Odadan Ayrıl",
                              child: ElevatedButton.icon(
                                onPressed: _leaveVoiceChannel,
                                icon: const ExcludeSemantics(child: Icon(Icons.call_end, size: 28)),
                                label: const Text('Ayrıl'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Media Streaming Panel (TeamTalk Style)
                      if (_selectedMediaFileName != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Medya Yayını',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: AppFonts.size(16),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Dosya: $_selectedMediaFileName',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: AppFonts.size(14),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _isMediaPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                      color: Colors.amber,
                                      size: 36,
                                    ),
                                    onPressed: _isMediaPlaying ? _pauseMediaFile : _playMediaFile,
                                    tooltip: _isMediaPlaying ? "Yayını Duraklat" : "Yayını Başlat",
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 36),
                                    onPressed: _stopMediaFile,
                                    tooltip: "Yayını Durdur",
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _mediaProgress,
                                      min: 0.0,
                                      max: 1.0,
                                      activeColor: Colors.amber,
                                      onChanged: (val) {}, // Mock progress for now
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.volume_down, size: 20, color: Colors.grey),
                                  Expanded(
                                    child: Slider(
                                      value: _mediaVolume,
                                      min: 0.0,
                                      max: 1.0,
                                      activeColor: Colors.amber,
                                      semanticFormatterCallback: (double value) => 'Medya Sesi: Yüzde ${(value * 100).round()}',
                                      onChanged: (val) {
                                        setState(() {
                                          _mediaVolume = val;
                                        });
                                      },
                                    ),
                                  ),
                                  const Icon(Icons.volume_up, size: 20, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ExpansionTile(
                        title: Text(
                          'Sesli Kanal Kullanıcıları (${(_room?.remoteParticipants.length ?? 0) + (_room?.localParticipant != null ? 1 : 0)})',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        collapsedBackgroundColor: Colors.grey[800],
                        backgroundColor: Colors.grey[900],
                        children: [
                          if (_room?.localParticipant != null)
                            Semantics(
                              container: true,
                              label: '${_room!.localParticipant!.identity.isNotEmpty ? _room!.localParticipant!.identity : 'Kullanıcı'} (Sen), ${_room!.localParticipant!.isSpeaking ? 'Konuşuyor' : 'Konuşmuyor'}, Mikrofon ${_room!.localParticipant!.isMicrophoneEnabled() ? 'Açık' : 'Kapalı'}',
                              child: ExcludeSemantics(
                                child: ListTile(
                                  leading: Icon(
                                    _room!.localParticipant!.isSpeaking
                                        ? Icons.volume_up
                                        : Icons.person,
                                    color: _room!.localParticipant!.isSpeaking
                                        ? Colors.green
                                        : Theme.of(context).colorScheme.secondary,
                                  ),
                                  title: Text(
                                    '${_room!.localParticipant!.identity.isNotEmpty ? _room!.localParticipant!.identity : 'Kullanıcı'} (Sen)',
                                    style: TextStyle(
                                      color: _room!.localParticipant!.isSpeaking
                                          ? Colors.green
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  trailing:
                                      _room!.localParticipant!.isMicrophoneEnabled()
                                      ? const Icon(Icons.mic, color: Colors.yellow)
                                      : const Icon(
                                          Icons.mic_off,
                                          color: Colors.red,
                                        ),
                                ),
                              ),
                            ),
                          ...(_room?.remoteParticipants.values.map((
                                participant,
                              ) {
                                final volume =
                                    _participantVolumes[participant.identity] ??
                                    1.35;
                                return Column(
                                  children: [
                                    Semantics(
                                      container: true,
                                      label: '${participant.identity.isNotEmpty ? participant.identity : 'Kullanıcı'}, ${participant.isSpeaking ? 'Konuşuyor' : 'Konuşmuyor'}, Mikrofon ${participant.isMicrophoneEnabled() ? 'Açık' : 'Kapalı'}',
                                      child: ExcludeSemantics(
                                        child: ListTile(
                                          leading: Icon(
                                            participant.isSpeaking
                                                ? Icons.volume_up
                                                : Icons.person,
                                            color: participant.isSpeaking
                                                ? Colors.green
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.secondary,
                                          ),
                                          title: Text(
                                            participant.identity.isNotEmpty
                                                ? participant.identity
                                                : 'Kullanıcı',
                                            style: TextStyle(
                                              color: participant.isSpeaking
                                                  ? Colors.green
                                                  : Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // TeamTalk tarzı dikey ses seviyesi çubukları
                                              if (participant.isSpeaking)
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: List.generate(5, (barIndex) {
                                                    // Calculate simulated volume based on time (for animation effect)
                                                    // Real volume simulation using random or time since it's hard to get real audio level quickly here without a stream
                                                    final timeBased = (DateTime.now().millisecondsSinceEpoch ~/ 100) % 5;
                                                    final isFilled = barIndex <= timeBased;
                                                    Color barColor = Colors.green;
                                                    if (barIndex == 3) barColor = Colors.orange;
                                                    if (barIndex == 4) barColor = Colors.red;
                                                    return Container(
                                                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                                      width: 4,
                                                      height: 6.0 + (barIndex * 3.0),
                                                      decoration: BoxDecoration(
                                                        color: isFilled ? barColor : Colors.grey[700],
                                                        borderRadius: BorderRadius.circular(1),
                                                      ),
                                                    );
                                                  }),
                                                )
                                              else
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: List.generate(5, (barIndex) {
                                                    return Container(
                                                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                                      width: 4,
                                                      height: 6.0 + (barIndex * 3.0),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[700],
                                                        borderRadius: BorderRadius.circular(1),
                                                      ),
                                                    );
                                                  }),
                                                ),
                                              const SizedBox(width: 8),
                                              participant.isMicrophoneEnabled()
                                              ? const Icon(
                                                  Icons.mic,
                                                  color: Colors.yellow,
                                                )
                                              : const Icon(
                                                  Icons.mic_off,
                                                  color: Colors.red,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.volume_down,
                                            size: 20,
                                          ),
                                          Expanded(
                                            child: Slider(
                                              value: volume,
                                              min: 0.0,
                                              max: 2.0,
                                              activeColor: Colors.amber,
                                              semanticFormatterCallback:
                                                  (double value) =>
                                                      'Yüzde ${(value * 100).round()}',
                                              onChanged: (val) {
                                                setState(() {
                                                  _participantVolumes[participant
                                                          .identity] =
                                                      val;
                                                });
                                                if (participant
                                                    .audioTrackPublications
                                                    .isNotEmpty) {
                                                  try {
                                                    (participant
                                                                .audioTrackPublications
                                                                .first
                                                                .track
                                                            as dynamic)
                                                        ?.setVolume(val);
                                                  } catch (e) {
                                                    debugPrint(
                                                      'Volume error: $e',
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          ),
                                          const Icon(Icons.volume_up, size: 20),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList() ??
                              []),
                        ],
                      ),
                    ],
                  ),
                // Status message for screen readers
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: Colors.transparent,
                    fontSize: AppFonts.size(1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Bir hata oluştu.'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(strokeWidth: 6),
                  );
                }

                // ⚡ Bolt: Dynamically filter messages client-side that expire *while*
                // the user is viewing the screen, without triggering new server reads.
                final now = Timestamp.now();
                final messages = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final expiresAt = data['expires_at'] as Timestamp?;
                  return expiresAt != null && expiresAt.compareTo(now) > 0;
                }).toList();

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Henüz mesaj bulunmuyor.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                        messages[index].data() as Map<String, dynamic>;
                    final type = messageData['type'] ?? 'text';
                    final text = messageData['text'] ?? '';
                    final audioUrl = messageData['audioUrl'] as String?;
                    final duration = messageData['duration'] as int?;
                    final senderName =
                        messageData['senderName'] ?? 'Bilinmeyen';
                    final isMe =
                        messageData['senderId'] == _auth.currentUser?.uid;
                    final timestamp = messageData['timestamp'] as Timestamp?;
                    final timeString = timestamp != null
                        ? "${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}"
                        : "";

                    final label = type == 'text'
                        ? 'Gönderen: $senderName, Mesaj: $text, Saat: $timeString'
                        : 'Gönderen: $senderName, Sesli Mesaj ($duration saniye), Saat: $timeString';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 16.0,
                      ),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Semantics(
                                container: true,
                                label: label,
                                customSemanticsActions: isMe
                                    ? {
                                        CustomSemanticsAction(
                                          label: 'Mesajı Sil',
                                        ): () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: Theme.of(
                                                context,
                                              ).scaffoldBackgroundColor,
                                              title: Text(
                                                'Mesajı Sil',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                              ),
                                              content: Text(
                                                'Bu mesajı silmek istediğinize emin misiniz?',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('İptal'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _deleteMessage(
                                                      messages[index].id,
                                                      audioUrl,
                                                    );
                                                  },
                                                  child: const Text('Sil'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      }
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            senderName,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                              fontSize: AppFonts.size(16),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          if (type == 'audio')
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    _currentlyPlayingMessageId ==
                                                            messages[index].id
                                                        ? Icons.stop
                                                        : Icons.play_arrow,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                                    size: 30,
                                                  ),
                                                  onPressed: () async {
                                                    if (_currentlyPlayingMessageId ==
                                                        messages[index].id) {
                                                      await _audioPlayer.stop();
                                                      setState(() {
                                                        _currentlyPlayingMessageId =
                                                            null;
                                                      });
                                                    } else {
                                                      if (audioUrl != null) {
                                                        setState(() {
                                                          _currentlyPlayingMessageId =
                                                              messages[index]
                                                                  .id;
                                                        });
                                                        await _audioPlayer.play(
                                                          UrlSource(audioUrl),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                                Text(
                                                  '$duration sn',
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                                    fontSize: AppFonts.size(18),
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            Text(
                                              text,
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onPrimary,
                                                fontSize: AppFonts.size(20),
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isMe)
                                            ExcludeSemantics(
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.redAccent,
                                                  size: 24,
                                                ),
                                                tooltip: 'Mesajı sil',
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      backgroundColor: Theme.of(
                                                        context,
                                                      ).scaffoldBackgroundColor,
                                                      title: Text(
                                                        'Mesajı Sil',
                                                        style: TextStyle(
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                        ),
                                                      ),
                                                      content: Text(
                                                        'Bu mesajı silmek istediğinize emin misiniz?',
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                              ),
                                                          child: const Text(
                                                            'İptal',
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                            _deleteMessage(
                                                              messages[index]
                                                                  .id,
                                                              audioUrl,
                                                            );
                                                          },
                                                          child: const Text(
                                                            'Sil',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          Text(
                                            timeString,
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: AppFonts.size(14),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Theme.of(context).colorScheme.onPrimary,
            child: SafeArea(
              child: _isRecording ?
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: Theme.of(context).colorScheme.primary,
                        size: 36,
                      ),
                      onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          _isPaused
                              ? 'Duraklatıldı: $_recordDuration sn'
                              : 'Kayıt Yapılıyor: $_recordDuration sn',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: AppFonts.size(20),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.stop,
                        color: Theme.of(context).colorScheme.error,
                        size: 36,
                      ),
                      onPressed: _stopRecording,
                      tooltip: 'Kaydı Durdur ve Gönder',
                    ),
                  ],
                )
              : Row(
                children: [
                  // Medya Seç İkonu (En sol, dairesel sarı arka plan, müzik notası)
                  Tooltip(
                    message: "Medya dosyası seçip odadakilere çalın",
                    child: Semantics(
                      label: "Medya dosyası seçip odadakilere çalın",
                      button: true,
                      child: ElevatedButton(
                        onPressed: _pickMediaFile,
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(12),
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          minimumSize: Size.zero,
                        ),
                        child: const ExcludeSemantics(child: Icon(Icons.music_note)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Mesaj Giriş Alanı (Orta)
                  Expanded(
                    child: Tooltip(
                      message: "Mesaj gönderin...",
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Mesaj...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[800],
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Colors.amber, width: 2),
                          ),
                        ),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppFonts.size(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Kayıt Başlat İkonu (Dairesel, mavi arka plan, mikrofon)
                  Tooltip(
                    message: "Kayıt başlatmak için basılı tutun",
                    child: Semantics(
                      label: "Kayıt başlatmak için basılı tutun",
                      button: true,
                      child: GestureDetector(
                        onLongPress: _startRecording,
                        onLongPressUp: _stopRecording,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const ExcludeSemantics(
                            child: Icon(Icons.mic, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Mesaj Gönder İkonu (En sağ, dairesel, sarı arka plan, ok)
                  Tooltip(
                    message: "Mesaj gönder",
                    child: Semantics(
                      label: "Mesaj gönder",
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => _sendMessage(),
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(12),
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          minimumSize: Size.zero,
                        ),
                        child: const ExcludeSemantics(child: Icon(Icons.send)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
