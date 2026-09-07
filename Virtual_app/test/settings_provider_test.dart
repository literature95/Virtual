import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:virtual/services/asr_service.dart';
import 'package:virtual/services/tts_service.dart';
import 'package:virtual/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('settings provider persists ASR and TTS config', () async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);

    settings.setAsrConfig(
      platform: ASRPlatform.openai,
      apiKey: 'asr_key',
      baseUrl: 'https://api.openai.com',
      language: 'en',
    );

    settings.setTtsConfig(
      platform: TTSPlatform.elevenlabs,
      apiKey: 'tts_key',
      baseUrl: 'https://api.elevenlabs.io',
      voiceId: 'voice_123',
      speed: 1.5,
      pitch: 1.2,
    );

    expect(settings.asrPlatform, ASRPlatform.openai);
    expect(settings.asrApiKey, 'asr_key');
    expect(settings.asrBaseUrl, 'https://api.openai.com');
    expect(settings.asrLanguage, 'en');

    expect(settings.ttsPlatform, TTSPlatform.elevenlabs);
    expect(settings.ttsApiKey, 'tts_key');
    expect(settings.ttsBaseUrl, 'https://api.elevenlabs.io');
    expect(settings.ttsVoiceId, 'voice_123');
    expect(settings.ttsSpeed, 1.5);
    expect(settings.ttsPitch, 1.2);

    expect(prefs.getString('asr_platform'), 'openai');
    expect(prefs.getString('asr_api_key'), 'asr_key');
    expect(prefs.getString('tts_platform'), 'elevenlabs');
    expect(prefs.getString('tts_voice_id'), 'voice_123');
  });
}
