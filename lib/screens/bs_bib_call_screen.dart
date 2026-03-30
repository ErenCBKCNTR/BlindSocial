import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/permission_manager.dart';

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
  bool _isConnecting = true;
  bool _hasError = false;
  String _errorMessage = '';

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isMicMuted = false;
  bool _isCameraFront = false;

  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initRenderers().then((_) => _connect());
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
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

      await _initWebRTC();

      if (!widget.isAdmin) {
        await _createOffer();
      } else {
        await _joinRoom();
      }

    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isConnecting = false;
      });
    }
  }

  Future<void> _initWebRTC() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': widget.isAdmin ? 'user' : 'environment', // User starts with rear camera by default
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = _localStream;

    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onAddStream = (stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
      });
    };

    _peerConnection?.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
         setState(() {
           _isConnecting = false;
         });
      }
    };
  }

  Future<void> _createOffer() async {
    final roomRef = _firestore.collection('bs_bib_calls').doc(widget.roomId);

    _peerConnection?.onIceCandidate = (candidate) {
      roomRef.collection('caller_candidates').add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    final offer = await _peerConnection?.createOffer();
    await _peerConnection?.setLocalDescription(offer!);

    await roomRef.set({
      'roomId': widget.roomId,
      'callerId': _auth.currentUser?.uid,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'offer': {
        'type': offer!.type,
        'sdp': offer.sdp,
      }
    });

    setState(() {
        _isConnecting = false;
    });

    roomRef.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      final remoteDesc = await _peerConnection?.getRemoteDescription();
      if (remoteDesc == null && data != null && data['answer'] != null) {
        var answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        await _peerConnection?.setRemoteDescription(answer);
      }
    });

    roomRef.collection('callee_candidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          _peerConnection?.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });
  }

  Future<void> _joinRoom() async {
    final roomRef = _firestore.collection('bs_bib_calls').doc(widget.roomId);

    _peerConnection?.onIceCandidate = (candidate) {
      roomRef.collection('callee_candidates').add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    final roomDoc = await roomRef.get();
    if (!roomDoc.exists) {
      throw Exception('Oda bulunamadı.');
    }

    final offer = roomDoc.data()?['offer'];
    if (offer != null) {
      await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
    }

    final answer = await _peerConnection?.createAnswer();
    await _peerConnection?.setLocalDescription(answer!);

    await roomRef.update({
      'answer': {
        'type': answer!.type,
        'sdp': answer.sdp,
      }
    });

    roomRef.collection('caller_candidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          _peerConnection?.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });
  }

  void _toggleMic() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
      setState(() {
        _isMicMuted = !audioTrack.enabled;
      });
    }
  }

  void _switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
      setState(() {
        _isCameraFront = !_isCameraFront;
      });
    }
  }

  Future<void> _endCall() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();

    if (!widget.isAdmin) {
      final roomRef = _firestore.collection('bs_bib_calls').doc(widget.roomId);

      roomRef.collection('caller_candidates').get().then((callerCandidates) {
        for (var doc in callerCandidates.docs) {
          doc.reference.delete();
        }
      });

      roomRef.collection('callee_candidates').get().then((calleeCandidates) {
        for (var doc in calleeCandidates.docs) {
          doc.reference.delete();
        }
      });

      roomRef.delete();
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _localStream?.dispose();
    _peerConnection?.close();
    _peerConnection?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting && _remoteRenderer.srcObject == null) {
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
            // Remote Video Area (Full Screen)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),

            // Local Video Area (PiP)
            Positioned(
              right: 20,
              bottom: 120,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: _isCameraFront,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

            // Controls
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Semantics(
                    label: _isMicMuted ? 'Mikrofonu Aç' : 'Mikrofonu Kapat',
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: _isMicMuted ? Colors.red : Colors.white24,
                      child: IconButton(
                        icon: Icon(
                          _isMicMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                        ),
                        onPressed: _toggleMic,
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Kamerayı Çevir',
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.white24,
                      child: IconButton(
                        icon: const Icon(
                          Icons.switch_camera,
                          color: Colors.white,
                        ),
                        onPressed: _switchCamera,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _endCall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text('Aramayı Sonlandır', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
