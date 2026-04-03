import 'package:flutter/material.dart';
import 'dart:ui' show TextDirection;
import 'package:flutter/semantics.dart';
import 'package:blind_social/theme/app_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import 'post_comments_screen.dart';
import 'meydan_profile_screen.dart';

class SquareScreen extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  const SquareScreen({super.key, this.auth, this.firestore});

  @override
  State<SquareScreen> createState() => _SquareScreenState();
}

class ExpandablePostText extends StatefulWidget {
  final String text;

  const ExpandablePostText({super.key, required this.text});

  @override
  State<ExpandablePostText> createState() => _ExpandablePostTextState();
}

class _ExpandablePostTextState extends State<ExpandablePostText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(
          text: widget.text,
          style: TextStyle(
            color: Colors.white,
            fontSize: AppFonts.size(16),
            height: 1.5,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 3,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout(maxWidth: constraints.maxWidth);

        if (textPainter.didExceedMaxLines) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppFonts.size(16),
                  height: 1.5,
                ),
                maxLines: _isExpanded ? null : 3,
                overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    _isExpanded ? '...daha az göster' : '...devamını okuyun',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: AppFonts.size(14),
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          return Text(
            widget.text,
            style: TextStyle(
              color: Colors.white,
              fontSize: AppFonts.size(16),
              height: 1.5,
            ),
          );
        }
      },
    );
  }
}

class _SquareScreenState extends State<SquareScreen> {
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  final TextEditingController _postController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isPosting = false;
  int _limit = 20;
  late Stream<QuerySnapshot> _postsStream;
  DateTime? _lastRefreshTime;

  int _userRole = 2;

  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Şu anda BS Meydan sayfasındasınız"),
            duration: const Duration(seconds: 2),
          ),
        );
        SemanticsService.announce("Şu anda BS Meydan sayfasındasınız", TextDirection.ltr);
      }
    });
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

  Future<void> _handleRefresh() async {
    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!).inSeconds < 15) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen yenilemek için biraz bekleyin.'),
          ),
        );
      }
      return;
    }

    _lastRefreshTime = now;
    if (mounted) {
      setState(() {
        _limit = 20;
        _updateStream();
      });
    }
  }

  @override
  void dispose() {
    _postController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (_isPosting) return;

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

    // Fetch numericId and username of the reporter
    final reporterDoc = await _firestore.collection('users').doc(uid).get();
    final reporterData = reporterDoc.data();
    final reporterNumericId = reporterData?['numericId'];
    final reporterUsername = reporterData?['username'] ?? 'İsimsiz';

    // Send report to reported_posts for admin
    await _firestore.collection('reported_posts').add({
      'postId': postId,
      'reportedByUserId': uid,
      'reportedByNumericId': reporterNumericId,
      'reportedByUsername': reporterUsername,
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

  void _showNewPostDialog() {
    String currentText = _postController.text;
    showDialog(
      context: context,
      builder: (context) {
        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              _speech.stop();
              _isListening = false;
            }
          },
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                backgroundColor: Colors.black,
                title: const Text(
                  'Yeni Gönderi',
                  style: TextStyle(color: Colors.yellow),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
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
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.red : Colors.yellow,
                            size: 32,
                          ),
                          onPressed: () async {
                            if (!_isListening) {
                              bool available = await _speech.initialize(
                                onStatus: (val) {
                                  if (val == 'done' || val == 'notListening') {
                                    if (mounted) {
                                      setStateDialog(
                                        () => _isListening = false,
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesli yazma durduruldu')));
                                      SemanticsService.announce('Sesli yazma durduruldu', TextDirection.ltr);
                                    }
                                  }
                                },
                                onError: (val) {
                                  if (mounted) {
                                    setStateDialog(() => _isListening = false);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesli yazma durduruldu')));
                                    SemanticsService.announce('Sesli yazma durduruldu', TextDirection.ltr);
                                  }
                                },
                              );
                              if (available) {
                                setStateDialog(() => _isListening = true);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesli yazma başlatıldı')));
                                  SemanticsService.announce('Sesli yazma başlatıldı', TextDirection.ltr);
                                }
                                currentText = _postController.text;
                                _speech.listen(
                                  onResult: (val) {
                                    setStateDialog(() {
                                      if (val.recognizedWords.isNotEmpty) {
                                        _postController.text =
                                            '$currentText ${val.recognizedWords}'
                                                .trimLeft();
                                      }
                                    });
                                  },
                                  localeId: 'tr_TR',
                                );
                              }
                            } else {
                              setStateDialog(() => _isListening = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesli yazma durduruldu')));
                                SemanticsService.announce('Sesli yazma durduruldu', TextDirection.ltr);
                              }
                              _speech.stop();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      _speech.stop();
                      _isListening = false;
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'İptal',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _speech.stop();
                      _isListening = false;
                      Navigator.pop(context);
                      _submitPost();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                    ),
                    child: const Text(
                      'Paylaş',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPostsList(List<DocumentSnapshot> docs, String? currentUserUid) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Colors.yellow,
      backgroundColor: Colors.black,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: docs.length,
        padding: const EdgeInsets.only(bottom: 80),
        itemBuilder: (context, index) {
          final doc = docs[index];
          final data = doc.data() as Map<String, dynamic>;

          final content = data['content'] ?? '';
          final authorId = data['authorId'];
          final authorUsername = data['authorUsername'] ?? 'İsimsiz';
          final likes = data['likes'] as List<dynamic>? ?? [];
          final reportedBy = data['reportedBy'] as List<dynamic>? ?? [];

          final isLiked =
              currentUserUid != null && likes.contains(currentUserUid);
          final likeCount = likes.length;

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('meydan_posts')
                .doc(doc.id)
                .collection('comments')
                .snapshots(),
            builder: (context, commentSnapshot) {
              final commentCount = commentSnapshot.data?.docs.length ?? 0;
              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PostCommentsScreen(postId: doc.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Semantics(
                      label:
                          'Gönderen: $authorUsername. İçerik: $content. ${likeCount > 0 ? '$likeCount kişi beğendi.' : ''} ${commentCount > 0 ? '$commentCount kişi yorum yaptı.' : ''}',
                      container: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MeydanProfileScreen(userId: authorId),
                                    ),
                                  );
                                },
                                child: Text(
                                  '@$authorUsername',
                                  style: TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: AppFonts.size(16),
                                  ),
                                ),
                              ),
                              if (data['createdAt'] != null)
                                Text(
                                  _formatTimestamp(
                                    data['createdAt'] as Timestamp,
                                  ),
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: AppFonts.size(14),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ExpandablePostText(text: content),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: likeCount > 0
                                        ? 'Gönderiyi beğen. Bu gönderiyi $likeCount kişi beğendi.'
                                        : 'Gönderiyi beğen',
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
                                  ExcludeSemantics(
                                    child: Text(
                                      '$likeCount',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: AppFonts.size(16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  if (currentUserUid != null) ...[
                                    Semantics(
                                      label: commentCount > 0
                                          ? '$commentCount yorum. Yorumlara git.'
                                          : 'Yorumlar',
                                      button: true,
                                      child: IconButton(
                                        icon: const ExcludeSemantics(
                                          child: Icon(
                                            Icons.comment,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  PostCommentsScreen(
                                                    postId: doc.id,
                                                  ),
                                            ),
                                          );
                                        },
                                        tooltip: commentCount > 0
                                            ? '$commentCount yorum. Yorumlara git.'
                                            : 'Yorumlar',
                                      ),
                                    ),
                                  ],
                                  if (currentUserUid == authorId ||
                                      _userRole == 0 ||
                                      _userRole == 1) ...[
                                    if (currentUserUid == authorId)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () =>
                                            _editPost(doc.id, content),
                                        tooltip: 'Düzenle',
                                      ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _deletePost(doc.id),
                                      tooltip: 'Sil',
                                    ),
                                  ],
                                  if (currentUserUid != null &&
                                      currentUserUid != authorId) ...[
                                    IconButton(
                                      icon: const Icon(
                                        Icons.report,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () =>
                                          _reportPost(doc.id, reportedBy),
                                      tooltip: 'Şikayet Et',
                                    ),
                                  ],
                                ],
                              ),
                            ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('BS Meydan'),
        actions: [
          if (currentUserUid != null)
            Semantics(
              label: 'BS Meydan profilim',
              button: true,
              child: IconButton(
                icon: const ExcludeSemantics(child: Icon(Icons.person)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MeydanProfileScreen(userId: currentUserUid),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewPostDialog,
        backgroundColor: Colors.yellow,
        icon: const Icon(Icons.edit, color: Colors.black),
        label: const Text(
          'Yeni Gönderi Oluştur',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Column(
        children: [
          if (_isPosting) const LinearProgressIndicator(color: Colors.yellow),
          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
              future: currentUserUid != null
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUserUid)
                        .get()
                  : Future.value(null),
              builder: (context, userSnapshot) {
                List<dynamic> followingList = [];
                if (userSnapshot.hasData &&
                    userSnapshot.data != null &&
                    userSnapshot.data!.exists) {
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  followingList = userData['following'] as List<dynamic>? ?? [];
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _postsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Bir hata oluştu.',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'Henüz gönderi yok.',
                          style: TextStyle(color: Colors.white, fontSize: AppFonts.size(18)),
                        ),
                      );
                    }

                    // Feed Mixing Algorithm
                    List<DocumentSnapshot> followedPosts = [];
                    List<DocumentSnapshot> otherPosts = [];

                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final authorId = data['authorId'];
                      if (followingList.contains(authorId)) {
                        followedPosts.add(doc);
                      } else {
                        otherPosts.add(doc);
                      }
                    }

                    List<DocumentSnapshot> mixedDocs = [];
                    int fIndex = 0;
                    int oIndex = 0;

                    while (fIndex < followedPosts.length ||
                        oIndex < otherPosts.length) {
                      if (fIndex < followedPosts.length) {
                        mixedDocs.add(followedPosts[fIndex]);
                        fIndex++;
                      }
                      if (oIndex < otherPosts.length) {
                        mixedDocs.add(otherPosts[oIndex]);
                        oIndex++;
                      }
                    }

                    return _buildPostsList(mixedDocs, currentUserUid);
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
