import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class FirebaseAppCheckService {
  static const _webRecaptchaSiteKey = String.fromEnvironment(
    'FIREBASE_APP_CHECK_RECAPTCHA_KEY',
  );

  static Future<void> activate() async {
    final webProvider = kIsWeb
        ? (kDebugMode ? WebDebugProvider() : _productionWebProvider())
        : null;
    await FirebaseAppCheck.instance.activate(
      providerWeb: webProvider,
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }

  static WebProvider _productionWebProvider() {
    if (_webRecaptchaSiteKey.isEmpty) {
      throw StateError(
        'FIREBASE_APP_CHECK_RECAPTCHA_KEY is required for production web.',
      );
    }
    return ReCaptchaV3Provider(_webRecaptchaSiteKey);
  }
}
