import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

enum TTSPlatform { elevenlabs, openai, googleGemini, minimax, flutterTts }

class TTSConfig {
  final TTSPlatform platform;
  final String apiKey;
  final String baseUrl;
  final String? model;
  final String? voiceId;
  final double speed;
  final double pitch;

  const TTSConfig({
    required this.platform,
    required this.apiKey,
    required this.baseUrl,
    this.model,
    this.voiceId,
    this.speed = 1.0,
    this.pitch = 1.0,
  });
}

class TTSService {
  final Dio _dio;
  FlutterSoundPlayer? _player;
  bool _playerInitialized = false;

  TTSService(this._dio);

  Future<void> _ensurePlayerInitialized() async {
    if (_playerInitialized) return;
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
    _playerInitialized = true;
  }

  /// Speak text using configured TTS platform
  Future<void> speak(String text, TTSConfig config) async {
    switch (config.platform) {
      case TTSPlatform.elevenlabs:
        await _speakElevenLabs(text, config);
        break;
      case TTSPlatform.openai:
        await _speakOpenAI(text, config);
        break;
      case TTSPlatform.googleGemini:
        await _speakGemini(text, config);
        break;
      case TTSPlatform.minimax:
        await _speakMiniMax(text, config);
        break;
      case TTSPlatform.flutterTts:
        await _speakFlutterTts(text, config);
        break;
    }
  }

  Future<void> _speakElevenLabs(String text, TTSConfig config) async {
    final voiceId = config.voiceId ?? '21m00Tcm4TlvDq8ikWAM';
    final response = await _dio.post(
      '${config.baseUrl}/v1/text-to-speech/$voiceId',
      data: {
        'text': text,
        'model_id': config.model ?? 'eleven_multilingual_v2',
        'voice_settings': {
          'stability': 0.5,
          'similarity_boost': 0.75,
          'speed': config.speed,
        },
      },
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'xi-api-key': config.apiKey},
      ),
    );
    await _playAudioBytes(response.data);
  }

  Future<void> _speakOpenAI(String text, TTSConfig config) async {
    final voice = config.voiceId ?? 'alloy';
    final response = await _dio.post(
      '${config.baseUrl}/v1/audio/speech',
      data: {
        'model': config.model ?? 'tts-1',
        'input': text,
        'voice': voice,
        'speed': config.speed,
      },
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      ),
    );
    await _playAudioBytes(response.data);
  }

  Future<void> _speakGemini(String text, TTSConfig config) async {
    final model = config.model ?? 'gemini-2.5-flash-preview-tts';
    final response = await _dio.post(
      '${config.baseUrl}/v1beta/models/$model:generateContent',
      data: {
        'contents': [{'parts': [{'text': text}]}],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': config.voiceId ?? 'Kore',
              }
            }
          }
        }
      },
      options: Options(
        headers: {'x-goog-api-key': config.apiKey},
      ),
    );
    final candidates = response.data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final parts = candidates[0]['content']['parts'] as List?;
      if (parts != null) {
        for (final part in parts) {
          if (part['inlineData'] != null) {
            final audioData = part['inlineData']['data'];
            await _playAudioBase64(audioData);
          }
        }
      }
    }
  }

  Future<void> _speakMiniMax(String text, TTSConfig config) async {
    final response = await _dio.post(
      '${config.baseUrl}/v1/t2a_v2',
      data: {
        'model': config.model ?? 'speech-01',
        'text': text,
        'voice_setting': {
          'voice_id': config.voiceId ?? 'male-qn-qingse',
          'speed': config.speed,
          'pitch': config.pitch,
        },
      },
      options: Options(
        headers: {'Authorization': 'Bearer ${config.apiKey}'},
      ),
    );
    final audio = response.data['data']?['audio'];
    if (audio != null) {
      await _playAudioBase64(audio);
    }
  }

  Future<void> _speakFlutterTts(String text, TTSConfig config) async {
    // Fallback to system TTS via flutter_tts package
    // For now, use system TTS as default
  }

  Future<void> _playAudioBytes(List<int> bytes) async {
    await _ensurePlayerInitialized();
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/tts_audio.mp3');
    await tempFile.writeAsBytes(bytes);
    await _player!.startPlayer(
      fromURI: tempFile.path,
      codec: Codec.mp3,
    );
  }

  Future<void> _playAudioBase64(String base64Data) async {
    final bytes = base64Decode(base64Data);
    await _playAudioBytes(bytes);
  }

  Future<void> stop() async {
    if (_player != null && _player!.isPlaying) {
      await _player!.stopPlayer();
    }
  }

  bool get isPlaying => _player?.isPlaying ?? false;

  /// Get available voices for a platform
  Future<List<Map<String, String>>> getVoices(TTSPlatform platform, String apiKey, String baseUrl) async {
    switch (platform) {
      case TTSPlatform.elevenlabs:
        return _getElevenLabsVoices(apiKey, baseUrl);
      case TTSPlatform.openai:
        return _getOpenAIVoices();
      default:
        return [];
    }
  }

  Future<List<Map<String, String>>> _getElevenLabsVoices(String apiKey, String baseUrl) async {
    final response = await _dio.get(
      '$baseUrl/v1/voices',
      options: Options(headers: {'xi-api-key': apiKey}),
    );
    final voices = response.data['voices'] as List;
    return voices.map((v) => {
      'id': v['voice_id'] as String,
      'name': v['name'] as String,
    }).toList();
  }

  List<Map<String, String>> _getOpenAIVoices() {
    return [
      {'id': 'alloy', 'name': 'Alloy'},
      {'id': 'echo', 'name': 'Echo'},
      {'id': 'fable', 'name': 'Fable'},
      {'id': 'onyx', 'name': 'Onyx'},
      {'id': 'nova', 'name': 'Nova'},
      {'id': 'shimmer', 'name': 'Shimmer'},
    ];
  }

  Future<void> dispose() async {
    if (_player != null) {
      await _player!.closePlayer();
      _player = null;
      _playerInitialized = false;
    }
  }
}