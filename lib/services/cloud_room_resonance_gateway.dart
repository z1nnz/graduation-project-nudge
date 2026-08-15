import 'package:cloud_functions/cloud_functions.dart';

import '../models/room_resonance.dart';

typedef RoomResonanceCallable =
    Future<Object?> Function(Map<String, dynamic> payload);
typedef RoomResonanceRequestIdFactory = String Function();

class RoomResonanceException implements Exception {
  const RoomResonanceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'RoomResonanceException($code): $message';
}

class CloudRoomResonanceGateway {
  CloudRoomResonanceGateway.withCallable(
    RoomResonanceCallable call, {
    RoomResonanceRequestIdFactory? requestIdFactory,
  }) : _call = call,
       _requestIdFactory = requestIdFactory ?? _defaultRequestId;

  final RoomResonanceCallable _call;
  final RoomResonanceRequestIdFactory _requestIdFactory;

  static String _defaultRequestId() =>
      'resonance_${DateTime.now().toUtc().microsecondsSinceEpoch}';

  factory CloudRoomResonanceGateway.firebase({FirebaseFunctions? functions}) {
    return CloudRoomResonanceGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('manageRoomResonance');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  Future<Map<String, dynamic>> _command(
    String action,
    String roomId, {
    Map<String, dynamic> fields = const {},
  }) async {
    if (roomId.trim().isEmpty) {
      throw const RoomResonanceException('invalid-argument', '必須先選擇活動房。');
    }
    try {
      final response = await _call({
        'action': action,
        'roomId': roomId.trim(),
        'sourceSurface': 'app',
        'clientRequestId': _requestIdFactory(),
        ...fields,
      });
      return roomResonanceMap(response);
    } on FirebaseFunctionsException catch (error) {
      throw RoomResonanceException(error.code, error.message ?? '共振訊號同步失敗。');
    } on RoomResonanceException {
      rethrow;
    } catch (_) {
      throw const RoomResonanceException('protocol-error', '共振訊號服務回傳了無效資料。');
    }
  }

  Future<RoomResonancePreference> setPreference({
    required String roomId,
    required String userId,
    required bool enabled,
  }) async {
    final response = await _command(
      'set_preference',
      roomId,
      fields: {'enabled': enabled},
    );
    try {
      return RoomResonancePreference.fromMap(
        roomResonanceMap(response['preference']),
        expectedRoomId: roomId,
        expectedUserId: userId,
      );
    } catch (_) {
      throw const RoomResonanceException('protocol-error', '共振分享設定資料不完整。');
    }
  }

  Future<RoomResonanceSignal> publish({
    required String roomId,
    required RoomResonanceCue cue,
  }) async {
    final response = await _command(
      'publish',
      roomId,
      fields: {'cueKey': cue.wireKey},
    );
    return _parseSignal(response, roomId);
  }

  Future<RoomResonanceSignal> withdraw({required String roomId}) async {
    final response = await _command('withdraw', roomId);
    return _parseSignal(response, roomId);
  }

  Future<RoomResonanceSignal> acknowledge({
    required String roomId,
    required String ownerUserId,
    required String generationId,
    required RoomResonanceResponse response,
  }) async {
    final result = await _command(
      'acknowledge',
      roomId,
      fields: {
        'ownerUserId': ownerUserId,
        'generationId': generationId,
        'responseKey': response.wireKey,
      },
    );
    return _parseSignal(result, roomId);
  }

  RoomResonanceSignal _parseSignal(
    Map<String, dynamic> response,
    String roomId,
  ) {
    try {
      return RoomResonanceSignal.fromMap(
        roomResonanceMap(response['signal']),
        expectedRoomId: roomId,
      );
    } catch (_) {
      throw const RoomResonanceException('protocol-error', '共振訊號資料不完整。');
    }
  }
}
