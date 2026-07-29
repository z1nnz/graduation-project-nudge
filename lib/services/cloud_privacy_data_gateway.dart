import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/privacy_data_request.dart';

typedef PrivacyDataCallable =
    Future<Object?> Function(String name, Map<String, dynamic> payload);
typedef PrivacyDataWatch =
    Stream<List<PrivacyDataRequest>> Function(String userId);

class PrivacyDataException implements Exception {
  const PrivacyDataException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PrivacyDataException($code): $message';
}

class CloudPrivacyDataGateway {
  const CloudPrivacyDataGateway.withAdapters({
    required PrivacyDataCallable call,
    required PrivacyDataWatch watch,
  }) : _call = call,
       _watch = watch;

  final PrivacyDataCallable _call;
  final PrivacyDataWatch _watch;

  factory CloudPrivacyDataGateway.firebase({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) {
    final cloudFunctions =
        functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1');
    final cloudFirestore = firestore ?? FirebaseFirestore.instance;
    return CloudPrivacyDataGateway.withAdapters(
      call: (name, payload) async {
        final response = await cloudFunctions
            .httpsCallable(name)
            .call<dynamic>(payload);
        return response.data;
      },
      watch: (userId) {
        return cloudFirestore
            .collection('privacy_data_requests')
            .where('userId', isEqualTo: userId)
            .snapshots()
            .map((snapshot) {
              final requests = <PrivacyDataRequest>[];
              for (final document in snapshot.docs) {
                try {
                  requests.add(
                    PrivacyDataRequest.fromMap(
                      document.data(),
                      documentId: document.id,
                    ),
                  );
                } on FormatException {
                  // Fail one malformed record closed without hiding valid cases.
                }
              }
              requests.sort((a, b) {
                final aDate =
                    a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bDate =
                    b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return bDate.compareTo(aDate);
              });
              return List<PrivacyDataRequest>.unmodifiable(requests);
            });
      },
    );
  }

  Stream<List<PrivacyDataRequest>> watchRequests(String userId) {
    return _watch(userId);
  }

  Future<PrivacyDataRequestResult> requestExport({
    required String clientRequestId,
  }) {
    return _request({
      'action': 'request_export',
      'clientRequestId': clientRequestId,
      'sourceSurface': 'app',
    });
  }

  Future<PrivacyDataRequestResult> requestAccountDeletion({
    required String clientRequestId,
    String reason = '',
  }) {
    return _request({
      'action': 'request_account_deletion',
      'clientRequestId': clientRequestId,
      'sourceSurface': 'app',
      'reason': reason,
    });
  }

  Future<PrivacyDataRequestResult> cancel({
    required String requestId,
    required String clientRequestId,
  }) async {
    return _parseRequestResult(
      await _invoke('cancelPrivacyDataRequest', {
        'requestId': requestId,
        'clientRequestId': clientRequestId,
        'sourceSurface': 'app',
      }),
    );
  }

  Future<PrivacyExportDownload> getExportDownload({
    required String requestId,
    required String clientRequestId,
  }) async {
    final response = await _invoke('getPrivacyExportDownload', {
      'requestId': requestId,
      'clientRequestId': clientRequestId,
      'sourceSurface': 'app',
    });
    try {
      return PrivacyExportDownload.fromMap(response);
    } on FormatException {
      throw const PrivacyDataException('protocol-error', '資料匯出下載資訊缺少必要的稽核欄位。');
    }
  }

  Future<PrivacyDataRequestResult> _request(
    Map<String, dynamic> payload,
  ) async {
    return _parseRequestResult(
      await _invoke('requestPrivacyDataAction', payload),
    );
  }

  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _call(name, payload);
      if (response is! Map) {
        throw const PrivacyDataException('protocol-error', '隱私資料服務回傳了無效資料。');
      }
      return response.map((key, value) => MapEntry(key.toString(), value));
    } on FirebaseFunctionsException catch (error) {
      throw PrivacyDataException(error.code, error.message ?? '隱私資料操作未完成。');
    }
  }

  PrivacyDataRequestResult _parseRequestResult(Map<String, dynamic> response) {
    try {
      return PrivacyDataRequestResult.fromMap(response);
    } on FormatException {
      throw const PrivacyDataException('protocol-error', '隱私資料申請結果缺少必要的稽核欄位。');
    }
  }
}
