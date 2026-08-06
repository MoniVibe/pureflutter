import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Platform-neutral value object for a rewarded-ad payout.
///
/// Kept deliberately free of any `google_mobile_ads` type so the public kit
/// surface is identical on every platform (mobile real impl + web/desktop
/// stub). The mobile implementation maps Google's `RewardItem` into this.
class AdReward {
  const AdReward(this.amount, this.type);

  /// Amount of the reward as configured on the ad unit in the AdMob console.
  final num amount;

  /// Reward type string as configured on the ad unit.
  final String type;

  @override
  String toString() => 'AdReward(amount: $amount, type: $type)';
}

/// Central, single-edit configuration seam for AdMob identifiers.
///
/// Google supplies dedicated *test* ad units that always return fill and never
/// risk an account ban during development. This kit ships those by default.
///
/// TO GO LIVE (the ONLY code edits required):
///   1. Paste the director-provided IDs into the `_prod*` constants below.
///   2. Build with `--dart-define=bullethole.ads.prod=true` (or flip
///      [useProductionAds]'s default to `true`).
///   3. Update the AndroidManifest `com.google.android.gms.ads.APPLICATION_ID`
///      meta-data (and iOS `GADApplicationIdentifier`) to the real app ID —
///      those live in native config and must match [appId].
class AdConfig {
  const AdConfig._();

  /// The single production/test seam. Defaults to safe TEST ads. Can be forced
  /// on at build time with `--dart-define=bullethole.ads.prod=true` so the same
  /// binary source can produce a store build without editing this file.
  static const bool useProductionAds =
      bool.fromEnvironment('bullethole.ads.prod');

  // --- Google's official sample/test IDs (safe, never ban an account) ---
  // Android: https://developers.google.com/admob/android/test-ads
  // iOS:     https://developers.google.com/admob/ios/test-ads
  static const String _testAndroidAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String _testIosAppId = 'ca-app-pub-3940256099942544~1458002511';
  static const String _testAndroidRewarded =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosRewarded =
      'ca-app-pub-3940256099942544/1712485313';

  // --- PRODUCTION placeholders — REPLACE with director-provided IDs. ---
  // Leaving these as placeholders is safe: [useProductionAds] defaults to false
  // so they are never used until deliberately switched on.
  static const String _prodAndroidAppId = 'REPLACE_WITH_PROD_ANDROID_APP_ID';
  static const String _prodIosAppId = 'REPLACE_WITH_PROD_IOS_APP_ID';
  static const String _prodAndroidRewarded =
      'REPLACE_WITH_PROD_ANDROID_REWARDED_UNIT_ID';
  static const String _prodIosRewarded =
      'REPLACE_WITH_PROD_IOS_REWARDED_UNIT_ID';

  /// True on iOS at runtime. Uses [defaultTargetPlatform] (not `dart:io`) so the
  /// file stays compilable for web/desktop targets.
  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// AdMob application ID for the current platform. The value that actually
  /// wires the SDK lives in the native manifest; this is exposed for
  /// reference/telemetry and to keep the two in sync.
  static String get appId {
    if (useProductionAds) {
      return _isIos ? _prodIosAppId : _prodAndroidAppId;
    }
    return _isIos ? _testIosAppId : _testAndroidAppId;
  }

  /// Rewarded ad-unit ID for the current platform.
  static String get rewardedUnitId {
    if (useProductionAds) {
      return _isIos ? _prodIosRewarded : _prodAndroidRewarded;
    }
    return _isIos ? _testIosRewarded : _testAndroidRewarded;
  }

  /// True while running on Google's test inventory (i.e. not yet live).
  static bool get usingTestAds => !useProductionAds;
}
