import 'package:flutter/material.dart';
import 'trivia_game_screen.dart';

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
        ],
      ),
    );
  }
}
