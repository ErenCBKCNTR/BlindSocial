import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<Map<String, String>> _newsItems = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    try {
      final response = await http.get(Uri.parse('https://www.trthaber.com/xml_mobile.php'));
      if (response.statusCode == 200) {
        // Fix common XML escaping issues
        // Ensure UTF-8 decoding for Turkish characters
        String body = utf8.decode(response.bodyBytes).replaceAll('&', '&amp;');
        // Avoid double escaping if it was already &amp;
        body = body.replaceAll('&amp;amp;', '&amp;');

        final document = XmlDocument.parse(body);
        final items = document.findAllElements('item');

        final parsedItems = items.map((node) {
          final title = node.findElements('title').isNotEmpty
              ? node.findElements('title').first.innerText
              : 'Başlıksız';
          final description = node.findElements('description').isNotEmpty
              ? node.findElements('description').first.innerText
              : 'Açıklama yok.';
          final link = node.findElements('link').isNotEmpty
              ? node.findElements('link').first.innerText
              : '';

          return {
            'title': title,
            'description': description,
            'link': link,
          };
        }).toList();

        setState(() {
          _newsItems = parsedItems;
          _isLoading = false;
        });
      } else {
        _fetchFallbackNews();
      }
    } catch (e) {
      _fetchFallbackNews();
    }
  }

  Future<void> _fetchFallbackNews() async {
    try {
      final response = await http.get(Uri.parse('https://www.haberturk.com/rss/manset.xml'));
      if (response.statusCode == 200) {
        // Fix common XML escaping issues
        // Ensure UTF-8 decoding for Turkish characters
        String body = utf8.decode(response.bodyBytes).replaceAll('&', '&amp;');
        body = body.replaceAll('&amp;amp;', '&amp;');

        final document = XmlDocument.parse(body);
        final items = document.findAllElements('item');

        final parsedItems = items.map((node) {
          final title = node.findElements('title').isNotEmpty
              ? node.findElements('title').first.innerText
              : 'Başlıksız';
          final description = node.findElements('description').isNotEmpty
              ? node.findElements('description').first.innerText
              : 'Açıklama yok.';
          final link = node.findElements('link').isNotEmpty
              ? node.findElements('link').first.innerText
              : '';

          return {
            'title': title,
            'description': description,
            'link': link,
          };
        }).toList();

        setState(() {
          _newsItems = parsedItems;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güncel Haberler'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? const Center(child: Text('Haberler yüklenirken bir hata oluştu.'))
              : ListView.builder(
                  itemCount: _newsItems.length,
                  itemBuilder: (context, index) {
                    final item = _newsItems[index];
                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text(
                          item['title']!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NewsDetailScreen(
                                title: item['title']!,
                                description: item['description']!,
                                initialIndex: index,
                                newsList: _newsItems,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
