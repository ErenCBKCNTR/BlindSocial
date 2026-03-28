import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TriviaGameScreen extends StatefulWidget {
  const TriviaGameScreen({super.key});

  @override
  State<TriviaGameScreen> createState() => _TriviaGameScreenState();
}

class _TriviaGameScreenState extends State<TriviaGameScreen> {
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isAnswered = false;
  int _timeLeft = 30;
  Timer? _timer;
  String _selectedAnswer = '';
  List<String> _shuffledOptions = [];

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchQuestions() async {
    try {
      final response = await http.get(Uri.parse('https://the-trivia-api.com/api/questions?limit=10'));
      if (response.statusCode == 200) {
        setState(() {
          _questions = json.decode(response.body);
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
    if (_questions.isNotEmpty && _currentQuestionIndex < _questions.length) {
      final currentQuestion = _questions[_currentQuestionIndex];
      List<String> options = List<String>.from(currentQuestion['incorrectAnswers']);
      options.add(currentQuestion['correctAnswer']);
      options.shuffle();
      setState(() {
        _shuffledOptions = options;
      });
    }
  }

  void _startTimer() {
    _timeLeft = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timer?.cancel();
          _handleAnswer('');
        }
      });
    });
  }

  void _handleAnswer(String answer) {
    if (_isAnswered) return;

    setState(() {
      _isAnswered = true;
      _selectedAnswer = answer;
      _timer?.cancel();

      if (answer == _questions[_currentQuestionIndex]['correctAnswer']) {
        _score += 10;
      }
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _isAnswered = false;
          _selectedAnswer = '';
        });
        _prepareCurrentOptions();
        _prepareCurrentOptions();
        _startTimer();
      } else {
        _showGameOverDialog();
      }
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Oyun Bitti', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        content: Text('Toplam Puanınız: $_score\nDoğru Cevap Sayısı: ${_score ~/ 10}/${_questions.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Çıkış', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
                _currentQuestionIndex = 0;
                _score = 0;
                _isAnswered = false;
              });
              _fetchQuestions();
            },
            child: Text('Tekrar Oyna', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 18)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bilgi Yarışması')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bilgi Yarışması')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Sorular yüklenirken bir hata oluştu.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                  });
                  _fetchQuestions();
                },
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    List<String> options = _shuffledOptions;

    return Scaffold(
      appBar: AppBar(
        title: Text('Soru ${_currentQuestionIndex + 1} / ${_questions.length}'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text('Puan: $_score', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _timeLeft <= 5 ? Colors.red.withValues(alpha: 0.2) : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer, color: _timeLeft <= 5 ? Colors.red : Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '$_timeLeft Saniye',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _timeLeft <= 5 ? Colors.red : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Card(
                color: Colors.grey[800],
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    currentQuestion['question'],
                    style: TextStyle(fontSize: 22, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  bool isCorrect = option == currentQuestion['correctAnswer'];
                  bool isSelected = option == _selectedAnswer;

                  Color backgroundColor = Colors.grey[900]!;
                  if (_isAnswered) {
                    if (isCorrect) {
                      backgroundColor = Colors.green[800]!;
                    } else if (isSelected) {
                      backgroundColor = Colors.red[800]!;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: backgroundColor,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isAnswered ? null : () => _handleAnswer(option),
                        child: Text(
                          option,
                          style: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.onSurface),
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
