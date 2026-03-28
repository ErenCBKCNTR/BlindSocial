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
  int? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? FirebaseAuth.instance;
    _firestore = widget.firestore ?? FirebaseFirestore.instance;

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        setState(() {
          _limit += 20;
        });
      }
    });
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _currentUserRole = doc.data()?['role_id'] as int?;
        });
      }
    }
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


  Future<void> _deletePost(String postId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Sil', style: TextStyle(color: Colors.red)),
        content: const Text('Bu gönderiyi silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    ) ?? false;

    if (confirm) {
      await _firestore.collection('meydan_posts').doc(postId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderi silindi.')));
      }
    }
  }

  void _editPost(String postId, String currentContent) {
    TextEditingController editController = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Gönderiyi Düzenle', style: TextStyle(color: Colors.yellow)),
          content: TextField(
            controller: editController,
            maxLines: 4,
            maxLength: 280,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyan)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.yellow)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                final newText = editController.text.trim();
                if (newText.isNotEmpty) {
                  await _firestore.collection('meydan_posts').doc(postId).update({'content': newText});
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderi güncellendi.')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
              child: const Text('Kaydet', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      }
    );
  }

  void _showCommentsDialog(String postId) {
    TextEditingController commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Yorumlar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.grey),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('meydan_posts').doc(postId).collection('comments').orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      var docs = snapshot.data!.docs;
                      if (docs.isEmpty) return const Center(child: Text('İlk yorumu siz yapın!', style: TextStyle(color: Colors.grey)));

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var comment = docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text('@${comment['authorUsername']}', style: const TextStyle(color: Colors.cyan, fontSize: 14)),
                            subtitle: Text(comment['content'], style: const TextStyle(color: Colors.white)),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Yorum ekle...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.cyan),
                      onPressed: () async {
                        final text = commentController.text.trim();
                        final user = _auth.currentUser;
                        if (text.isNotEmpty && user != null) {
                          final userDoc = await _firestore.collection('users').doc(user.uid).get();
                          final username = userDoc.data()?['username'] ?? 'İsimsiz';

                          await _firestore.collection('meydan_posts').doc(postId).collection('comments').add({
                            'content': text,
                            'authorId': user.uid,
                            'authorUsername': username,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          commentController.clear();
                        }
                      },
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
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

    // Add uid to reportedBy array
    await _firestore.collection('meydan_posts').doc(postId).update({
      'reportedBy': FieldValue.arrayUnion([uid])
    });

    // Send a copy to admin reported_posts
    await _firestore.collection('reported_posts').add({
      'postId': postId,
      'reporterId': uid,
      'reportedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gönderi şikayet edildi. İncelenecektir.')),
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s önce';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}d önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}sa önce';
    } else if (diff.inDays < 30) {
      return '${diff.inDays}g önce';
    } else {
      final months = diff.inDays ~/ 30;
      return '${months}a önce';
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
        title: const Text('BS Meydan'),
      ),
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
              stream: _firestore
                  .collection('meydan_posts')
                  .orderBy('createdAt', descending: true)
                  .limit(_limit)
                  .snapshots(),
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
                    child: const Text('Henüz gönderi yok.', style: TextStyle(color: Colors.white, fontSize: 18))
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
                    final timestamp = data['createdAt'] as Timestamp?;
                    final timeString = _formatTimestamp(timestamp);

                    // Basic client-side hide if current user reported it
                    if (currentUserUid != null && reportedBy.contains(currentUserUid)) {
                      return const SizedBox.shrink();
                    }

                    final isLiked = currentUserUid != null && likes.contains(currentUserUid);
                    final likeCount = likes.length;

                    final authorId = data['authorId'];
                    final canEditOrDelete = (currentUserUid != null && authorId == currentUserUid) || (_currentUserRole == 0 || _currentUserRole == 1);

                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                                  style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Row(
                                  children: [
                                    if (timeString.isNotEmpty)
                                      Text(
                                        timeString,
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    if (canEditOrDelete) ...[
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.cyan, size: 20),
                                        onPressed: () => _editPost(doc.id, content),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                        onPressed: () => _deletePost(doc.id),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ]
                                  ],
                                ),
                              ],
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
                                    IconButton(
                                      icon: Icon(
                                        isLiked ? Icons.favorite : Icons.favorite_border,
                                        color: isLiked ? Colors.red : Colors.grey,
                                      ),
                                      onPressed: () => _toggleLike(doc.id, likes),
                                    ),
                                    Text(
                                      '$likeCount',
                                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: const Icon(Icons.comment, color: Colors.cyan),
                                      onPressed: () => _showCommentsDialog(doc.id),
                                    ),
                                  ],
                                ),
                                IconButton(
                                    icon: const Icon(Icons.report, color: Colors.grey),
                                    onPressed: () => _reportPost(doc.id, reportedBy),
                                    tooltip: 'Şikayet Et',
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
