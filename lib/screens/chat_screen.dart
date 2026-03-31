import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/semantics.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const String liveKitUrl = 'wss://bs-app-l1mgfyed.livekit.cloud';
const String liveKitApiKey = 'APINTM3AUHp6ftW';
const String liveKitApiSecret = 'lQTO4G5gD9rGBFx94LoAl2bh0yaMBAaR6VgHN45ZeoO';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final AudioRecorder? audioRecorder;
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final FirebaseStorage? storage;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.audioRecorder,
    this.auth,
    this.firestore,
    this.storage,
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

  @override
  void initState() {
    _speech = stt.SpeechToText();
    super.initState();
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
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if (mounted) {
          setState(() {
            _currentlyPlayingMessageId = null;
          });
        }
      }
    });
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          setState(() => _isListening = false);
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _messageController.text = val.recognizedWords;
          }),
          localeId: 'tr_TR',
        );
      } else {
        await Permission.microphone.request();
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
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

      transaction.update(roomRef, {'currentParticipants': FieldValue.increment(1)});

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
      await roomRef.update({
        'currentParticipants': FieldValue.increment(-1)
      });
      final participantRef = roomRef.collection('participants').doc(user.uid);
      await participantRef.delete();
    } catch (e) {
      debugPrint('Participant remove error: $e');
    }
  }

  String _generateToken() {
    final user = _auth.currentUser;
    final identity =
        _cachedDisplayName ??
        user?.uid ??
        'anonymous_${DateTime.now().millisecondsSinceEpoch}';

    final jwt = JWT({
      'exp':
          (DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch /
                  1000)
              .round(),
      'iss': liveKitApiKey,
      'sub': identity,
      'video': {'roomJoin': true, 'room': widget.roomId},
    }, issuer: liveKitApiKey);

    return jwt.sign(SecretKey(liveKitApiSecret), algorithm: JWTAlgorithm.HS256);
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

      final token = _generateToken();
      _room = Room();

      await _room!.connect(liveKitUrl, token);

      _room!.events.listen((event) {
        if (event is ParticipantConnectedEvent) {
          final participant = event.participant;
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${participant.identity} sesli kanala katıldı.'),
              ),
            );
            SystemSound.play(SystemSoundType.click);
          }
        } else if (event is ParticipantDisconnectedEvent) {
          final participant = event.participant;
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
        } else if (event is ActiveSpeakersChangedEvent) {
           if (mounted) {
             setState(() {});
           }
        } else if (event is TrackMutedEvent || event is TrackUnmutedEvent) {
           if (mounted) {
             setState(() {});
           }
        }
      });

      // Enable microphone immediately
      await _room!.localParticipant?.setMicrophoneEnabled(true);

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

  Future<void> _toggleMute() async {
    final newMuted = !_isMuted;
    await _room?.localParticipant?.setMicrophoneEnabled(!newMuted);
    setState(() {
      _isMuted = newMuted;
      _statusMessage = _isMuted ? "Mikrofon kapatıldı" : "Mikrofon açıldı";
    });
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
        final ref = widget.storage?.refFromURL(audioUrl) ??
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
    final messageText = _messageController.text.trim();
    if (type == 'text' && messageText.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showParticipantList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: (widget.firestore ?? FirebaseFirestore.instance)
            .collection('chat_rooms')
            .doc(widget.roomId)
            .collection('participants')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
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
                        fontSize: 24,
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
                        final isCreator = roomSnap.hasData &&
                            (roomSnap.data!.data() as Map<String, dynamic>?)?['creatorId'] ==
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
                              fontSize: 18,
                            ),
                          ),
                          trailing: (isCreator && !isMe)
                              ? IconButton(
                                  icon: Icon(Icons.mic_off, color: Theme.of(context).colorScheme.error),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Susturma özelliği eklenecektir.')),
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
        return StreamBuilder<DocumentSnapshot>(
          stream: _roomStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const AlertDialog(content: Text('Yükleniyor...'));
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final description = data['description'] ?? 'Bu oda için henüz bir açıklama eklenmemiş.';
            final isCreator = data['creatorId'] == _auth.currentUser?.uid;

            return AlertDialog(
              title: Text('${widget.roomName} Açıklaması'),
              content: Text(description),
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
    final TextEditingController controller = TextEditingController(text: currentDescription == 'Bu oda için henüz bir açıklama eklenmemiş.' ? '' : currentDescription);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Oda Açıklamasını Düzenle'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Oda açıklamasını buraya yazın...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () async {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: '${widget.roomName}. Oda açıklamasını görüntülemek için çift tıklayın.',
          button: true,
          child: GestureDetector(
            onDoubleTap: _showRoomDescription,
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
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _toggleMute,
                              icon: Icon(
                                _isMuted ? Icons.mic_off : Icons.mic,
                                size: 30,
                              ),
                              label: Text(_isMuted ? 'Sesi Aç' : 'Sustur'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isMuted
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _leaveVoiceChannel,
                              icon: Icon(Icons.call_end, size: 30),
                              label: Text('Ayrıl'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ExpansionTile(
                        title: Text(
                          'Sesli Kanal Kullanıcıları (${(_room?.remoteParticipants.length ?? 0) + (_room?.localParticipant != null ? 1 : 0)})',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                        collapsedBackgroundColor: Colors.grey[800],
                        backgroundColor: Colors.grey[900],
                        children: [
                          if (_room?.localParticipant != null)
                            ListTile(
                              leading: Icon(
                                _room!.localParticipant!.isSpeaking ? Icons.volume_up : Icons.person,
                                color: _room!.localParticipant!.isSpeaking ? Colors.green : Theme.of(context).colorScheme.secondary,
                              ),
                              title: Text(
                                '${_room!.localParticipant!.identity.isNotEmpty ? _room!.localParticipant!.identity : 'Kullanıcı'} (Sen)',
                                style: TextStyle(
                                  color: _room!.localParticipant!.isSpeaking ? Colors.green : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              trailing: _room!.localParticipant!.isMicrophoneEnabled()
                                  ? const Icon(Icons.mic, color: Colors.yellow)
                                  : const Icon(Icons.mic_off, color: Colors.red),
                            ),
                          ...(_room?.remoteParticipants.values.map((participant) {
                            return ListTile(
                              leading: Icon(
                                participant.isSpeaking ? Icons.volume_up : Icons.person,
                                color: participant.isSpeaking ? Colors.green : Theme.of(context).colorScheme.secondary,
                              ),
                              title: Text(
                                participant.identity.isNotEmpty ? participant.identity : 'Kullanıcı',
                                style: TextStyle(
                                  color: participant.isSpeaking ? Colors.green : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              trailing: participant.isMicrophoneEnabled()
                                  ? const Icon(Icons.mic, color: Colors.yellow)
                                  : const Icon(Icons.mic_off, color: Colors.red),
                            );
                          }).toList() ?? []),
                        ],
                      ),
                    ],
                  ),
                // Status message for screen readers
                Text(
                  _statusMessage,
                  style: TextStyle(color: Colors.transparent, fontSize: 1),
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

                    return GestureDetector(
                      onLongPress: isMe
                          ? () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                  title: Text('Mesajı Sil', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                  content: Text('Bu mesajı silmek istediğinize emin misiniz?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('İptal'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteMessage(messages[index].id, audioUrl);
                                      },
                                      child: const Text('Sil'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 16.0,
                        ),
                        child: Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.secondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      senderName,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                        fontSize: 16,
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
                                              _currentlyPlayingMessageId == messages[index].id
                                                  ? Icons.stop
                                                  : Icons.play_arrow,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                              size: 30,
                                            ),
                                            onPressed: () async {
                                              if (_currentlyPlayingMessageId == messages[index].id) {
                                                await _audioPlayer.stop();
                                                setState(() {
                                                  _currentlyPlayingMessageId = null;
                                                });
                                              } else {
                                                if (audioUrl != null) {
                                                  await _audioPlayer.stop();
                                                  setState(() {
                                                    _currentlyPlayingMessageId = messages[index].id;
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
                                              fontSize: 18,
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
                                          fontSize: 20,
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  timeString,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.onPrimary,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: _isRecording
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.secondary,
                      size: 36,
                    ),
                    onPressed: _isRecording ? _stopRecording : _startRecording,
                    tooltip: _isRecording ? 'Kaydı Durdur ve Gönder' : 'Sesli Mesaj Kaydet',
                  ),
                  if (_isRecording) ...[
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
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(hintText: 'Mesaj...'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : Theme.of(context).colorScheme.secondary,
                        size: 30,
                      ),
                      onPressed: _listen,
                      tooltip: 'Dikte',
                    ),
                    SizedBox(width: 6),
                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color: Theme.of(context).colorScheme.primary,
                        size: 36,
                      ),
                      onPressed: () => _sendMessage(),
                      tooltip: 'Mesajı Gönder',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
