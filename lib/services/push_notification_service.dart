import 'dart:async';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_push_installation_gateway.dart';
import 'notification_service.dart';

typedef PushRouteHandler = void Function(String route);

class PushNotificationService {
  PushNotificationService({
    CloudPushInstallationGateway? gateway,
    FirebaseMessaging? messaging,
  }) : _gateway = gateway ?? CloudPushInstallationGateway.firebase(),
       _messaging = messaging;

  static const _installationIdKey = 'nudge_push_installation_id_v1';

  final CloudPushInstallationGateway _gateway;
  final FirebaseMessaging? _messaging;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _signedInUserId;
  PushRouteHandler? _routeHandler;
  bool _started = false;
  bool _registrationEnabled = false;

  FirebaseMessaging get _client => _messaging ?? FirebaseMessaging.instance;

  bool get isSupported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  void setRouteHandler(PushRouteHandler handler) {
    _routeHandler = handler;
  }

  Future<void> start() async {
    if (_started || !isSupported) return;
    try {
      NotificationService.setPayloadHandler((route) {
        _routeHandler?.call(route);
      });
      _tokenSubscription = _client.onTokenRefresh.listen((token) {
        if (_signedInUserId != null && _registrationEnabled) {
          unawaited(_registerToken(token));
        }
      });
      _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        unawaited(
          NotificationService.showRemoteNotification(
            notificationId: message.messageId ?? message.data['notificationId'],
            title: notification.title ?? 'Nudge',
            body: notification.body ?? '',
            payload: message.data['route']?.toString(),
          ),
        );
      });
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleOpenedMessage,
      );
      _started = true;
      final initialMessage = await _client.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }
    } catch (error) {
      debugPrint('Push notification startup error: $error');
    }
  }

  Future<bool> enableForUser(String userId) async {
    if (!isSupported) return false;
    _signedInUserId = userId;
    await start();
    try {
      final settings = await _client.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (!_isAuthorized(settings.authorizationStatus)) return false;
      _registrationEnabled = true;
      final token = await _currentToken();
      if (token == null) return false;
      final result = await _registerToken(token);
      return result;
    } catch (error) {
      debugPrint('Push notification enable error: $error');
      return false;
    }
  }

  Future<bool> syncIfAuthorized(String userId) async {
    if (!isSupported) return false;
    _signedInUserId = userId;
    await start();
    try {
      final settings = await _client.getNotificationSettings();
      if (!_isAuthorized(settings.authorizationStatus)) return false;
      _registrationEnabled = true;
      final token = await _currentToken();
      if (token == null) return false;
      return await _registerToken(token);
    } catch (error) {
      debugPrint('Push notification sync error: $error');
      return false;
    }
  }

  void clearSignedInUser() {
    _signedInUserId = null;
    _registrationEnabled = false;
  }

  Future<void> revokeForUser(String userId) async {
    await _revoke(userId, requireCloudAudit: false);
    if (_signedInUserId == userId) _signedInUserId = null;
  }

  Future<void> disableForUser(String userId) async {
    await _revoke(userId, requireCloudAudit: true);
    _signedInUserId = userId;
  }

  Future<void> _revoke(String userId, {required bool requireCloudAudit}) async {
    if (!isSupported) return;
    _signedInUserId = userId;
    _registrationEnabled = false;
    Object? cloudError;
    StackTrace? cloudStackTrace;
    try {
      final installationId = await _installationId();
      await _gateway.revoke(
        installationId: installationId,
        clientRequestId: _requestId('push_revoke'),
      );
    } catch (error, stackTrace) {
      debugPrint('Push notification revoke error: $error');
      cloudError = error;
      cloudStackTrace = stackTrace;
    }
    try {
      await _client.deleteToken();
    } catch (error) {
      debugPrint('Push token deletion error: $error');
    }
    if (requireCloudAudit && cloudError != null) {
      Error.throwWithStackTrace(cloudError, cloudStackTrace!);
    }
  }

  Future<bool> _registerToken(String token) async {
    final userId = _signedInUserId;
    if (userId == null || token.trim().isEmpty) return false;
    final installationId = await _installationId();
    final result = await _gateway.register(
      installationId: installationId,
      platform: _platformKey(),
      token: token,
      clientRequestId: _requestId('push_register'),
    );
    return result.configured;
  }

  Future<String?> _currentToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken = await _client.getAPNSToken();
      if (apnsToken == null || apnsToken.isEmpty) return null;
    }
    final token = await _client.getToken();
    return token?.trim().isEmpty ?? true ? null : token;
  }

  bool _isAuthorized(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  String _platformKey() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => throw UnsupportedError('Push notifications are unsupported.'),
    };
  }

  Future<String> _installationId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_installationIdKey);
    if (existing != null &&
        RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    final suffix = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final generated =
        'device_${DateTime.now().toUtc().microsecondsSinceEpoch}_$suffix';
    await preferences.setString(_installationIdKey, generated);
    return generated;
  }

  String _requestId(String prefix) {
    return '${prefix}_${DateTime.now().toUtc().microsecondsSinceEpoch}';
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final route = message.data['route']?.toString().trim() ?? '';
    if (route.isNotEmpty) _routeHandler?.call(route);
  }

  Future<void> dispose() async {
    _signedInUserId = null;
    _registrationEnabled = false;
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
