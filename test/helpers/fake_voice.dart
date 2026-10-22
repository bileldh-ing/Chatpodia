import 'dart:async';

import 'package:chatpodia/services/voice_recognizer.dart';

/// Emits a scripted transcript word-by-word with a synthetic mic level.
class FakeVoiceRecognizer implements VoiceRecognizer {
  FakeVoiceRecognizer({this.script = 'Hi, play my favorite playlist to accompany me while studying my assignments.'});
  final String script;
  void Function(bool)? _onListening;
  Timer? _t;

  @override
  Future<bool> initialize({required void Function(bool) onListening, required void Function(String) onError}) async {
    _onListening = onListening;
    return true;
  }

  @override
  Future<void> listen({required void Function(String, bool) onResult, required void Function(double) onLevel}) async {
    _onListening?.call(true);
    final words = script.split(' ');
    var i = 0;
    _t = Timer.periodic(const Duration(milliseconds: 260), (t) {
      i++;
      onLevel(0.35 + (i % 3) * 0.25);
      final done = i >= words.length;
      onResult(words.take(i).join(' '), done);
      if (done) {
        t.cancel();
        _onListening?.call(false);
        onLevel(0);
      }
    });
  }

  @override
  Future<void> stop() async => _t?.cancel();

  @override
  Future<void> cancel() async => _t?.cancel();
}
