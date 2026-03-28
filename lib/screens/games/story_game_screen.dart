import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoryGameScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  const StoryGameScreen({super.key, this.firestore});

  @override
  State<StoryGameScreen> createState() => _StoryGameScreenState();
}

class _StoryGameScreenState extends State<StoryGameScreen> {
  late final FirebaseFirestore _firestore;
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, dynamic>? _currentStoryNode;
  String _currentStoryId = 'story_1'; // Hardcoded start or fetched from a list

  // Let's seed a simple local story if DB fails
  final Map<String, dynamic> _localStory = {
    'story_1': {
      'text': 'Karanlık bir ormanda uyandın. İki yol ayrımındasın.',
      'choices': [
        {'text': 'Sola git', 'nextId': 'story_2'},
        {'text': 'Sağa git', 'nextId': 'story_3'},
      ]
    },
    'story_2': {
      'text': 'Sola gittin ve bir nehirle karşılaştın. Nehri geçmek için bir köprü var ama çok eski görünüyor.',
      'choices': [
        {'text': 'Köprüden geç', 'nextId': 'story_4'},
        {'text': 'Geri dön', 'nextId': 'story_1'},
      ]
    },
    'story_3': {
      'text': 'Sağa gittin ve bir kurt sürüsüyle karşılaştın. Kurtlar sana doğru yaklaşıyor.',
      'choices': [
        {'text': 'Savaş', 'nextId': 'story_5'},
        {'text': 'Kaç', 'nextId': 'story_1'},
      ]
    },
    'story_4': {
      'text': 'Köprüden geçtin ve gizli bir hazine buldun! Oyunu kazandın.',
      'choices': [
        {'text': 'Baştan başla', 'nextId': 'story_1'},
      ]
    },
    'story_5': {
      'text': 'Kurtlarla savaşırken yaralandın. Oyunu kaybettin.',
      'choices': [
        {'text': 'Baştan başla', 'nextId': 'story_1'},
      ]
    }
  };

  @override
  void initState() {
    super.initState();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _fetchStoryNode(_currentStoryId);
  }

  Future<void> _fetchStoryNode(String nodeId) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final doc = await _firestore.collection('Games').doc('Story').collection('Nodes').doc(nodeId).get();
      if (doc.exists) {
        setState(() {
          _currentStoryNode = doc.data();
          _isLoading = false;
        });
      } else {
        // Fallback to local
        setState(() {
          _currentStoryNode = _localStory[nodeId];
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback
      setState(() {
        _currentStoryNode = _localStory[nodeId];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('İnteraktif Hikaye')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentStoryNode == null || _hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('İnteraktif Hikaye')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Hikaye yüklenemedi.', style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      );
    }

    final text = _currentStoryNode!['text'] ?? '';
    final choices = _currentStoryNode!['choices'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('İnteraktif Hikaye')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: choices.length,
                itemBuilder: (context, index) {
                  final choice = choices[index] as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: () => _fetchStoryNode(choice['nextId']),
                      child: Text(
                        choice['text'] ?? '',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
