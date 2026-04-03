import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

class RadioProxyServer {
  HttpServer? _server;
  http.Client? _httpClient;
  StreamSubscription? _sourceSubscription;
  http.StreamedResponse? _sourceResponse;

  String? _targetUrl;
  final List<IOSink> _clients = [];

  IOSink? _recordSink;
  bool _isRecording = false;

  Timer? _idleTimer;

  int get port => _server?.port ?? 0;

  bool get isRunning => _server != null;
  String? get targetUrl => _targetUrl;

  void _checkIdle() {
    _idleTimer?.cancel();
    if (_clients.isEmpty && !_isRecording) {
      _idleTimer = Timer(const Duration(seconds: 5), () {
        if (_clients.isEmpty && !_isRecording) {
          stop();
        }
      });
    }
  }

  Future<void> start(String targetUrl) async {
    if (_targetUrl == targetUrl && isRunning) return;

    await stop();
    _targetUrl = targetUrl;

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    _httpClient = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(targetUrl));
      _sourceResponse = await _httpClient!.send(request);

      _sourceSubscription = _sourceResponse!.stream.listen(
        (chunk) {
          final deadClients = <IOSink>[];
          for (final client in _clients) {
            try {
              client.add(chunk);
            } catch (e) {
              deadClients.add(client);
            }
          }
          for (final dead in deadClients) {
            _clients.remove(dead);
          }
          if (deadClients.isNotEmpty) {
            _checkIdle();
          }

          if (_isRecording && _recordSink != null) {
            try {
              _recordSink!.add(chunk);
            } catch (e) {
              stopRecording();
            }
          }
        },
        onDone: () {
          stop();
        },
        onError: (e) {
          stop();
        },
      );
    } catch (e) {
      await stop();
      return;
    }

    _server!.listen((HttpRequest request) {
      if (_sourceResponse != null) {
        request.response.statusCode = _sourceResponse!.statusCode;
        _sourceResponse!.headers.forEach((key, value) {
          if (key.toLowerCase() != 'transfer-encoding' && key.toLowerCase() != 'connection') {
            request.response.headers.set(key, value);
          }
        });
        // We will send chunked data
        request.response.headers.set('Transfer-Encoding', 'chunked');

        _clients.add(request.response);
        _idleTimer?.cancel();

        request.response.done.then((_) {
          _clients.remove(request.response);
          _checkIdle();
        }).catchError((_) {
          _clients.remove(request.response);
          _checkIdle();
        });
      } else {
        request.response.statusCode = 500;
        request.response.close();
      }
    });

    // Start idle check initially in case player doesn't connect quickly
    _checkIdle();
  }

  void startRecording(IOSink sink) {
    _recordSink = sink;
    _isRecording = true;
    _idleTimer?.cancel();
  }

  void stopRecording() {
    _isRecording = false;
    _recordSink = null;
    _checkIdle();
  }

  Future<void> stop() async {
    _idleTimer?.cancel();
    _idleTimer = null;

    _isRecording = false;
    _recordSink = null;

    await _sourceSubscription?.cancel();
    _sourceSubscription = null;

    _httpClient?.close();
    _httpClient = null;

    _sourceResponse = null;

    for (final client in _clients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _clients.clear();

    await _server?.close(force: true);
    _server = null;
    _targetUrl = null;
  }
}

final radioProxyServer = RadioProxyServer();
