import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Blind Social\'a Hoş Geldiniz',
      'description': 'Görme engelliler için özel olarak tasarlanmış, tamamen sesli ve erişilebilir sosyal medya platformuna hoş geldiniz.',
      'icon': 'accessibility_new',
    },
    {
      'title': 'Sesli Odalar',
      'description': 'İlgi alanlarınıza göre sesli sohbet odaları oluşturun veya mevcut odalara katılarak yeni insanlarla tanışın.',
      'icon': 'record_voice_over',
    },
    {
      'title': 'Gizlilik ve Güvenlik',
      'description': 'Şifreli odalar oluşturarak özel görüşmeler yapın. Mesajlarınız belirlediğiniz süre sonunda otomatik olarak silinir.',
      'icon': 'security',
    },
    {
      'title': 'Tamamen Erişilebilir',
      'description': 'TalkBack ve VoiceOver ile tam uyumlu arayüz sayesinde uygulamayı kolayca ve bağımsız bir şekilde kullanın.',
      'icon': 'hearing',
    },
  ];

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'accessibility_new':
        return Icons.accessibility_new;
      case 'record_voice_over':
        return Icons.record_voice_over;
      case 'security':
        return Icons.security;
      case 'hearing':
        return Icons.hearing;
      default:
        return Icons.info;
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          label: 'Sayfa ${index + 1} ikonu',
                          child: Icon(
                            _getIconData(_pages[index]['icon']!),
                            size: 100,
                            color: Colors.yellow,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Semantics(
                          label: 'Başlık: ${_pages[index]['title']}',
                          child: Text(
                            _pages[index]['title']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.cyan,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Semantics(
                          label: 'Açıklama: ${_pages[index]['description']}',
                          child: Text(
                            _pages[index]['description']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    button: true,
                    label: 'Geri butonu',
                    hint: 'Önceki sayfaya dönmek için çift dokunun',
                    child: TextButton(
                      onPressed: _currentPage == 0
                          ? null
                          : () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                      child: Text(
                        'Geri',
                        style: TextStyle(
                          color: _currentPage == 0 ? Colors.grey : Colors.yellow,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Semantics(
                        label: 'Sayfa göstergesi ${index + 1} / ${_pages.length}',
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          width: _currentPage == index ? 16.0 : 8.0,
                          height: 8.0,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? Colors.cyan : Colors.grey,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: _currentPage == _pages.length - 1 ? 'Başla butonu' : 'İleri butonu',
                    hint: _currentPage == _pages.length - 1
                        ? 'Uygulamaya başlamak için çift dokunun'
                        : 'Sonraki sayfaya geçmek için çift dokunun',
                    child: TextButton(
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Başla' : 'İleri',
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
