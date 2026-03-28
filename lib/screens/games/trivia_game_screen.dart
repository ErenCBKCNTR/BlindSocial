import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TriviaGameScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;

  const TriviaGameScreen({super.key, this.firestore});

  @override
  State<TriviaGameScreen> createState() => _TriviaGameScreenState();
}

class _TriviaGameScreenState extends State<TriviaGameScreen> {
  late final FirebaseFirestore _firestore;

  @override
  void initState() {
    super.initState();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
  }

  bool _isSettingsSelected = false;
  String _selectedCategory = 'Genel Kültür';
  String _selectedDifficulty = 'kolay';

  final List<String> _categories = ['Genel Kültür', 'Tarih', 'Coğrafya', 'Bilim', 'Spor'];
  final List<String> _difficulties = ['kolay', 'orta', 'zor'];

  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isAnswered = false;
  int _timeLeft = 30;
  Timer? _timer;
  String _selectedAnswer = '';
  List<String> _shuffledOptions = [];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchQuestions() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final snapshot = await _firestore
          .collection('Games')
          .doc('Trivia')
          .collection('Questions')
          .doc(_selectedCategory)
          .collection('sorular')
          .where('difficulty', isEqualTo: _selectedDifficulty)
          .limit(10)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docs = snapshot.docs;
        docs.shuffle(); // Randomize
        setState(() {
          _questions = docs.map((e) => e.data()).toList();
          _isLoading = false;
        });
        _prepareCurrentOptions();
        _startTimer();
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _prepareCurrentOptions() {
    if (_currentQuestionIndex < _questions.length) {
      final q = _questions[_currentQuestionIndex];
      List<String> options = List<String>.from(q['options']);
      options.shuffle();
      setState(() {
        _shuffledOptions = options;
        _isAnswered = false;
        _selectedAnswer = '';
        _timeLeft = 30;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    if (_isAnswered) return;
    setState(() {
      _isAnswered = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _nextQuestion();
    });
  }

  void _checkAnswer(String answer) {
    if (_isAnswered) return;

    _timer?.cancel();
    setState(() {
      _isAnswered = true;
      _selectedAnswer = answer;
      if (answer == _questions[_currentQuestionIndex]['correctAnswer']) {
        _score += 10;
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _prepareCurrentOptions();
      _startTimer();
    } else {
      _showGameOverDialog();
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Oyun Bitti',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        content: Text(
          'Skorunuz: $_score',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 24,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isSettingsSelected = false;
                _currentQuestionIndex = 0;
                _score = 0;
                _questions.clear();
              });
            },
            child: const Text('Tekrar Oyna'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsScreen() {
    return Center(
      child: Card(
        color: Colors.grey[900],
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Trivia Ayarları',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: Colors.grey[800],
                decoration: InputDecoration(
                  labelText: 'Kategori Seç',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.secondary),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                items: _categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedCategory = val!);
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedDifficulty,
                dropdownColor: Colors.grey[800],
                decoration: InputDecoration(
                  labelText: 'Zorluk Seç',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.secondary),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 18),
                items: _difficulties.map((diff) {
                  return DropdownMenuItem(value: diff, child: Text(diff.toUpperCase()));
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedDifficulty = val!);
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isSettingsSelected = true;
                  });
                  _fetchQuestions();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Oyuna Başla'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSettingsSelected) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trivia Oyunu')),
        body: _buildSettingsScreen(),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trivia Oyunu')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trivia Oyunu')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Sorular yüklenemedi veya bu kategoride soru yok.',
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isSettingsSelected = false;
                  });
                },
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Soru ${_currentQuestionIndex + 1} / ${_questions.length}'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Skor: $_score',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategory,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _timeLeft <= 5 ? Colors.red : Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '$_timeLeft',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _timeLeft <= 5
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              question['question'] ?? '',
              style: TextStyle(
                fontSize: 24,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Expanded(
              child: ListView.builder(
                itemCount: _shuffledOptions.length,
                itemBuilder: (context, index) {
                  final option = _shuffledOptions[index];
                  bool isSelected = _selectedAnswer == option;
                  bool isCorrect = option == question['correctAnswer'];

                  Color btnColor = Colors.grey[800]!;
                  if (_isAnswered) {
                    if (isCorrect) {
                      btnColor = Colors.green;
                    } else if (isSelected) {
                      btnColor = Colors.red;
                    }
                  } else if (isSelected) {
                    btnColor = Theme.of(context).colorScheme.primary;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        padding: const EdgeInsets.all(20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _isAnswered ? null : () => _checkAnswer(option),
                      child: Text(
                        option,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
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
