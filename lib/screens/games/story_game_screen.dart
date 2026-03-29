import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  Map<String, dynamic> _stories = {
    'start': {
      'text': 'Karanlık bir ormanda uyandın. Gözlerini açtığında etrafında hiçbir şey göremiyorsun. Sadece uzaktan gelen bir su sesi duyuyorsun. Ne yaparsın?',
      'choices': [
        {'text': 'Su sesine doğru yürü', 'next': 'river'},
        {'text': 'Olduğun yerde bekle ve dinle', 'next': 'wait'},
      ]
    },
    'river': {
      'text': 'Su sesini takip ederek geniş bir nehrin kenarına ulaştın. Nehrin karşısında eski bir kulübe görünüyor. Ayrıca nehrin kenarında küçük bir kayık var.',
      'choices': [
        {'text': 'Kayığa binip karşıya geç', 'next': 'cabin'},
        {'text': 'Nehir boyunca yürümeye devam et', 'next': 'walk_river'},
      ]
    },
    'wait': {
      'text': 'Bir süre olduğun yerde bekledin. Ay ışığı yavaş yavaş etrafı aydınlatmaya başladı. Yakınlarda bir patika belirdi.',
      'choices': [
        {'text': 'Patikayı takip et', 'next': 'path'},
        {'text': 'Geri dönüp uyumaya çalış', 'next': 'sleep'},
      ]
    },
    'cabin': {
      'text': 'Kayıkla zor da olsa karşıya geçtin. Kulübenin kapısı aralık. İçeriden loş bir ışık sızıyor.',
      'choices': [
        {'text': 'Kapıyı çal', 'next': 'knock'},
        {'text': 'Sessizce içeri gir', 'next': 'sneak'},
      ]
    },
    'walk_river': {
      'text': 'Nehir boyunca saatlerce yürüdün ve sonunda bir köye ulaştın. Güvendesin!\n\nSON.',
      'choices': [
        {'text': 'Tekrar Oyna', 'next': 'start'}
      ]
    },
    'path': {
      'text': 'Patika seni büyük bir mağaraya götürdü. Mağaranın içinde parlayan taşlar var.',
      'choices': [
        {'text': 'Taşları incele', 'next': 'stones'},
        {'text': 'Mağaradan çık', 'next': 'leave_cave'},
      ]
    },
    'sleep': {
      'text': 'Gözlerini kapattın ve uykuya daldın. Sabah olduğunda kurtarma ekipleri seni buldu. Güvendesin!\n\nSON.',
      'choices': [
        {'text': 'Tekrar Oyna', 'next': 'start'}
      ]
    },
    'knock': {
      'text': 'Kapıyı çaldın. Yaşlı bir adam kapıyı açtı ve seni içeri davet etti. Sana sıcak çorba ikram etti. Güvendesin!\n\nSON.',
      'choices': [
        {'text': 'Tekrar Oyna', 'next': 'start'}
      ]
    },
    'sneak': {
      'text': 'Sessizce içeri girdin ama içerideki köpek seni fark edip havlamaya başladı! Yaşlı adam korkuyla uyanıp seni dışarı attı. Ormanda tekrar kayboldun.\n\nSON.',
      'choices': [
        {'text': 'Tekrar Oyna', 'next': 'start'}
      ]
    },
    'stones': {
      'text': 'Taşlar büyülüydü! Onlara dokunur dokunmaz kendini evinde buldun. Büyülü bir macera yaşadın.\n\nSON.',
      'choices': [
        {'text': 'Tekrar Oyna', 'next': 'start'}
      ]
    },
    'leave_cave': {
      'text': 'Mağaradan çıktın ve ormanda kayboldun. Belki de taşları incelemeliydin.\n\nSON.',
      'choices': [
        {'text': 'Tekrar Oyna', 'next': 'start'}
      ]
    }
  };

  String _currentNode = 'start';
  String _gameInstanceId = 'default_story';

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final user = _auth.currentUser;
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
          if (data['currentNode'] != null) {
            setState(() {
              _currentNode = data['currentNode'];
            });
          }
        }
      } catch (e) {
        // Fallback to start
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _makeChoice(String nextNode) async {
    setState(() {
      _savingProgress = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('games')
            .doc('interactive_story')
            .collection('progress')
            .doc(user.uid)
            .set({
          'currentNode': nextNode,
          'lastPlayed': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // Handle error or ignore to just keep playing locally
    }

    setState(() {
      _currentNode = nextNode;
      _savingProgress = false;
    });
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
                child: Container(
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
              ),
            ),
            const SizedBox(height: 20),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
          ],
        ),
      ),
    );
  }
}
