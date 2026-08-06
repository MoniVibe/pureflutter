import 'package:flutter/foundation.dart';

/// Minimal, dependency-free analytics seam.
///
/// The kit ships [NoOpAnalyticsService] as the default so the games run with
/// ZERO analytics config (no Firebase `google-services.json` required, nothing
/// to break a build). When the director wants real analytics, implement
/// [AnalyticsService] with a Firebase (or other) backend and assign it once at
/// startup via [AppAnalytics.instance]. No other game code has to change.
///
/// This file intentionally imports nothing beyond `foundation`, so it is safe
/// on every platform (mobile, desktop, web) and every test target.
abstract class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object?>? parameters});
  Future<void> logScreenView(String screenName);
  Future<void> setUserProperty(String name, String? value);
}

/// Default implementation: swallows everything. In debug builds it echoes the
/// event stream to the console so you can watch instrumentation without wiring
/// a backend.
class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService({this.echoInDebug = true});

  final bool echoInDebug;

  @override
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {
    if (echoInDebug && kDebugMode) {
      debugPrint('[analytics] event: $name ${parameters ?? const {}}');
    }
  }

  @override
  Future<void> logScreenView(String screenName) async {
    if (echoInDebug && kDebugMode) {
      debugPrint('[analytics] screen: $screenName');
    }
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    if (echoInDebug && kDebugMode) {
      debugPrint('[analytics] userProperty: $name=$value');
    }
  }
}

/// Global holder. Off by default (no-op). Swap [instance] at startup to enable a
/// real backend:
///
/// ```dart
/// AppAnalytics.instance = FirebaseAnalyticsService();
/// ```
class AppAnalytics {
  AppAnalytics._();

  static AnalyticsService instance = const NoOpAnalyticsService();
}
