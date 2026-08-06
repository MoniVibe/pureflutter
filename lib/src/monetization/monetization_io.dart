import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Real ads/consent implementation for platforms with `dart:io`
/// (Android + iOS run ads for real; desktop compiles but every native call is
/// caught, so it degrades to a silent no-op).
///
/// Design rules enforced here:
///   * Nothing runs at import/construction time — the SDK is only touched from
///     [AdsBootstrap.initialize], which the app calls explicitly.
///   * No method ever throws into the caller — the game loop is never at risk.
///   * Consent (UMP/GDPR) is ALWAYS gathered before any ad is requested.

/// One-call, additive bootstrap for the ads stack.
///
/// Call [instance.initialize] once, after `WidgetsFlutterBinding
/// .ensureInitialized()`. It is safe to fire-and-forget:
///   1. gather UMP consent (GDPR) — always before any ad request,
///   2. only if ads may be requested, initialise the Mobile Ads SDK.
/// On any error it leaves ads uninitialised and the game continues unaffected.
class AdsBootstrap {
  AdsBootstrap._();
  static final AdsBootstrap instance = AdsBootstrap._();

  bool _initialised = false;
  bool get isInitialised => _initialised;

  final ConsentManager _consent = ConsentManager();

  Future<void> initialize() async {
    if (_initialised) return;
    try {
      final canRequestAds = await _consent.gather();
      if (!canRequestAds) return; // Respect the user's / jurisdiction's choice.
      await MobileAds.instance.initialize();
      _initialised = true;
      if (kDebugMode && AdConfig.usingTestAds) {
        debugPrint(
          '[AdsBootstrap] initialised with TEST ad units '
          '(appId=${AdConfig.appId}).',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AdsBootstrap] init skipped: $e');
    }
  }
}

/// GDPR/UMP consent gate wrapping Google's User Messaging Platform.
///
/// [gather] requests a consent-info update, shows the consent form if the
/// jurisdiction requires it, and reports whether ads may now be requested.
/// Every path is defensive and resolves to the SDK's last-known value on error.
class ConsentManager {
  ConsentManager({this.testDeviceIds = const <String>[]});

  /// Optional hashed test-device IDs to force the EEA geography while QA-ing the
  /// consent form. Empty in production.
  final List<String> testDeviceIds;

  Future<bool> gather() async {
    try {
      final params = ConsentRequestParameters(
        consentDebugSettings: testDeviceIds.isEmpty
            ? null
            : ConsentDebugSettings(
                debugGeography: DebugGeography.debugGeographyEea,
                testIdentifiers: testDeviceIds,
              ),
      );
      final completer = Completer<bool>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null && kDebugMode) {
                debugPrint('[ConsentManager] form error: $formError');
              }
            });
          } catch (e) {
            if (kDebugMode) debugPrint('[ConsentManager] form failed: $e');
          }
          if (!completer.isCompleted) completer.complete(await canRequestAds());
        },
        (error) async {
          if (kDebugMode) {
            debugPrint('[ConsentManager] info update failed: $error');
          }
          if (!completer.isCompleted) completer.complete(await canRequestAds());
        },
      );
      return completer.future;
    } catch (e) {
      if (kDebugMode) debugPrint('[ConsentManager] gather failed: $e');
      return canRequestAds();
    }
  }

  Future<bool> canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      return false;
    }
  }

  /// Reset stored consent — wire this to a "Privacy settings" button so users
  /// can re-open the consent form (a store requirement in some jurisdictions).
  Future<void> reset() async {
    try {
      await ConsentInformation.instance.reset();
    } catch (_) {}
  }
}

/// Thin, defensive wrapper around a single rewarded-ad slot.
///
/// Keeps one ad warm, exposes [isReady], grants the reward via [onReward], and
/// auto-reloads after a show. Load failures back off exponentially (capped) so
/// a dead network never hammers the ad server. [showIfAvailable] never blocks
/// the game loop: with nothing loaded it returns false immediately.
class RewardedAdService {
  RewardedAdService({this.onReward});

  /// Invoked when the user earns the reward.
  final void Function(AdReward reward)? onReward;

  RewardedAd? _ad;
  bool _isLoading = false;
  int _retryAttempt = 0;
  bool _disposed = false;

  static const int _maxRetryAttempts = 5;

  bool get isReady => _ad != null;

  /// Preload a rewarded ad. Safe to call repeatedly; no-ops while one is already
  /// loaded or loading. Requires [AdsBootstrap.initialize] to have run first.
  Future<void> load() async {
    if (_disposed || _ad != null || _isLoading) return;
    _isLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: AdConfig.rewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (_disposed) {
              ad.dispose();
              return;
            }
            _ad = ad;
            _isLoading = false;
            _retryAttempt = 0;
            _wireFullScreenCallbacks(ad);
          },
          onAdFailedToLoad: (error) {
            _ad = null;
            _isLoading = false;
            if (kDebugMode) {
              debugPrint('[RewardedAdService] load failed: $error');
            }
            _scheduleRetry();
          },
        ),
      );
    } catch (e) {
      _isLoading = false;
      if (kDebugMode) debugPrint('[RewardedAdService] load threw: $e');
      _scheduleRetry();
    }
  }

  void _wireFullScreenCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        load(); // Keep one warm for next time.
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        load();
      },
    );
  }

  void _scheduleRetry() {
    if (_disposed || _retryAttempt >= _maxRetryAttempts) return;
    _retryAttempt++;
    final delaySeconds = 1 << _retryAttempt; // 2, 4, 8, 16, 32
    Timer(Duration(seconds: delaySeconds), () {
      if (!_disposed) load();
    });
  }

  /// Show the ad if one is ready. Returns true if an ad was shown. When nothing
  /// is loaded, [onUnavailable] lets the caller fall back gracefully (grant the
  /// reward anyway, show a "try later" toast, etc.).
  Future<bool> showIfAvailable({VoidCallback? onUnavailable}) async {
    final ad = _ad;
    if (ad == null) {
      onUnavailable?.call();
      load(); // Opportunistically start a load for next time.
      return false;
    }
    _ad = null; // Consumed.
    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          onReward?.call(AdReward(reward.amount, reward.type));
        },
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[RewardedAdService] show threw: $e');
      onUnavailable?.call();
      load();
      return false;
    }
  }

  void dispose() {
    _disposed = true;
    _ad?.dispose();
    _ad = null;
  }
}
