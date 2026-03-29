import 'package:flutter/material.dart';
import 'package:html/parser.dart';

class NewsDetailScreen extends StatelessWidget {
  final String title;
  final String description;

  const NewsDetailScreen({super.key, required this.title, required this.description});

  String _stripHtmlTags(String htmlString) {
    var document = parse(htmlString);
    return document.body?.text ?? htmlString;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haber Detayı'),
      ),
      body: SingleChildScrollView(
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
    );
  }
}
