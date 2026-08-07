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
/// TO GO LIVE, per app (each app is its OWN AdMob app with its OWN ids):
///   1. Call [AdConfig.configure] in the app's `main()` with that app's real
///      production ids (app id + interstitial / rewarded unit ids).
///   2. Build with `--dart-define=bullethole.ads.prod=true`.
///   3. Set the AndroidManifest `com.google.android.gms.ads.APPLICATION_ID`
///      meta-data (and iOS `GADApplicationIdentifier`) to that app's real app
///      ID — those live in native config and must match [appId].
class AdConfig {
  const AdConfig._();

  /// The single production/test seam. Defaults to safe TEST ads. Can be forced
  /// on at build time with `--dart-define=bullethole.ads.prod=true` so the same
  /// binary source can produce a store build without editing this file.
  static const bool useProductionAds = bool.fromEnvironment(
    'bullethole.ads.prod',
  );

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
  static const String _testAndroidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosInterstitial =
      'ca-app-pub-3940256099942544/4411468910';

  // --- PRODUCTION ids — injected PER-APP at startup via [configure]. ---
  // Each app (Chess, Backgammon, …) is a SEPARATE AdMob app with its OWN ids,
  // so these are NOT hardcoded in the shared kit. They stay as loud placeholders
  // until an app calls [configure] in its main(); combined with [useProductionAds]
  // defaulting to false, no build is ever on real ids by accident.
  static String _prodAndroidAppId = 'REPLACE_WITH_PROD_ANDROID_APP_ID';
  static String _prodIosAppId = 'REPLACE_WITH_PROD_IOS_APP_ID';
  static String _prodAndroidRewarded =
      'REPLACE_WITH_PROD_ANDROID_REWARDED_UNIT_ID';
  static String _prodIosRewarded = 'REPLACE_WITH_PROD_IOS_REWARDED_UNIT_ID';
  static String _prodAndroidInterstitial =
      'REPLACE_WITH_PROD_ANDROID_INTERSTITIAL_UNIT_ID';
  static String _prodIosInterstitial =
      'REPLACE_WITH_PROD_IOS_INTERSTITIAL_UNIT_ID';

  /// Inject THIS app's real AdMob production ids. Call once from the app's
  /// `main()` before any ad loads (e.g. right before `AdsBootstrap…initialize`).
  /// Only the ids you pass are overridden; the rest keep their placeholders.
  ///
  /// The Android/iOS **App ID** must ALSO be set in the native manifest /
  /// Info.plist — the value here is exposed via [appId] for reference/telemetry
  /// and to keep the two in sync. Selection still gates on [useProductionAds]
  /// (`--dart-define=bullethole.ads.prod=true`), so a default build ignores these.
  static void configure({
    String? androidAppId,
    String? iosAppId,
    String? androidInterstitial,
    String? iosInterstitial,
    String? androidRewarded,
    String? iosRewarded,
  }) {
    if (androidAppId != null) _prodAndroidAppId = androidAppId;
    if (iosAppId != null) _prodIosAppId = iosAppId;
    if (androidInterstitial != null) {
      _prodAndroidInterstitial = androidInterstitial;
    }
    if (iosInterstitial != null) _prodIosInterstitial = iosInterstitial;
    if (androidRewarded != null) _prodAndroidRewarded = androidRewarded;
    if (iosRewarded != null) _prodIosRewarded = iosRewarded;
  }

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

  /// Interstitial ad-unit ID for the current platform. Shown full-screen at
  /// natural breaks (e.g. game over -> replay / search match).
  static String get interstitialUnitId {
    if (useProductionAds) {
      return _isIos ? _prodIosInterstitial : _prodAndroidInterstitial;
    }
    return _isIos ? _testIosInterstitial : _testAndroidInterstitial;
  }

  /// True while running on Google's test inventory (i.e. not yet live).
  static bool get usingTestAds => !useProductionAds;
}
