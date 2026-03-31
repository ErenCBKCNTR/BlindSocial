import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateScreen extends StatelessWidget {
  final String updateUrl;

  const UpdateScreen({super.key, required this.updateUrl});

  Future<void> _contactAdminViaWhatsApp(BuildContext context) async {
    const phoneNumber = '905345991728';
    const message = 'Merhaba, uygulamanın güncel sürümünü almak için iletişime geçiyorum.';
    final whatsappUrl = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

    try {
      if (!await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
           _showFallbackMessage(context);
        }
      }
    } catch (e) {
       if (context.mounted) {
           _showFallbackMessage(context);
       }
    }
  }

  void _showFallbackMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(
            'Hata',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          content: Text(
            'WhatsApp uygulaması açılamadı. Lütfen yönetici ile iletişime geçiniz: 0534 599 17 28',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Tamam',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 18),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.system_update_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 100,
                ),
                SizedBox(height: 32),
                Text(
                  'Güncelleme Gerekli',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Uygulamanın daha iyi ve sorunsuz çalışması için yeni sürümü yüklemelisiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _contactAdminViaWhatsApp(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 70),
                  ),
                  child: const Text(
                    'Uygulamayı Güncelle',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
