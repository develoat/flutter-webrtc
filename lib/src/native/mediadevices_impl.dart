import 'dart:async';

import 'package:flutter/services.dart';

import 'package:webrtc_interface/webrtc_interface.dart';

import 'event_channel.dart';
import 'media_stream_impl.dart';
import 'utils.dart';

class MediaDeviceNative extends MediaDevices {
  MediaDeviceNative._internal() {
    FlutterWebRTCEventChannel.instance.handleEvents.stream.listen((data) {
      var event = data.keys.first;
      Map<dynamic, dynamic> map = data.values.first;
      handleEvent(event, map);
    });
  }

  static final MediaDeviceNative instance = MediaDeviceNative._internal();

  final StreamController<String> logger =
    StreamController.broadcast();

  final StreamController<AndroidAudioFocusType?> onAudioFocusChange =
      StreamController.broadcast();

  void handleEvent(String event, final Map<dynamic, dynamic> map) async {
    switch (map['event']) {
      case 'onDeviceChange':
        ondevicechange?.call(null);
        break;
      case 'onAudioFocusChange':
        onAudioFocusChange.add(getFocusType(map['value']));
        break;
      case 'onLogger':
        logger.add(map['value']);
        break;
    }
  }

  @override
  Future<MediaStream> getUserMedia(
      Map<String, dynamic> mediaConstraints) async {
    try {
      final response = await WebRTC.invokeMethod(
        'getUserMedia',
        <String, dynamic>{'constraints': mediaConstraints},
      );
      if (response == null) {
        throw Exception('getUserMedia return null, something wrong');
      }

      String streamId = response['streamId'];
      var stream = MediaStreamNative(streamId, 'local');
      stream.setMediaTracks(
          response['audioTracks'] ?? [], response['videoTracks'] ?? []);
      return stream;
    } on PlatformException catch (e) {
      throw 'Unable to getUserMedia: ${e.message}';
    }
  }

  @override
  Future<MediaStream> getDisplayMedia(
      Map<String, dynamic> mediaConstraints) async {
    try {
      final response = await WebRTC.invokeMethod(
        'getDisplayMedia',
        <String, dynamic>{'constraints': mediaConstraints},
      );
      if (response == null) {
        throw Exception('getDisplayMedia return null, something wrong');
      }
      String streamId = response['streamId'];
      var stream = MediaStreamNative(streamId, 'local');
      stream.setMediaTracks(response['audioTracks'], response['videoTracks']);
      return stream;
    } on PlatformException catch (e) {
      throw 'Unable to getDisplayMedia: ${e.message}';
    }
  }

  @override
  Future<List<dynamic>> getSources() async {
    try {
      final response = await WebRTC.invokeMethod(
        'getSources',
        <String, dynamic>{},
      );

      List<dynamic> sources = response['sources'];

      return sources;
    } on PlatformException catch (e) {
      throw 'Unable to getSources: ${e.message}';
    }
  }

  @override
  Future<List<MediaDeviceInfo>> enumerateDevices() async {
    var source = await getSources();
    return source
        .map(
          (e) => MediaDeviceInfo(
              deviceId: e['deviceId'],
              groupId: e['groupId'],
              kind: e['kind'],
              label: e['label']),
        )
        .toList();
  }

  @override
  Future<MediaDeviceInfo> selectAudioOutput(
      [AudioOutputOptions? options]) async {
    await WebRTC.invokeMethod('selectAudioOutput', {
      'deviceId': options?.deviceId,
    });
    // TODO(cloudwebrtc): return the selected device
    return MediaDeviceInfo(label: 'label', deviceId: options!.deviceId);
  }

  AndroidAudioFocusType? getFocusType(String? value){
    if(value != null){
      switch(int.tryParse(value)){
        case 1:
          return AndroidAudioFocusType.AUDIOFOCUS_GAIN;
        case 2:
          return AndroidAudioFocusType.AUDIOFOCUS_GAIN_TRANSIENT;
        case 3:
          return AndroidAudioFocusType.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK;
        case -1:
          return AndroidAudioFocusType.AUDIOFOCUS_LOSS;
        case -2:
          return AndroidAudioFocusType.AUDIOFOCUS_LOSS_TRANSIENT;
        case -3:
          return AndroidAudioFocusType.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK;
        default:
          return null;
      }
    }
    return null;
  }
}
