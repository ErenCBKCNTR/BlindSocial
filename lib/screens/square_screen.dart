import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? FirebaseAuth.instance;
    _firestore = widget.firestore ?? FirebaseFirestore.instance;

    // ⚡ Bolt: Cache Firestore stream to prevent unnecessary queries on unrelated
    // widget rebuilds. Re-assign the stream only when _limit changes.
    _updateStream();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (mounted) {
          setState(() {
            _limit += 20;
            _updateStream();
          });
        }
      }
    });
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

    setState(() { _isPosting = true; });

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gönderi paylaşıldı.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gönderi paylaşılamadı.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isPosting = false; });
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
        'likes': FieldValue.arrayRemove([uid])
      });
    } else {
      await docRef.update({
        'likes': FieldValue.arrayUnion([uid])
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
      'reportedBy': FieldValue.arrayUnion([uid])
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gönderi şikayet edildi. İncelenecektir.')),
      );
    }
  }

  void _showNewPostDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Yeni Gönderi', style: TextStyle(color: Colors.yellow)),
          content: TextField(
            controller: _postController,
            maxLines: 4,
            maxLength: 280,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Neler düşünüyorsunuz?',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyan)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.yellow)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitPost();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
              child: const Text('Paylaş', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserUid = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'BS Meydan Başlığı',
          child: const Text('BS Meydan'),
        ),
      ),
      floatingActionButton: Semantics(
        label: 'Yeni gönderi paylaş',
        button: true,
        child: FloatingActionButton(
          onPressed: _showNewPostDialog,
          backgroundColor: Colors.yellow,
          child: const Icon(Icons.edit, color: Colors.black),
        ),
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
                    child: Semantics(
                      label: 'Henüz gönderi yok',
                      child: const Text('Henüz gönderi yok.', style: TextStyle(color: Colors.white, fontSize: 18)),
                    )
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
                    final authorUsername = data['authorUsername'] ?? 'İsimsiz';
                    final likes = data['likes'] as List<dynamic>? ?? [];
                    final reportedBy = data['reportedBy'] as List<dynamic>? ?? [];

                    // Basic client-side hide if current user reported it
                    if (currentUserUid != null && reportedBy.contains(currentUserUid)) {
                      return const SizedBox.shrink();
                    }

                    final isLiked = currentUserUid != null && likes.contains(currentUserUid);
                    final likeCount = likes.length;

                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@$authorUsername',
                              style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              content,
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Semantics(
                                      label: isLiked ? 'Beğenmekten vazgeç' : 'Beğen',
                                      button: true,
                                      child: IconButton(
                                        icon: Icon(
                                          isLiked ? Icons.favorite : Icons.favorite_border,
                                          color: isLiked ? Colors.red : Colors.grey,
                                        ),
                                        onPressed: () => _toggleLike(doc.id, likes),
                                      ),
                                    ),
                                    Text(
                                      '$likeCount',
                                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                                    ),
                                  ],
                                ),
                                Semantics(
                                  label: 'Şikayet Et',
                                  button: true,
                                  child: IconButton(
                                    icon: const Icon(Icons.report, color: Colors.grey),
                                    onPressed: () => _reportPost(doc.id, reportedBy),
                                    tooltip: 'Şikayet Et',
                                  ),
                                ),
                              ],
                            )
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
