import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class WebAudioRecorder {
  html.MediaRecorder? _mediaRecorder;
  html.MediaStream? _stream;
  final List<html.Blob> _chunks = [];
  final _onDataController = StreamController<Uint8List>.broadcast();
  final _onStopController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get onData => _onDataController.stream;
  Stream<Uint8List> get onStop => _onStopController.stream;

  Future<bool> hasPermission() async {
    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
      if (stream != null) {
        stream.getTracks().forEach((track) => track.stop());
        return true;
      }
      return false;
    } catch (e) {
      print('[WebAudioRecorder] 权限检查失败: $e');
      return false;
    }
  }

  Future<void> start() async {
    print('[WebAudioRecorder] 开始录音');

    try {
      _stream = await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});

      if (_stream == null) {
        throw Exception('无法获取音频流');
      }

      // 尝试使用 webm 格式，如果不支持则使用默认格式
      String mimeType = 'audio/webm;codecs=opus';
      if (!html.MediaRecorder.isTypeSupported(mimeType)) {
        mimeType = 'audio/webm';
        if (!html.MediaRecorder.isTypeSupported(mimeType)) {
          mimeType = ''; // 使用默认格式
        }
      }

      print('[WebAudioRecorder] 使用格式: $mimeType');

      _mediaRecorder = html.MediaRecorder(_stream!, {'mimeType': mimeType});
      _chunks.clear();

      _mediaRecorder!.addEventListener('dataavailable', (event) {
        final blob = (event as html.BlobEvent).data;
        if (blob != null && blob.size > 0) {
          print('[WebAudioRecorder] 数据块大小: ${blob.size}');
          _chunks.add(blob);
        }
      });

      _mediaRecorder!.addEventListener('stop', (event) async {
        print('[WebAudioRecorder] 录音停止，块数: ${_chunks.length}');
        if (_chunks.isNotEmpty) {
          final blob = html.Blob(_chunks, mimeType.isNotEmpty ? mimeType : 'audio/webm');
          final reader = html.FileReader();
          reader.readAsArrayBuffer(blob);
          await reader.onLoad.first;
          final data = reader.result as Uint8List;
          print('[WebAudioRecorder] 最终数据大小: ${data.length}');
          _onStopController.add(data);
        }
      });

      _mediaRecorder!.start();
      print('[WebAudioRecorder] MediaRecorder 已启动');
    } catch (e) {
      print('[WebAudioRecorder] 启动失败: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    print('[WebAudioRecorder] 停止录音');

    if (_mediaRecorder != null && _mediaRecorder!.state != 'inactive') {
      _mediaRecorder!.stop();
    }

    _stream?.getTracks().forEach((track) => track.stop());
    _stream = null;
  }

  void dispose() {
    _mediaRecorder = null;
    _stream?.getTracks().forEach((track) => track.stop());
    _stream = null;
    _onDataController.close();
    _onStopController.close();
  }
}
