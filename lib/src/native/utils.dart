import 'dart:io';

import 'package:flutter/services.dart';

class WebRTC {
  static const MethodChannel _channel = MethodChannel('FlutterWebRTC.Method');

  static bool get platformIsDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static bool get platformIsWindows => Platform.isWindows;

  static bool get platformIsMacOS => Platform.isMacOS;

  static bool get platformIsLinux => Platform.isLinux;

  static bool get platformIsMobile => Platform.isIOS || Platform.isAndroid;

  static bool get platformIsIOS => Platform.isIOS;

  static bool get platformIsAndroid => Platform.isAndroid;

  static bool get platformIsWeb => false;

  static Future<T?> invokeMethod<T, P>(String methodName,
          [dynamic param]) async =>
      _channel.invokeMethod<T>(
        methodName,
        param,
      );
}

enum AndroidAudioFocusType {
  AUDIOFOCUS_GAIN, //有効
  AUDIOFOCUS_GAIN_TRANSIENT, //一時有効
  AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK, //有効・ダッキング可能
  AUDIOFOCUS_LOSS, //無効
  AUDIOFOCUS_LOSS_TRANSIENT, //一時無効
  AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK, //無効・ダッキング可能
}