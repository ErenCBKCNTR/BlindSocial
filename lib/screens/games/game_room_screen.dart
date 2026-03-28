import 'package:flutter/material.dart';
import 'trivia_game_screen.dart';

class GameRoomScreen extends StatelessWidget {
  const GameRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: 'Oyun Odası Başlığı',
          child: Text('Oyun Odası'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Semantics(
            label: 'Bilgi Yarışması Oyunu',
            button: true,
            hint: 'Bilgi yarışması oynamak için çift dokunun',
            child: Card(
              color: Colors.grey[900],
              child: ListTile(
                leading: Icon(Icons.quiz, color: Theme.of(context).colorScheme.primary, size: 40),
                title: Text(
                  'Bilgi Yarışması',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Kim Milyarder Olmak İster tarzında süreli bilgi yarışması',
                  style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 16),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TriviaGameScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
