import 'package:flutter/material.dart';
import 'package:blind_social/theme/app_fonts.dart';
import '../services/local_error_logger.dart';

class LocalErrorLogsScreen extends StatefulWidget {
  const LocalErrorLogsScreen({Key? key}) : super(key: key);

  @override
  State<LocalErrorLogsScreen> createState() => _LocalErrorLogsScreenState();
}

class _LocalErrorLogsScreenState extends State<LocalErrorLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await LocalErrorLogger.getLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<void> _clearLogs() async {
    await LocalErrorLogger.clearLogs();
    await _loadLogs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm yerel hata kayıtları temizlendi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Yerel Hata Kayıtları',
          style: TextStyle(
            fontSize: AppFonts.size(24),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Kayıtları Temizle',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Kayıtları Temizle'),
                  content: const Text('Cihazdaki tüm yerel hata günlüklerini silmek istediğinize emin misiniz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('İptal'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearLogs();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Sil', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Text(
                    'Cihazda kayıtlı hata bulunmamaktadır.',
                    style: TextStyle(fontSize: AppFonts.size(18)),
                  ),
                )
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final dateStr = log['timestamp'] as String? ?? '';
                    DateTime? date;
                    if (dateStr.isNotEmpty) {
                      date = DateTime.tryParse(dateStr);
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: ExpansionTile(
                        leading: const Icon(Icons.error_outline, color: Colors.red),
                        title: Text(
                          log['errorMessage']?.toString() ?? 'Bilinmeyen Hata',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppFonts.size(16),
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        subtitle: Text(
                          date != null
                              ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}'
                              : 'Tarih Yok',
                          style: TextStyle(fontSize: AppFonts.size(14)),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[900]
                                : Colors.grey[200],
                            child: SelectableText(
                              log['stackTrace']?.toString() ?? 'Stack trace yok.',
                              style: TextStyle(
                                fontSize: AppFonts.size(14),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
