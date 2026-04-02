import 'package:flutter/material.dart';
import 'package:blind_social/theme/app_fonts.dart';
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
      'description':
          'Görme engelliler için özel olarak tasarlanmış, tamamen sesli ve erişilebilir sosyal medya platformuna hoş geldiniz.',
      'icon': 'accessibility_new',
    },
    {
      'title': 'Sesli Odalar',
      'description':
          'İlgi alanlarınıza göre sesli sohbet odaları oluşturun veya mevcut odalara katılarak yeni insanlarla tanışın.',
      'icon': 'record_voice_over',
    },
    {
      'title': 'Gizlilik ve Güvenlik',
      'description':
          'Şifreli odalar oluşturarak özel görüşmeler yapın. Mesajlarınız belirlediğiniz süre sonunda otomatik olarak silinir.',
      'icon': 'security',
    },
    {
      'title': 'Tamamen Erişilebilir',
      'description':
          'Tüm ekran okuyucularla uyumlu çalışmaktadır. Arayüz sayesinde uygulamayı kolayca ve bağımsız bir şekilde kullanın.',
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Atla',
                    style: TextStyle(
                      fontSize: AppFonts.size(18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
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
                        Icon(
                          _getIconData(_pages[index]['icon']!),
                          size: 100,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(height: 40),
                        Text(
                          _pages[index]['title']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontSize: AppFonts.size(28),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          _pages[index]['description']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: AppFonts.size(20),
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
                  TextButton(
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
                        color: _currentPage == 0
                            ? Colors.grey
                            : Theme.of(context).colorScheme.primary,
                        fontSize: AppFonts.size(20),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        width: _currentPage == index ? 16.0 : 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Theme.of(context).colorScheme.secondary
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: AppFonts.size(20),
                        fontWeight: FontWeight.bold,
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
