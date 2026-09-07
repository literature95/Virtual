import 'package:speech_to_text/speech_to_text.dart' as stt;

enum ASRPlatform { openai, google, plugin, system }

class ASRConfig {
  final ASRPlatform platform;
  final String? apiKey;
  final String? baseUrl;
  final String? language;

  const ASRConfig({
    required this.platform,
    this.apiKey,
    this.baseUrl,
    this.language = 'zh',
  });
}

class ASRService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onStatus: (status) {},
      onError: (error) {},
    );
    return _initialized;
  }

  /// Start listening for speech
  Future<void> startListening({
    required void Function(String text) onResult,
    required void Function() onEnd,
    ASRConfig? config,
  }) async {
    if (config?.platform == ASRPlatform.system || config == null) {
      await _startSystemRecognition(onResult, onEnd);
    } else {
      await _startCloudRecognition(onResult, onEnd, config);
    }
  }

  Future<void> _startSystemRecognition(
    void Function(String) onResult,
    void Function() onEnd,
  ) async {
    await initialize();
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          onEnd();
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _startCloudRecognition(
    void Function(String) onResult,
    void Function() onEnd,
    ASRConfig config,
  ) async {
    await initialize();
    await _speech.listen(
      onResult: (result) async {
        if (result.finalResult) {
          final text = await _sendToCloudASR(result.recognizedWords, config);
          onResult(text);
          onEnd();
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<String> _sendToCloudASR(String text, ASRConfig config) async {
    // For now, return the system recognition result
    // Full implementation would record audio and send to API
    return text;
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  Future<void> dispose() async {
    await _speech.cancel();
  }

  bool get isListening => _speech.isListening;
}
