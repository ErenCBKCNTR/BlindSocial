import 'package:flutter/material.dart';
import 'package:html/parser.dart';

class NewsDetailScreen extends StatefulWidget {
  final String title;
  final String description;
  final int initialIndex;
  final List<Map<String, String>> newsList;

  const NewsDetailScreen({
    super.key,
    required this.title,
    required this.description,
    this.initialIndex = 0,
    this.newsList = const [],
  });

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late int _currentIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _stripHtmlTags(String htmlString) {
    var document = parse(htmlString);
    return document.body?.text ?? htmlString;
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.newsList.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasList = widget.newsList.isNotEmpty;
    final title = hasList ? widget.newsList[_currentIndex]['title']! : widget.title;
    final description =
        hasList ? widget.newsList[_currentIndex]['description']! : widget.description;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haber Detayı'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _stripHtmlTags(description),
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasList)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Semantics(
                    label: "Bir önceki habere geçiş yap",
                    button: true,
                    enabled: _currentIndex > 0,
                    child: ElevatedButton.icon(
                      onPressed: _currentIndex > 0 ? _goToPrevious : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Önceki Haber'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  Semantics(
                    label: "Sıradaki haberi oku",
                    button: true,
                    enabled: _currentIndex < widget.newsList.length - 1,
                    child: ElevatedButton.icon(
                      onPressed: _currentIndex < widget.newsList.length - 1 ? _goToNext : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Sonraki Haber'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
