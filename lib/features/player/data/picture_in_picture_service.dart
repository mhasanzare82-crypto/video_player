import 'package:flutter/services.dart';

class PictureInPictureService {
  static const MethodChannel _channel = MethodChannel('video_player/pip');

  Future<bool> enter() async {
    final result = await _channel.invokeMethod<bool>('enterPip');
    return result ?? false;
  }
}
