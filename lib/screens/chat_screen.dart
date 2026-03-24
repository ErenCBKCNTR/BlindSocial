import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

const String appId = "F38268f6936e44f39b67c8efc7b8e162";

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ChatScreen({super.key, required this.roomId, required this.roomName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _scrollController = ScrollController();

  RtcEngine? _engine;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isJoining = false;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            setState(() {
              _isJoined = true;
              _isJoining = false;
              _statusMessage = "Sesli kanala bağlanıldı.";
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kanala başarıyla bağlanıldı')),
              );
            }
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            setState(() {
              _isJoined = false;
              _isJoining = false;
              _statusMessage = "Sesli kanaldan ayrılındı.";
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            setState(() {
              _statusMessage = "Odaya yeni birisi katıldı.";
            });
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('Agora error: $err - $msg');
            setState(() {
              _isJoining = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bağlantı kurulamadı, lütfen kanal ayarlarını kontrol edin'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('Agora initialization error: $e');
    }
  }

  Future<void> _joinVoiceChannel() async {
    if (_isJoining) return;

    final status = await Permission.microphone.request();

    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Semantics(
              label: 'Mikrofon izni verilmedi. Sesli sohbete katılmak için lütfen izin verin.',
              child: const Text('Mikrofon izni verilmedi. Sesli sohbete katılmak için lütfen izin verin.'),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      // Safety: leave previous channel if any
      await _engine?.leaveChannel();

      await _engine!.joinChannel(
        token: "",
        channelId: widget.roomId,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ),
      );
    } catch (e) {
      debugPrint('Error joining channel: $e');
      setState(() {
        _isJoining = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı hatası: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _leaveVoiceChannel() async {
    await _engine!.leaveChannel();
  }

  Future<void> _toggleMute() async {
    await _engine!.muteLocalAudioStream(!_isMuted);
    setState(() {
      _isMuted = !_isMuted;
      _statusMessage = _isMuted ? "Mikrofon kapatıldı" : "Mikrofon açıldı";
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'text': messageText,
      'senderId': user.uid,
      'senderEmail': user.email,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: '${widget.roomName} odası sohbet ekranı',
          child: Text(widget.roomName),
        ),
      ),
      body: Column(
        children: [
          // Voice Chat Controls
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.black,
            child: Column(
              children: [
                if (!_isJoined)
                  Semantics(
                    label: 'Sesli Kanala Katıl',
                    hint: 'Sesli sohbete katıl, odadaki diğer kullanıcılarla konuşmak için dokunun',
                    button: true,
                    enabled: !_isJoining,
                    child: ElevatedButton.icon(
                      onPressed: _isJoining ? null : _joinVoiceChannel,
                      icon: _isJoining
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.volume_up, size: 30),
                      label: Text(_isJoining ? 'Katılınıyor...' : 'Sesli Kanala Katıl'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 60),
                        backgroundColor: Colors.cyan,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: _isMuted ? 'Mikrofonu Aç' : 'Mikrofonu Sustur',
                          hint: _isMuted ? 'Sesinizi iletmek için dokunun' : 'Sesinizi kapatmak için dokunun',
                          button: true,
                          child: ElevatedButton.icon(
                            onPressed: _toggleMute,
                            icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, size: 30),
                            label: Text(_isMuted ? 'Sesi Aç' : 'Sustur'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isMuted ? Colors.red : Colors.yellow,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Semantics(
                          label: 'Sesli Kanaldan Ayrıl',
                          hint: 'Sesli sohbetten çıkmak için dokunun',
                          button: true,
                          child: ElevatedButton.icon(
                            onPressed: _leaveVoiceChannel,
                            icon: const Icon(Icons.call_end, size: 30),
                            label: const Text('Ayrıl'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                // Status message for screen readers
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(color: Colors.transparent, fontSize: 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(widget.roomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Semantics(
                      label: 'Mesajlar yüklenirken hata oluştu',
                      child: const Text('Bir hata oluştu.'),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 6),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Semantics(
                      label: 'Henüz mesaj yok',
                      child: Text(
                        'Henüz mesaj bulunmuyor.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
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
                    final text = messageData['text'] ?? '';
                    final senderEmail = messageData['senderEmail'] ?? 'Bilinmeyen';
                    final isMe = messageData['senderId'] == _auth.currentUser?.uid;
                    final timestamp = messageData['timestamp'] as Timestamp?;
                    final timeString = timestamp != null
                        ? "${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}"
                        : "";

                    return Semantics(
                      label: 'Gönderen: $senderEmail, Mesaj: $text, Saat: $timeString',
                      liveRegion: index == 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        child: Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.yellow : Colors.cyan,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      senderEmail,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      text,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeString,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 14,
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
            color: Colors.black,
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Mesajınızı buraya yazın',
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Mesaj...',
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  label: 'Mesajı Gönder butonu',
                  hint: 'Yazdığınız mesajı odaya göndermek için dokunun',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.yellow, size: 36),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
