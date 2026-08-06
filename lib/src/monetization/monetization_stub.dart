import 'package:flutter/foundation.dart';

import 'ad_config.dart';

/// No-op implementation used on platforms without `dart:io` (web).
///
/// Every class mirrors the real (`monetization_io.dart`) public API exactly so
/// game code compiles and runs unchanged on web/desktop-web builds — ads simply
/// never appear there.

/// Additive, fire-and-forget entry point for the whole ads stack. No-op here.
class AdsBootstrap {
  AdsBootstrap._();
  static final AdsBootstrap instance = AdsBootstrap._();

  bool get isInitialised => false;

  Future<void> initialize() async {
    // Ads are unsupported on this platform; nothing to do.
  }
}

/// GDPR/UMP consent gate. No-op here: consent is meaningless without ads.
class ConsentManager {
  ConsentManager({this.testDeviceIds = const <String>[]});

  final List<String> testDeviceIds;

  Future<bool> gather() async => false;

  Future<bool> canRequestAds() async => false;

  Future<void> reset() async {}
}

/// Rewarded-ad wrapper. No-op here: nothing to load or show.
class RewardedAdService {
  RewardedAdService({this.onReward});

  final void Function(AdReward reward)? onReward;

  bool get isReady => false;

  Future<void> load() async {}

  Future<bool> showIfAvailable({VoidCallback? onUnavailable}) async {
    onUnavailable?.call();
    return false;
  }

  void dispose() {}
}
