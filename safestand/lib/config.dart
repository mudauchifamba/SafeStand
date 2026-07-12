/// App configuration. Secrets are injected at build/run time, never committed.
///
/// Supply the Groq key when running or building:
///   flutter run  --dart-define=GROQ_API_KEY=your_key_here
///   flutter build apk --dart-define=GROQ_API_KEY=your_key_here
///
/// Without a key the app still works fully offline; only the optional online
/// "AI land analysis" step in the remote check is disabled, and the UI says so.
class Config {
  static const groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  static bool get hasGroqKey => groqApiKey.isNotEmpty;

  /// Vision-capable Groq model used for satellite land-context analysis.
  static const groqVisionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';
}
