import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'voice_core.dart';

class VoiceParticipant {
  const VoiceParticipant({
    required this.uid,
    required this.joinedAt,
    required this.muted,
    required this.handRaised,
    required this.updatedAt,
  });

  factory VoiceParticipant.fromMap(String uid, Map<String, dynamic> data) =>
      VoiceParticipant(
        uid: uid,
        joinedAt: data['joinedAt'] as String? ?? '',
        muted: data['muted'] != false,
        handRaised: data['handRaised'] == true,
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );

  final String uid;
  final String joinedAt;
  final bool muted;
  final bool handRaised;
  final DateTime? updatedAt;
}

class _Peer {
  _Peer(this.connection, this.joinedAt);

  final RTCPeerConnection connection;
  final String joinedAt;
  final List<RTCIceCandidate> pendingIce = [];
  Future<void> queue = Future.value();
  Timer? timeout;
  bool failed = false;
  bool connected = false;
}

/// One person's seat in a room's voice chat. Speaks the same Firestore
/// signalling protocol as the Web client, so App and Web users hear each
/// other. Audio goes peer to peer (free direct WebRTC, Google STUN only).
class RoomVoiceSession extends ChangeNotifier {
  RoomVoiceSession({
    required this.roomId,
    required this.uid,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final String roomId;
  final String uid;
  final FirebaseFirestore _db;

  static const _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  bool joining = false;
  bool joined = false;
  bool muted = true;
  bool handRaised = false;
  String problem = '';
  String notice = '';
  Map<String, VoiceParticipant> participants = {};

  String? _joinedAt;
  DateTime _started = DateTime.now();
  Duration _clockOffset = Duration.zero;
  MediaStream? _stream;
  final Map<String, _Peer> _peers = {};
  final List<StreamSubscription<dynamic>> _subs = [];
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _pendingSignals =
      {};
  Timer? _heartbeat;
  Timer? _expiry;
  bool _closed = false;

  DocumentReference<Map<String, dynamic>> get _room =>
      _db.collection('rooms').doc(roomId);
  DocumentReference<Map<String, dynamic>> get _own =>
      _room.collection('voice_participants').doc(uid);
  DocumentReference<Map<String, dynamic>> get _capacity =>
      _room.collection('voice_state').doc('capacity');

  int get peerCount => _peers.length;
  int get connectedCount => _peers.values.where((p) => p.connected).length;
  bool get anyFailed => _peers.values.any((p) => p.failed);

  List<String> get raisedHands => participants.values
      .where((p) => p.uid != uid && p.handRaised)
      .map((p) => p.uid)
      .toList();

  String status({required bool enabled}) => VoiceCore.status(
    enabled: enabled,
    joining: joining,
    joined: joined,
    peers: peerCount,
    connected: connectedCount,
    failed: anyFailed,
    problem: problem,
  );

  void _changed() {
    if (!_closed) notifyListeners();
  }

  Future<void> join() async {
    if (joining || joined || _closed) return;
    joining = true;
    problem = '';
    _changed();
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      if (_closed) {
        await stream.dispose();
        return;
      }
      _stream = stream;
      for (final track in stream.getAudioTracks()) {
        track.enabled = false;
      }
      _joinedAt = VoiceCore.joinedAtNow();
      await _reserve();
      joined = true;
      final presence = await _own.get(const GetOptions(source: Source.server));
      final serverTime = (presence.data()?['updatedAt'] as Timestamp?)
          ?.toDate();
      if (serverTime != null) {
        _started = serverTime;
        _clockOffset = serverTime.difference(DateTime.now());
      }
      _listen();
    } catch (error) {
      final text = '$error';
      await leave(
        message: text.contains('Permission') || text.contains('NotAllowed')
            ? '需要麥克風授權才能加入。'
            : error is _VoiceError
            ? error.message
            : '無法加入語音。',
      );
      return;
    } finally {
      joining = false;
      _changed();
    }
  }

  Future<void> _reserve() async {
    await _db.runTransaction((tx) async {
      final capacity = await tx.get(_capacity);
      final own = await tx.get(_own);
      final uids = List<String>.from(
        capacity.data()?['uids'] as List? ?? const [],
      );
      if (own.exists || uids.contains(uid)) {
        throw const _VoiceError('你已在另一個裝置加入語音。');
      }
      if (uids.length >= VoiceCore.maxParticipants) {
        throw const _VoiceError('語音自習室已滿 8 人。');
      }
      tx.set(_capacity, {
        'uids': [...uids, uid],
      });
      tx.set(_own, {
        'uid': uid,
        'joinedAt': _joinedAt,
        'muted': true,
        'handRaised': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _release() async {
    final joinedAt = _joinedAt;
    if (joinedAt == null) return;
    try {
      await _db.runTransaction((tx) async {
        final own = await tx.get(_own);
        if (!own.exists || own.data()?['joinedAt'] != joinedAt) return;
        final capacity = await tx.get(_capacity);
        final uids = List<String>.from(
          capacity.data()?['uids'] as List? ?? const [],
        )..remove(uid);
        tx.set(_capacity, {'uids': uids});
        tx.delete(_own);
      });
    } catch (error) {
      debugPrint('Voice presence cleanup deferred: $error');
    }
  }

  void _listen() {
    void lost([Object? _]) {
      if (!_closed) unawaited(leave(message: '語音資格已失效或無法同步。'));
    }

    _subs.add(
      _room
          .collection('voice_participants')
          .snapshots(includeMetadataChanges: true)
          .listen((snapshot) {
            if (_closed || snapshot.metadata.isFromCache) return;
            participants = {
              for (final doc in snapshot.docs)
                doc.id: VoiceParticipant.fromMap(doc.id, doc.data()),
            };
            if (!participants.containsKey(uid)) return lost();
            _refreshPeers();
            _changed();
          }, onError: lost),
    );
    _subs.add(
      _room
          .collection('voice_signals')
          .where('to', isEqualTo: uid)
          .snapshots()
          .listen((snapshot) {
            if (_closed) return;
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.removed) {
                _pendingSignals.remove(change.doc.id);
              }
              if (change.type != DocumentChangeType.added) continue;
              final createdAt = (change.doc.data()?['createdAt'] as Timestamp?)
                  ?.toDate();
              if (createdAt == null || createdAt.isBefore(_started)) {
                unawaited(change.doc.reference.delete().catchError((_) {}));
              } else {
                _readSignal(change.doc);
              }
            }
          }, onError: lost),
    );
    var lastMute = _started;
    _subs.add(
      _room
          .collection('voice_mute')
          .doc('current')
          .snapshots(includeMetadataChanges: true)
          .listen((snapshot) {
            if (_closed || snapshot.metadata.isFromCache) return;
            final at = (snapshot.data()?['createdAt'] as Timestamp?)?.toDate();
            if (!snapshot.metadata.hasPendingWrites &&
                at != null &&
                at.isAfter(lastMute)) {
              lastMute = at;
              muted = true;
              notice = '房主已請大家靜音。';
              _applyMic();
            }
          }, onError: lost),
    );
    _heartbeat = Timer.periodic(
      VoiceCore.heartbeatEvery,
      (_) => _writePresence().catchError((_) => lost()),
    );
    _expiry = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshPeers();
      _changed();
    });
  }

  bool _validPeer(String peerUid) {
    final p = participants[peerUid];
    return p != null &&
        !VoiceCore.heartbeatExpired(
          p.updatedAt,
          DateTime.now().add(_clockOffset),
        );
  }

  void _refreshPeers() {
    for (final entry in _peers.entries.toList()) {
      final p = participants[entry.key];
      if (!_validPeer(entry.key) || p?.joinedAt != entry.value.joinedAt) {
        _disconnect(entry.key);
      }
    }
    for (final peerUid in participants.keys) {
      if (peerUid != uid && _validPeer(peerUid)) unawaited(_addPeer(peerUid));
    }
    for (final signal in _pendingSignals.values.toList()) {
      final from = signal.data()?['from'] as String?;
      if (from != null && _validPeer(from)) _readSignal(signal);
    }
  }

  Future<void> _send(String to, String type, Map<String, dynamic> data) async {
    if (_closed) return;
    final payload = jsonEncode(data);
    if (payload.length > 8000) throw const _VoiceError('語音連線資料超過限制。');
    await _room.collection('voice_signals').add({
      'from': uid,
      'to': to,
      'type': type,
      'payload': payload,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _fail(_Peer peer) {
    if (_closed) return;
    peer.failed = true;
    _changed();
  }

  Future<void> _addPeer(String peerUid) async {
    if (_peers.containsKey(peerUid) || _stream == null) return;
    final joinedAt = participants[peerUid]!.joinedAt;
    // Reserve the slot synchronously so refreshes don't double-connect.
    final connection = await createPeerConnection(_rtcConfig);
    if (_closed || _peers.containsKey(peerUid)) {
      await connection.close();
      return;
    }
    final peer = _Peer(connection, joinedAt);
    _peers[peerUid] = peer;
    peer.timeout = Timer(VoiceCore.connectTimeout, () {
      if (!peer.connected) _fail(peer);
    });
    for (final track in _stream!.getAudioTracks()) {
      await connection.addTrack(track, _stream!);
    }
    connection.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _send(peerUid, 'ice', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }).catchError((Object _) {
        _fail(peer);
      });
    };
    connection.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        peer.timeout?.cancel();
        peer.connected = true;
        peer.failed = false;
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        peer.connected = false;
        _fail(peer);
      }
      _changed();
    };
    if (VoiceCore.shouldOffer(uid, peerUid)) {
      peer.queue = peer.queue
          .then((_) async {
            final offer = await connection.createOffer({});
            await connection.setLocalDescription(offer);
            await _send(peerUid, 'offer', {
              'type': offer.type,
              'sdp': offer.sdp,
            });
          })
          .catchError((Object _) {
            _fail(peer);
          });
    }
    _changed();
  }

  void _readSignal(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return;
    final from = data['from'] as String?;
    final type = data['type'] as String?;
    final raw = data['payload'] as String? ?? '';
    if (from == null || from == uid || data['to'] != uid || raw.length > 8000) {
      return;
    }
    final peer = _peers[from];
    if (peer == null || !_validPeer(from)) {
      _pendingSignals[doc.id] = doc;
      return;
    }
    _pendingSignals.remove(doc.id);
    peer.queue = peer.queue
        .then((_) async {
          if (_closed || _peers[from] != peer) return;
          final payload = jsonDecode(raw) as Map<String, dynamic>;
          final connection = peer.connection;
          if (type == 'ice') {
            final ice = RTCIceCandidate(
              payload['candidate'] as String?,
              payload['sdpMid'] as String?,
              (payload['sdpMLineIndex'] as num?)?.toInt(),
            );
            if (await connection.getRemoteDescription() != null) {
              await connection.addCandidate(ice);
            } else {
              peer.pendingIce.add(ice);
            }
            return;
          }
          final isOffer = type == 'offer';
          if (payload['type'] != type ||
              isOffer == VoiceCore.shouldOffer(uid, from)) {
            return;
          }
          await connection.setRemoteDescription(
            RTCSessionDescription(payload['sdp'] as String?, type),
          );
          for (final ice in List.of(peer.pendingIce)) {
            await connection.addCandidate(ice);
          }
          peer.pendingIce.clear();
          if (isOffer) {
            final answer = await connection.createAnswer({});
            await connection.setLocalDescription(answer);
            await _send(from, 'answer', {
              'type': answer.type,
              'sdp': answer.sdp,
            });
          }
        })
        .catchError((Object _) {
          _fail(peer);
        })
        .whenComplete(() => doc.reference.delete().catchError((_) {}));
  }

  void _disconnect(String peerUid) {
    final peer = _peers.remove(peerUid);
    if (peer == null) return;
    peer.timeout?.cancel();
    unawaited(peer.connection.close());
  }

  Future<void> _writePresence() async {
    final joinedAt = _joinedAt;
    await _db.runTransaction((tx) async {
      final snapshot = await tx.get(_own);
      if (_closed || snapshot.data()?['joinedAt'] != joinedAt) {
        throw const _VoiceError('presence moved');
      }
      tx.update(_own, {
        'muted': muted,
        'handRaised': handRaised,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  void _applyMic() {
    for (final track in _stream?.getAudioTracks() ?? const []) {
      track.enabled = !muted;
    }
    _changed();
    _writePresence().catchError((_) {
      if (!_closed) unawaited(leave(message: '語音資格已失效或無法同步。'));
    });
  }

  void toggleMic() {
    if (!joined) return;
    problem = '';
    notice = '';
    muted = !muted;
    _applyMic();
  }

  void toggleHand() {
    if (!joined) return;
    handRaised = !handRaised;
    _applyMic();
  }

  /// Room owner only: ask everyone to mute.
  Future<bool> requestMuteAll() async {
    try {
      await _room.collection('voice_mute').doc('current').set({
        'requestedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> leave({String message = ''}) async {
    problem = message;
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    _heartbeat?.cancel();
    _expiry?.cancel();
    for (final peerUid in _peers.keys.toList()) {
      _disconnect(peerUid);
    }
    final stream = _stream;
    _stream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
    if (joined) await _release();
    joined = false;
    joining = false;
    muted = true;
    handRaised = false;
    participants = {};
    _pendingSignals.clear();
    _changed();
  }

  @override
  void dispose() {
    unawaited(leave());
    _closed = true;
    super.dispose();
  }
}

class _VoiceError implements Exception {
  const _VoiceError(this.message);
  final String message;
  @override
  String toString() => message;
}
