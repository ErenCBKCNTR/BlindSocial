import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../services/permission_manager.dart';

const String liveKitUrl = 'wss://bs-app-l1mgfyed.livekit.cloud';
const String liveKitApiKey = 'APINTM3AUHp6ftW';
const String liveKitApiSecret = 'lQTO4G5gD9rGBFx94LoAl2bh0yaMBAaR6VgHN45ZeoO';

class BSBibCallScreen extends StatefulWidget {
  final String roomId;
  final bool isAdmin;

  const BSBibCallScreen({
    super.key,
    required this.roomId,
    this.isAdmin = false,
  });

  @override
  State<BSBibCallScreen> createState() => _BSBibCallScreenState();
}

class _BSBibCallScreenState extends State<BSBibCallScreen> {
  Room? _room;
  bool _isConnecting = true;
  bool _hasError = false;
  String _errorMessage = '';
  VideoTrack? _remoteVideoTrack;
  bool _isFrozen = false;

  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı bulunamadı.');
      }

      if (!widget.isAdmin) {
        final hasPermissions = await PermissionManager.requestBsBibPermissions(context);
        if (!hasPermissions) {
          setState(() {
            _isConnecting = false;
          });
          if (mounted) {
            Navigator.pop(context);
          }
          return;
        }
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final username = userDoc.data()?['username'] ?? 'Kullanıcı';

      final roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      );

      _room = Room(roomOptions: roomOptions);

      _room!.events.listen((event) {
        if (event is TrackSubscribedEvent) {
          if (event.track is VideoTrack) {
            setState(() {
              _remoteVideoTrack = event.track as VideoTrack;
            });
          }
        } else if (event is TrackUnsubscribedEvent) {
          if (event.track.sid == _remoteVideoTrack?.sid) {
            setState(() {
              _remoteVideoTrack = null;
            });
          }
        } else if (event is ParticipantDisconnectedEvent) {
           if(mounted){
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('${event.participant.identity} çağrıdan ayrıldı.'))
             );
           }
        } else if (event is ParticipantConnectedEvent) {
          if (!widget.isAdmin) {
            // Bolt: Replaced deprecated 'position' with 'cameraPosition' for livekit_client compatibility
            _room!.localParticipant?.setCameraEnabled(true,
              cameraCaptureOptions: const CameraCaptureOptions(
                cameraPosition: CameraPosition.back,
                params: VideoParameters(
                  dimensions: VideoDimensions(640, 480),
                  encoding: VideoEncoding(maxBitrate: 400 * 1000, maxFramerate: 15),
                ),
              ));
          }
        }
      });

      // Token generated simply on client for demonstration
      // Normally, this should be done on the server-side
      final token = _generateToken(
        widget.roomId,
        username,
        liveKitApiKey,
        liveKitApiSecret,
      );

      await _room!.connect(liveKitUrl, token);

      if (!widget.isAdmin) {
        // User: Publish microphone only initially. Wait for admin to join before publishing camera
        if (_room!.remoteParticipants.isNotEmpty) {
           // Bolt: Replaced deprecated 'position' with 'cameraPosition' for livekit_client compatibility
           await _room!.localParticipant?.setCameraEnabled(true,
             cameraCaptureOptions: const CameraCaptureOptions(
               cameraPosition: CameraPosition.back,
               params: VideoParameters(
                 dimensions: VideoDimensions(640, 480),
                 encoding: VideoEncoding(maxBitrate: 400 * 1000, maxFramerate: 15),
               ),
             ));
        }

        await _room!.localParticipant?.setMicrophoneEnabled(true);

        // Write to Firestore
        await _firestore.collection('bs_bib_calls').doc(widget.roomId).set({
          'roomId': widget.roomId,
          'callerId': user.uid,
          'callerName': username,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Admin: Only microphone
        await _room!.localParticipant?.setMicrophoneEnabled(true);
      }

      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isConnecting = false;
      });
    }
  }

  // Token generation helper (simplified for client-side demo)
  String _generateToken(
      String roomName, String participantName, String apiKey, String apiSecret) {

    final jwt = JWT(
      {
        'video': {
          'room': roomName,
          'roomJoin': true,
        },
        'name': participantName,
      },
      issuer: apiKey,
      subject: participantName,
    );

    return jwt.sign(SecretKey(apiSecret),
        expiresIn: const Duration(hours: 2));
  }

  Future<void> _endCall() async {
    await _room?.disconnect();
    if (!widget.isAdmin) {
      await _firestore.collection('bs_bib_calls').doc(widget.roomId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.yellow),
              const SizedBox(height: 20),
              Text(
                'Bağlanıyor...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
              )
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('BS BiB - Hata')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bir hata oluştu:',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.red),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Geri Dön'),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Area
            if (widget.isAdmin && _remoteVideoTrack != null)
               _isFrozen
                ? const Center(child: Text("Görüntü Donduruldu", style: TextStyle(color: Colors.yellow, fontSize: 24, fontWeight: FontWeight.bold)))
                : Positioned.fill(
                    child: VideoTrackRenderer(_remoteVideoTrack!),
                  )
            else if (!widget.isAdmin && _room?.localParticipant?.videoTrackPublications.isNotEmpty == true)
               Positioned.fill(
                   child: VideoTrackRenderer(_room!.localParticipant!.videoTrackPublications.first.track as VideoTrack),
               )
            else
               const Center(child: Text('Görüntü Bekleniyor...', style: TextStyle(color: Colors.white))),

            // Controls
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isAdmin && _remoteVideoTrack != null)
                     ElevatedButton.icon(
                        onPressed: () {
                           setState(() {
                              _isFrozen = !_isFrozen;
                           });
                        },
                        icon: Icon(_isFrozen ? Icons.play_arrow : Icons.pause),
                        label: Text(_isFrozen ? 'Görüntüyü Çöz' : 'Görüntüyü Dondur'),
                        style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.blue,
                           foregroundColor: Colors.white,
                        )
                     ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _endCall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                    child: const Text('Aramayı Sonlandır', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
