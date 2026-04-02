import 'package:flutter/semantics.dart';
import 'package:blind_social/theme/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class PostCommentsScreen extends StatefulWidget {
  final String postId;

  const PostCommentsScreen({super.key, required this.postId});

  @override
  _PostCommentsScreenState createState() => _PostCommentsScreenState();
}

class _PostCommentsScreenState extends State<PostCommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isPosting = false;
  late final Stream<QuerySnapshot> _commentsStream;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    // ⚡ Bolt: Cache Firestore stream to prevent redundant database reads
    // on every widget rebuild (e.g. when typing or using speech-to-text)
    _commentsStream = _firestore
        .collection('meydan_posts')
        .doc(widget.postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesli yazma durduruldu')));
              SemanticsService.announce('Sesli yazma durduruldu', TextDirection.ltr);
            }
          }
        },
        onError: (val) {
          setState(() => _isListening = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesli yazma durduruldu')));
            SemanticsService.announce('Sesli yazma durduruldu', TextDirection.ltr);
          }
        },
      );

      if (available) {
        setState(() => _isListening = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesli yazma başlatıldı')));
          SemanticsService.announce('Sesli yazma başlatıldı', TextDirection.ltr);
        }
        _speech.listen(
          onResult: (val) => setState(() {
            _commentController.text = val.recognizedWords;
          }),
          localeId: 'tr_TR',
        );
      } else {
        await Permission.microphone.request();
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesli yazma durduruldu')));
        SemanticsService.announce('Sesli yazma durduruldu', TextDirection.ltr);
      }
    }
  }

  Future<void> _submitComment() async {
    if (_isPosting) return;

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isPosting = true;
    });

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final username = userDoc.data()?['username'] ?? 'İsimsiz';

      await _firestore.collection('meydan_posts').doc(widget.postId).collection('comments').add({
        'content': text,
        'authorId': user.uid,
        'authorUsername': username,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteComment(String commentId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Emin misiniz?'),
          content: const Text('Yorumunuzu silmek istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteComment(commentId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gönderiye yaptığınız yorum silinmiştir.')),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    await _firestore
        .collection('meydan_posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} saniye önce';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dakika önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} gün önce';
    } else if (diff.inDays < 365) {
      return '${diff.inDays ~/ 30} ay önce';
    } else {
      return '${diff.inDays ~/ 365} yıl önce';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yorumlar'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _commentsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data!.docs;
                if (comments.isEmpty) {
                  return const Center(
                    child: Text('Henüz yorum yapılmamış.', style: TextStyle(color: Colors.white)),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final commentDoc = comments[index];
                    final data = commentDoc.data() as Map<String, dynamic>;
                    final authorId = data['authorId'];
                    final content = data['content'] ?? '';
                    final authorUsername = data['authorUsername'] ?? 'Bilinmiyor';

                    return Semantics(
                      customSemanticsActions: {
                        if (currentUserUid == authorId)
                          const CustomSemanticsAction(label: 'Sil'): () => _confirmDeleteComment(commentDoc.id),
                      },
                      child: Card(
                        color: Colors.grey[850],
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: ListTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('@$authorUsername', style: const TextStyle(color: Colors.yellow)),
                              if (data['createdAt'] != null)
                                Text(
                                  _formatTimestamp(data['createdAt'] as Timestamp),
                                  style: TextStyle(color: Colors.grey, fontSize: AppFonts.size(12)),
                                ),
                            ],
                          ),
                          subtitle: Text(content, style: const TextStyle(color: Colors.white)),
                          trailing: currentUserUid == authorId
                              ? ExcludeSemantics(
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _confirmDeleteComment(commentDoc.id),
                                    tooltip: 'Sil',
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Yorum ekle...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : Colors.yellow,
                    ),
                    onPressed: _listen,
                    tooltip: 'Dikte',
                  ),
                  TextButton(
                    onPressed: _submitComment,
                    child: Text(
                      'Gönder',
                      style: TextStyle(
                        color: Colors.cyan,
                        fontWeight: FontWeight.bold,
                        fontSize: AppFonts.size(16),
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
