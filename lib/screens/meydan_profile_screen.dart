import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'post_comments_screen.dart';

class MeydanProfileScreen extends StatefulWidget {
  final String userId;

  const MeydanProfileScreen({super.key, required this.userId});

  @override
  State<MeydanProfileScreen> createState() => _MeydanProfileScreenState();
}

class _MeydanProfileScreenState extends State<MeydanProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _postCount = 0;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.userId).get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _userData = doc.data() as Map<String, dynamic>;
          });
        }
      }

      // Count posts
      final postsQuery = await _firestore
          .collection('meydan_posts')
          .where('authorId', isEqualTo: widget.userId)
          .get();

      if (mounted) {
        setState(() {
          _postCount = postsQuery.docs.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_userData == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: Text('Kullanıcı bulunamadı.', style: TextStyle(color: Colors.white))),
      );
    }

    final username = _userData?['username'] ?? 'İsimsiz';
    final followers = _userData?['followers'] as List<dynamic>? ?? [];
    final following = _userData?['following'] as List<dynamic>? ?? [];
    final bio = _userData?['bio'] ?? '';

    final currentUserUid = _auth.currentUser?.uid;
    final isCurrentUser = currentUserUid == widget.userId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text('@$username')),
      body: Column(
        children: [
          _buildProfileHeader(username, followers.length, following.length, bio, isCurrentUser),
          const Divider(color: Colors.grey),
          Expanded(child: _buildUserPosts()),
        ],
      ),
    );
  }

  Future<void> _toggleFollow(bool isFollowing) async {
    final currentUserUid = _auth.currentUser?.uid;
    if (currentUserUid == null) return;

    final batch = _firestore.batch();

    final currentUserRef = _firestore.collection('users').doc(currentUserUid);
    final targetUserRef = _firestore.collection('users').doc(widget.userId);

    if (isFollowing) {
      batch.update(currentUserRef, {
        'following': FieldValue.arrayRemove([widget.userId])
      });
      batch.update(targetUserRef, {
        'followers': FieldValue.arrayRemove([currentUserUid])
      });
    } else {
      batch.update(currentUserRef, {
        'following': FieldValue.arrayUnion([widget.userId])
      });
      batch.update(targetUserRef, {
        'followers': FieldValue.arrayUnion([currentUserUid])
      });
    }

    try {
      await batch.commit();
      _loadUserProfile(); // refresh data
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem başarısız oldu.')),
        );
      }
    }
  }

  void _showEditBioDialog(String currentBio) {
    _bioController.text = currentBio;
    String currentText = currentBio;

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
                  'Biyografi Düzenle',
                  style: TextStyle(color: Colors.yellow),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 150,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Kendinizden bahsedin...',
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
                                      setStateDialog(() => _isListening = false);
                                    }
                                  }
                                },
                                onError: (val) {
                                  if (mounted) {
                                    setStateDialog(() => _isListening = false);
                                  }
                                },
                              );
                              if (available) {
                                setStateDialog(() => _isListening = true);
                                currentText = _bioController.text;
                                _speech.listen(
                                  onResult: (val) {
                                    setStateDialog(() {
                                      if (val.recognizedWords.isNotEmpty) {
                                        _bioController.text =
                                            '$currentText ${val.recognizedWords}'.trimLeft();
                                      }
                                    });
                                  },
                                  localeId: 'tr_TR',
                                );
                              }
                            } else {
                              setStateDialog(() => _isListening = false);
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
                    child: const Text('İptal', style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      _speech.stop();
                      _isListening = false;

                      final newBio = _bioController.text.trim();
                      await _firestore.collection('users').doc(widget.userId).update({
                        'bio': newBio,
                      });

                      if (mounted) {
                        Navigator.pop(context);
                        _loadUserProfile(); // refresh data
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Biyografi güncellendi.')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
                    child: const Text(
                      'Kaydet',
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

  Widget _buildProfileHeader(String username, int followersCount, int followingCount, String bio, bool isCurrentUser) {
    final currentUserUid = _auth.currentUser?.uid;
    final followersList = _userData?['followers'] as List<dynamic>? ?? [];
    final isFollowing = currentUserUid != null && followersList.contains(currentUserUid);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                label: 'Profil resmi',
                child: const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn('Gönderi', _postCount),
                    _buildStatColumn('Takipçi', followersCount),
                    _buildStatColumn('Takip', followingCount),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (bio.isNotEmpty)
            Text(
              bio,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: isCurrentUser
                ? ElevatedButton(
                    onPressed: () => _showEditBioDialog(bio),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Colors.grey),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Profilimi Düzenle'),
                  )
                : ElevatedButton(
                    onPressed: () => _toggleFollow(isFollowing),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.transparent : Colors.blue,
                      side: isFollowing ? const BorderSide(color: Colors.grey) : BorderSide.none,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isFollowing ? 'Takipten Çık' : 'Takip Et'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
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

  Future<void> _deletePost(String postId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Emin misiniz?', style: TextStyle(color: Colors.red)),
        content: const Text('Bu gönderiyi silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('meydan_posts').doc(postId).delete();
      if (mounted) {
        _loadUserProfile(); // Update post count
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gönderi silindi.')),
        );
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

  Widget _buildUserPosts() {
    final currentUserUid = _auth.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('meydan_posts')
          .where('authorId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Gönderiler yüklenirken bir hata oluştu.', style: TextStyle(color: Colors.white)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Henüz gönderi yok.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.only(bottom: 20),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final content = data['content'] ?? '';
            final authorUsername = data['authorUsername'] ?? 'İsimsiz';
            final likes = data['likes'] as List<dynamic>? ?? [];
            final isLiked = currentUserUid != null && likes.contains(currentUserUid);
            final likeCount = likes.length;

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('meydan_posts').doc(doc.id).collection('comments').snapshots(),
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
                          builder: (context) => PostCommentsScreen(postId: doc.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Semantics(
                        label: 'Gönderen: $authorUsername. İçerik: $content. ${likeCount > 0 ? '$likeCount kişi beğendi.' : ''} ${commentCount > 0 ? '$commentCount kişi yorum yaptı.' : ''}',
                        container: true,
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
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Semantics(
                                      label: likeCount > 0
                                          ? 'Gönderiyi beğen. Bu gönderiyi $likeCount kişi beğendi.'
                                          : 'Gönderiyi beğen',
                                      button: true,
                                      child: IconButton(
                                        tooltip: 'Gönderiyi beğen',
                                        icon: Icon(
                                          isLiked ? Icons.favorite : Icons.favorite_border,
                                          color: isLiked ? Colors.red : Colors.grey,
                                        ),
                                        onPressed: () => _toggleLike(doc.id, likes),
                                      ),
                                    ),
                                    ExcludeSemantics(
                                      child: Text(
                                        '$likeCount',
                                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (currentUserUid != null) ...[
                                      Semantics(
                                        label: commentCount > 0 ? '$commentCount yorum. Yorumlara git.' : 'Yorumlar',
                                        button: true,
                                        child: IconButton(
                                          icon: const ExcludeSemantics(child: Icon(Icons.comment, color: Colors.grey)),
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
                                      ),
                                    ],
                                    if (currentUserUid == widget.userId) ...[
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
        );
      },
    );
  }
}
