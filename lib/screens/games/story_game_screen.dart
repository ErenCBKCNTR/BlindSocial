import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'story_data.dart';

class InteractiveStoryGameScreen extends StatefulWidget {
  const InteractiveStoryGameScreen({super.key});

  @override
  State<InteractiveStoryGameScreen> createState() => _InteractiveStoryGameScreenState();
}

class _InteractiveStoryGameScreenState extends State<InteractiveStoryGameScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _savingProgress = false;
  late Map<String, dynamic> _stories;

  String _currentNode = 'start';
  String _gameInstanceId = 'default';

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  void _pickRandomStory() {
    final random = Random();
    final storyDef = StoryData.stories[random.nextInt(StoryData.stories.length)];
    _gameInstanceId = storyDef['id'];
    _stories = storyDef['nodes'];
  }

  Future<void> _loadProgress() async {
    final user = _auth.currentUser;
    bool loadedSavedGame = false;

    if (user != null) {
      try {
        final doc = await _firestore
            .collection('games')
            .doc('interactive_story')
            .collection('progress')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['currentNode'] != null && data['gameInstanceId'] != null) {
            // Find the story definition matching the saved gameInstanceId
            final savedInstanceId = data['gameInstanceId'];
            final matchedStoryDef = StoryData.stories.cast<Map<String, dynamic>?>().firstWhere(
                  (story) => story?['id'] == savedInstanceId,
                  orElse: () => null,
                );

            if (matchedStoryDef != null) {
              _gameInstanceId = savedInstanceId;
              _stories = matchedStoryDef['nodes'];
              _currentNode = data['currentNode'];

              // If the user reached the end in their save, start them fresh
              if (_currentNode == 'start') {
                 loadedSavedGame = false;
              } else {
                 loadedSavedGame = true;
              }
            }
          }
        }
      } catch (e) {
        // Fallback to start
      }
    }

    if (!loadedSavedGame) {
      _pickRandomStory();
      _currentNode = 'start';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _makeChoice(String nextNode) async {
    setState(() {
      _savingProgress = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // If the game reaches the 'start' node (meaning "Tekrar Oyna" was pressed),
        // randomly pick a new story so the next session is different.
        String nextInstanceId = _gameInstanceId;
        if (nextNode == 'start') {
           _pickRandomStory();
           nextInstanceId = _gameInstanceId;
        }

        await _firestore
            .collection('games')
            .doc('interactive_story')
            .collection('progress')
            .doc(user.uid)
            .set({
          'currentNode': nextNode,
          'gameInstanceId': nextInstanceId,
          'lastPlayed': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // Handle error or ignore to just keep playing locally
    }

    if (mounted) {
      setState(() {
        _currentNode = nextNode;
        _savingProgress = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Etkileşimli Hikaye')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final node = _stories[_currentNode] ?? _stories['start'];

    return Scaffold(
      appBar: AppBar(title: const Text('Etkileşimli Hikaye')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_savingProgress)
              const LinearProgressIndicator(color: Colors.yellow),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                      ),
                      child: Text(
                        node['text'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...(node['choices'] as List<dynamic>).map((choice) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ElevatedButton(
                          onPressed: () => _makeChoice(choice['next']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.all(20),
                          ),
                          child: Text(
                            choice['text'],
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
