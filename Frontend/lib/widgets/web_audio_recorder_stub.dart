import 'dart:async';
import 'dart:typed_data';

class WebAudioRecorder {
  Stream<Uint8List> get onData => Stream.empty();
  Stream<Uint8List> get onStop => Stream.empty();

  Future<bool> hasPermission() async => false;
  Future<void> start() async {}
  Future<void> stop() async {}
  void dispose() {}
}
