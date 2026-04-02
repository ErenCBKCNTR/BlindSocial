import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'radio_theater_player_screen.dart';
import '../services/audio_favorites_manager.dart';
import '../services/audio_progress_manager.dart';
import '../services/audio_cache_manager.dart';

class RadioTheaterScreen extends StatefulWidget {
  const RadioTheaterScreen({super.key});

  @override
  State<RadioTheaterScreen> createState() => _RadioTheaterScreenState();
}

class _RadioTheaterScreenState extends State<RadioTheaterScreen> {
  int _currentIndex = 0;
  List<String> _favorites = [];
  final Map<String, Duration> _cachedProgress = {};
  bool _isLoadingProgress = true;
  bool _hasInternet = true;
  List<Map<String, String>> _downloadedFiles = [];

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadFavorites();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        setState(() {
          _hasInternet = false;
          _currentIndex = 3; // Default to Downloads if offline
        });
        _loadDownloadedFiles();
      }
    } else {
      setState(() {
        _hasInternet = true;
      });
    }
  }

  Future<void> _loadDownloadedFiles() async {
    final files = await AudioCacheManager.getDownloadedFiles();
    if (mounted) {
      setState(() {
        _downloadedFiles = files;
      });
    }
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
                    if (selected && _hasInternet) setState(() => _currentIndex = 2);
                  },
                ),
                ChoiceChip(
                  label: const Text('İndirdiğim Kaynaklar'),
                  selected: _currentIndex == 3,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _currentIndex = 3);
                      _loadDownloadedFiles();
                    }
                  },
                ),
              ],
            ),
          ),
          if (!_hasInternet && _currentIndex != 3)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'İnternet bağlantınız yok. Yalnızca indirdiğiniz kaynakları dinleyebilirsiniz.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else if (_currentIndex == 3)
            Expanded(
              child: _downloadedFiles.isEmpty
                  ? const Center(child: Text('İndirdiğiniz herhangi bir kaynak bulunamadı.'))
                  : ListView.builder(
                      itemCount: _downloadedFiles.length,
                      itemBuilder: (context, index) {
                        final fileData = _downloadedFiles[index];
                        final title = fileData['title'] ?? 'Bilinmeyen Eser';
                        final localPath = fileData['localPath'] ?? '';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const Icon(Icons.offline_pin, color: Colors.green),
                            title: Text(title),
                            subtitle: const Text('Çevrimdışı Kaynak'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RadioTheaterPlayerScreen(
                                    url: localPath, // Use local path as unique ID for offline progress tracking
                                    title: title,
                                    localForcePath: localPath, // We need to add this to Player Screen
                                  ),
                                ),
                              ).then((_) => _loadDownloadedFiles()); // Refresh if deleted
                            },
                          ),
                        );
                      },
                    ),
            )
          else
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
