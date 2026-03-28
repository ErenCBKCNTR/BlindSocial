import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'post_comments_screen.dart';

class SquareScreen extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const SquareScreen({super.key, this.auth, this.firestore});

  @override
  State<SquareScreen> createState() => _SquareScreenState();
}

class _SquareScreenState extends State<SquareScreen> {
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  final TextEditingController _postController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isPosting = false;
  int _limit = 20;
  late Stream<QuerySnapshot> _postsStream;

  int _userRole = 2;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? FirebaseAuth.instance;
    _firestore = widget.firestore ?? FirebaseFirestore.instance;

    _checkUserRole();

    // ⚡ Bolt: Cache Firestore stream to prevent unnecessary queries on unrelated
    // widget rebuilds. Re-assign the stream only when _limit changes.
    _updateStream();

    _speech = stt.SpeechToText();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (mounted) {
          setState(() {
            _limit += 20;
            _updateStream();
          });
        }
      }
    });
  }

  Future<void> _checkUserRole() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _userRole = doc.data()?['role_id'] ?? 2;
          });
        }
      }
    }
  }

  void _updateStream() {
    _postsStream = _firestore
        .collection('meydan_posts')
        .orderBy('createdAt', descending: true)
        .limit(_limit)
        .snapshots();
  }

  @override
  void dispose() {
    _postController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isPosting = true;
    });

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final username = userData?['username'] ?? 'İsimsiz';

      await _firestore.collection('meydan_posts').add({
        'content': text,
        'authorId': user.uid,
        'authorUsername': username,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'reportedBy': [],
      });

      _postController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gönderi paylaşıldı.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gönderi paylaşılamadı.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  Future<void> _toggleLike(String postId, List<dynamic> currentLikes) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final isLiked = currentLikes.contains(uid);

    final docRef = _firestore.collection('meydan_posts').doc(postId);
    if (isLiked) {
      await docRef.update({
        'likes': FieldValue.arrayRemove([uid]),
      });
    } else {
      await docRef.update({
        'likes': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> _reportPost(String postId, List<dynamic> currentReports) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    if (currentReports.contains(uid)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu gönderiyi zaten şikayet ettiniz.')),
        );
      }
      return;
    }

    await _firestore.collection('meydan_posts').doc(postId).update({
      'reportedBy': FieldValue.arrayUnion([uid]),
    });

    // Send report to reported_posts for admin
    await _firestore.collection('reported_posts').add({
      'postId': postId,
      'reportedByUserId': uid,
      'reportedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gönderi şikayet edildi. İncelenecektir.'),
        ),
      );
    }
  }

  Future<void> _deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('meydan_posts').doc(postId).delete();
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s önce';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}d önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h önce';
    } else if (diff.inDays < 30) {
      return '${diff.inDays}g önce';
    } else if (diff.inDays < 365) {
      return '${diff.inDays ~/ 30}a önce';
    } else {
      return '${diff.inDays ~/ 365}y önce';
    }
  }

  Future<void> _editPost(String postId, String oldContent) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final editController = TextEditingController(text: oldContent);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text(
            'Gönderiyi Düzenle',
            style: TextStyle(color: Colors.yellow),
          ),
          content: TextField(
            controller: editController,
            maxLines: 4,
            maxLength: 280,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.cyan),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.yellow),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = editController.text.trim();
                if (text.isEmpty) return;
                await _firestore.collection('meydan_posts').doc(postId).update({
                  'content': text,
                  'editedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
              ),
              child: const Text('Güncelle'),
            ),
          ],
        );
      },
    );
  }

  void _listenForDictation() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) => setState(() => _isListening = false),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _postController.text = val.recognizedWords;
            });
          },
          localeId: 'tr_TR',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _showNewPostDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.black,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Yeni Gönderi',
                    style: TextStyle(color: Colors.yellow),
                  ),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : Colors.cyan,
                    ),
                    tooltip: 'Konuşarak Yaz',
                    onPressed: () async {
                      if (!_isListening) {
                        bool available = await _speech.initialize(
                          onStatus: (val) {
                            if (val == 'done' || val == 'notListening') {
                              if (mounted) setDialogState(() => _isListening = false);
                            }
                          },
                          onError: (val) {
                            if (mounted) setDialogState(() => _isListening = false);
                          },
                        );
                        if (available) {
                          setDialogState(() => _isListening = true);
                          _speech.listen(
                            onResult: (val) {
                              setDialogState(() {
                                _postController.text = val.recognizedWords;
                              });
                            },
                            localeId: 'tr_TR',
                          );
                        }
                      } else {
                        setDialogState(() => _isListening = false);
                        _speech.stop();
                      }
                    },
                  )
                ],
              ),
              content: TextField(
                controller: _postController,
                maxLines: 4,
                maxLength: 280,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Neler düşünüyorsunuz?',
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyan),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.yellow),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _speech.stop();
                    _isListening = false;
                    Navigator.pop(context);
                  },
                  child: const Text('İptal', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    _speech.stop();
                    _isListening = false;
                    Navigator.pop(context);
                    _submitPost();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
                  child: const Text(
                    'Paylaş',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('BS Meydan')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewPostDialog,
        backgroundColor: Colors.yellow,
        child: const Icon(Icons.edit, color: Colors.black),
      ),
      body: Column(
        children: [
          if (_isPosting) const LinearProgressIndicator(color: Colors.yellow),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _postsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Bir hata oluştu.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: const Text(
                      'Henüz gönderi yok.',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: docs.length,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final content = data['content'] ?? '';
                    final authorId = data['authorId'];
                    final authorUsername = data['authorUsername'] ?? 'İsimsiz';
                    final likes = data['likes'] as List<dynamic>? ?? [];
                    final reportedBy =
                        data['reportedBy'] as List<dynamic>? ?? [];

                    // Basic client-side hide if current user reported it
                    if (currentUserUid != null &&
                        reportedBy.contains(currentUserUid)) {
                      return const SizedBox.shrink();
                    }

                    final isLiked =
                        currentUserUid != null &&
                        likes.contains(currentUserUid);
                    final likeCount = likes.length;

                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '@$authorUsername',
                                  style: const TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (data['createdAt'] != null)
                                  Text(
                                    _formatTimestamp(data['createdAt'] as Timestamp),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isLiked
                                            ? Colors.red
                                            : Colors.grey,
                                      ),
                                      onPressed: () =>
                                          _toggleLike(doc.id, likes),
                                    ),
                                    Text(
                                      '$likeCount',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (currentUserUid != null) ...[
                                      IconButton(
                                        icon: const Icon(Icons.comment, color: Colors.grey),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PostCommentsScreen(postId: doc.id),
                                            ),
                                          );
                                        },
                                        tooltip: 'Yorumlar',
                                      ),
                                    ],
                                    if (currentUserUid == authorId || _userRole == 0 || _userRole == 1) ...[
                                      if (currentUserUid == authorId)
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _editPost(doc.id, content),
                                          tooltip: 'Düzenle',
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deletePost(doc.id),
                                        tooltip: 'Sil',
                                      ),
                                    ],
                                    if (currentUserUid != null && currentUserUid != authorId) ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.report,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () =>
                                            _reportPost(doc.id, reportedBy),
                                        tooltip: 'Şikayet Et',
                                      ),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
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
}
