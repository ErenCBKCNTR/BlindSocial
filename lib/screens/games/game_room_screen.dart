import 'package:flutter/material.dart';
import 'trivia_game_screen.dart';
import 'story_game_screen.dart';

class GameRoomScreen extends StatelessWidget {
  const GameRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Oyun Odası')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            color: Colors.grey[900],
            child: ListTile(
              leading: Icon(
                Icons.quiz,
                color: Theme.of(context).colorScheme.primary,
                size: 40,
              ),
              title: Text(
                'Bilgi Yarışması',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Kim Milyarder Olmak İster tarzında süreli bilgi yarışması',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.pushNamed(context, '/trivia');
              },
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surface,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.secondary,
                width: 2,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              leading: Icon(
                Icons.book,
                color: Theme.of(context).colorScheme.primary,
                size: 40,
              ),
              title: Text(
                'İnteraktif Hikaye',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Kendi seçimlerinle ilerle',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 16,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StoryGameScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
