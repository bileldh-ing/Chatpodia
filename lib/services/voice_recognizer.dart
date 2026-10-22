import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text behind an interface so voice mode is testable / demoable.
abstract class VoiceRecognizer {
  Future<bool> initialize(
      {required void Function(bool listening) onListening, required void Function(String error) onError});

  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function(double level01) onLevel,
  });

  Future<void> stop();
  Future<void> cancel();
}

class DeviceVoiceRecognizer implements VoiceRecognizer {
  final _stt = SpeechToText();

  @override
  Future<bool> initialize({required void Function(bool) onListening, required void Function(String) onError}) async {
    try {
      return await _stt.initialize(
        onStatus: (s) => onListening(s == 'listening'),
        onError: (e) => onError(e.errorMsg),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> listen({required void Function(String, bool) onResult, required void Function(double) onLevel}) {
    return _stt.listen(
      onResult: (SpeechRecognitionResult r) => onResult(r.recognizedWords, r.finalResult),
      // Android reports roughly -2..10 dB.
      onSoundLevelChange: (l) => onLevel(((l + 2) / 12).clamp(0.0, 1.0)),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() => _stt.cancel();
}
