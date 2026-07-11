/// App configuration. Secrets are injected at build/run time, never committed.
///
/// Supply the Gemini key when running or building:
///   flutter run  --dart-define=GEMINI_API_KEY=your_key_here
///   flutter build apk --dart-define=GEMINI_API_KEY=your_key_here
///
/// Without a key the app still works fully offline; only the optional online
/// "AI land analysis" step in the remote check is disabled, and the UI says so.
class Config {
  static const geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;

  /// Vision-capable Gemini model used for satellite land-context analysis.
  static const geminiVisionModel = 'gemini-2.0-flash';
}
