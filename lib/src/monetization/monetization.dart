/// Public entry point for the ads/consent kit.
///
/// This facade picks the real, `google_mobile_ads`-backed implementation on
/// platforms with `dart:io` (Android, iOS, desktop) and a no-op stub on the web
/// (where `google_mobile_ads` does not exist). Consumers only ever import this
/// file — the switch is invisible and keeps `flutter build web` compiling.
///
/// On desktop the real impl compiles but every native call is caught and
/// swallowed, so it behaves like the stub at runtime. Ads only truly run on
/// Android/iOS.
export 'monetization_stub.dart'
    if (dart.library.io) 'monetization_io.dart';
