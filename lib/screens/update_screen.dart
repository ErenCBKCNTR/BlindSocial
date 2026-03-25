import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateScreen extends StatelessWidget {
  final String updateUrl;

  const UpdateScreen({super.key, required this.updateUrl});

  Future<void> _launchUpdate() async {
    final url = Uri.parse(updateUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $updateUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (_) {},
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.system_update_rounded,
                  color: Colors.yellow,
                  size: 100,
                ),
                const SizedBox(height: 32),
                Semantics(
                  label: 'Güncelleme Gerekli başlığı',
                  child: const Text(
                    'Güncelleme Gerekli',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.yellow,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: 'Uygulamanın daha iyi ve sorunsuz çalışması için yeni sürümü yüklemelisiniz içeriği',
                  child: const Text(
                    'Uygulamanın daha iyi ve sorunsuz çalışması için yeni sürümü yüklemelisiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
                const Spacer(),
                Semantics(
                  label: 'Güncellemeyi İndir butonu',
                  hint: 'Dış tarayıcıyı açarak yeni APK dosyasını indirmenizi sağlar',
                  button: true,
                  child: ElevatedButton(
                    onPressed: _launchUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 70),
                    ),
                    child: const Text(
                      'Güncellemeyi İndir',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
