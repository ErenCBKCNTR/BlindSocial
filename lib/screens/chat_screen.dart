import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:permission_handler/permission_handler.dart';

const String liveKitUrl = 'wss://bs-app-l1mgfyed.livekit.cloud';
const String liveKitApiKey = 'APINTM3AUHp6ftW';
const String liveKitApiSecret = 'lQTO4G5gD9rGBFx94LoAl2bh0yaMBAaR6VgHN45ZeoO';

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

  Room? _room;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isJoining = false;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _addParticipant();
  }

  Future<void> _addParticipant() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final roomRef =
        FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;

      int current = snapshot.data()?['currentParticipants'] ?? 0;
      transaction.update(roomRef, {'currentParticipants': current + 1});

      final participantRef = roomRef.collection('participants').doc(user.uid);
      transaction.set(participantRef, {
        'uid': user.uid,
        'email': user.email,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _removeParticipant() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final roomRef =
        FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;

      int current = snapshot.data()?['currentParticipants'] ?? 0;
      transaction
          .update(roomRef, {'currentParticipants': (current - 1).clamp(0, 999)});

      final participantRef = roomRef.collection('participants').doc(user.uid);
      transaction.delete(participantRef);
    });
  }

  String _generateToken() {
    final user = _auth.currentUser;
    final identity = user?.email ?? user?.uid ?? 'anonymous_${DateTime.now().millisecondsSinceEpoch}';

    final jwt = JWT(
      {
        'exp': (DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch / 1000).round(),
        'iss': liveKitApiKey,
        'sub': identity,
        'video': {
          'roomJoin': true,
          'room': widget.roomId,
        },
      },
      issuer: liveKitApiKey,
    );

    return jwt.sign(
      SecretKey(liveKitApiSecret),
      algorithm: JWTAlgorithm.HS256,
    );
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
      if (_room != null) {
        await _room!.disconnect();
      }

      final token = _generateToken();
      _room = Room();

      await _room!.connect(liveKitUrl, token);

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
          SnackBar(content: Text('${widget.roomName} odasına başarıyla bağlanıldı')),
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
  void dispose() {
    _removeParticipant();
    _messageController.dispose();
    _scrollController.dispose();
    _room?.disconnect();
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

  void _showParticipantList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(widget.roomId)
            .collection('participants')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final participants = snapshot.data!.docs;

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Katılımcılar', style: TextStyle(color: Colors.yellow, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final p = participants[index].data() as Map<String, dynamic>;
                    final email = p['email'] ?? 'Anonim';
                    return Semantics(
                      label: 'Katılımcı: $email',
                      child: ListTile(
                        leading: const Icon(Icons.person, color: Colors.cyan),
                        title: Text(email, style: const TextStyle(color: Colors.white, fontSize: 18)),
                      ),
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
        backgroundColor: Colors.black,
        title: const Text('Odayı Sil', style: TextStyle(color: Colors.red)),
        content: const Text('Bu odayı kalıcı olarak silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).delete();
              if (context.mounted) {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // leave chat screen
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SİL'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: '${widget.roomName} odası sohbet ekranı',
          child: Text(widget.roomName),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people, size: 30),
            onPressed: _showParticipantList,
            tooltip: 'Katılımcıları Gör',
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chat_rooms').doc(widget.roomId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                if (data['creatorId'] == _auth.currentUser?.uid) {
                  return IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red, size: 30),
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
