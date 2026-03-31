import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'radio_theater_player_screen.dart';
import '../services/audio_favorites_manager.dart';
import '../services/audio_progress_manager.dart';

class RadioTheaterScreen extends StatefulWidget {
  const RadioTheaterScreen({super.key});

  @override
  State<RadioTheaterScreen> createState() => _RadioTheaterScreenState();
}

class _RadioTheaterScreenState extends State<RadioTheaterScreen> {
  int _currentIndex = 0;
  List<String> _favorites = [];
  Map<String, Duration> _cachedProgress = {};
  bool _isLoadingProgress = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await AudioFavoritesManager.getFavorites();
    setState(() {
      _favorites = favs;
    });
  }

  Future<void> _toggleFavorite(String url) async {
    await AudioFavoritesManager.toggleFavorite(url);
    await _loadFavorites();
  }

  Future<void> _loadAllProgress(List<QueryDocumentSnapshot> docs) async {
    // Only fetch progress if we haven't loaded it or if we specifically request a refresh.
    // If we're on the Devam Edilen tab, we want to know progress for everything.
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final url = data['url'] ?? '';
      if (!_cachedProgress.containsKey(url)) {
        final progress = await AudioProgressManager.getProgress(url);
        _cachedProgress[url] = progress;
      }
    }
    if (mounted && _isLoadingProgress) {
      setState(() {
        _isLoadingProgress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Radyo Tiyatrosu')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8.0,
              alignment: WrapAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Tümü'),
                  selected: _currentIndex == 0,
                  onSelected: (selected) {
                    if (selected) setState(() => _currentIndex = 0);
                  },
                ),
                ChoiceChip(
                  label: const Text('Devam Edilen'),
                  selected: _currentIndex == 1,
                  onSelected: (selected) {
                    if (selected) setState(() => _currentIndex = 1);
                  },
                ),
                ChoiceChip(
                  label: const Text('Favorilerim'),
                  selected: _currentIndex == 2,
                  onSelected: (selected) {
                    if (selected) setState(() => _currentIndex = 2);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('radio_theaters')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                // Preload progress for active docs
                if (_currentIndex == 1 && _isLoadingProgress) {
                  _loadAllProgress(docs);
                  return const Center(child: CircularProgressIndicator());
                }

                // Tab Filtering
                if (_currentIndex == 1) { // Devam Edilen
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final url = data['url'] ?? '';
                    final progress = _cachedProgress[url] ?? Duration.zero;
                    return progress.inSeconds > 0;
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(child: Text('Devam ettiğiniz eser bulunamadı.'));
                  }
                } else if (_currentIndex == 2) { // Favorilerim
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _favorites.contains(data['url'] ?? '');
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(child: Text('Tiyatro bulunamadı.'));
                }

                return _buildListView(docs);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<DocumentSnapshot> docs) {
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final title = data['title'] ?? 'Bilinmeyen Tiyatro';
        final url = data['url'] ?? '';
        final isFav = _favorites.contains(url);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.radio),
            title: Text(title),
            trailing: IconButton(
              icon: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.red : null,
              ),
              onPressed: () => _toggleFavorite(url),
              tooltip: 'Favorilere Ekle/Çıkar',
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RadioTheaterPlayerScreen(
                    url: url,
                    title: title,
                  ),
                ),
              );
              // Force progress refresh for this specific item when returning
              final newProgress = await AudioProgressManager.getProgress(url);
              _cachedProgress[url] = newProgress;

              if (mounted) {
                setState(() {});
              }
            },
          ),
        );
      },
    );
  }
}
