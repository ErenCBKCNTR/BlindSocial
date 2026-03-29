import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // TRT Haber RSS
      final response = await http.get(Uri.parse('https://www.trthaber.com/xml_mobile.php?tur=xml_genel&adet=20'));

      if (response.statusCode == 200) {
        final body = response.body;

        // Basic regex parsing for RSS <item> tags
        final itemRegExp = RegExp(r'<item>([\s\S]*?)<\/item>');
        final titleRegExp = RegExp(r'<title><!\[CDATA\[(.*?)\]\]><\/title>');
        final linkRegExp = RegExp(r'<link>(.*?)<\/link>');

        final items = itemRegExp.allMatches(body);
        final List<Map<String, String>> parsedNews = [];

        for (final item in items) {
          final itemStr = item.group(1) ?? '';
          final titleMatch = titleRegExp.firstMatch(itemStr);
          final linkMatch = linkRegExp.firstMatch(itemStr);

          if (titleMatch != null && linkMatch != null) {
            parsedNews.add({
              'title': titleMatch.group(1)?.trim() ?? '',
              'link': linkMatch.group(1)?.trim() ?? '',
            });
          }
        }

        setState(() {
          _newsItems = parsedNews;
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Haber açılamadı.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Güncel Haberler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNews,
            tooltip: 'Haberleri Yenile',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Haberler yüklenemedi.',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchNews,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : _newsItems.isEmpty
                  ? const Center(
                      child: Text(
                        'Haber bulunamadı.',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _newsItems.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.grey),
                      itemBuilder: (context, index) {
                        final news = _newsItems[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          title: Text(
                            news['title'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: const Icon(Icons.open_in_new, color: Colors.blueAccent),
                          onTap: () => _launchUrl(news['link'] ?? ''),
                        );
                      },
                    ),
    );
  }
}
