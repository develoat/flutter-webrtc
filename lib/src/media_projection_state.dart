import 'dart:async';

import 'native/event_channel.dart';

class MediaProjectionStoppedEvent {
  const MediaProjectionStoppedEvent({this.trackId});

  factory MediaProjectionStoppedEvent.fromMap(Map<dynamic, dynamic> map) {
    return MediaProjectionStoppedEvent(
      trackId: map['trackId'] as String?,
    );
  }

  final String? trackId;
}

class MediaProjectionStateListener {
  MediaProjectionStateListener._internal() {
    FlutterWebRTCEventChannel.instance.handleEvents.stream.listen((data) {
      final event = data.keys.first as String;
      final map = data.values.first as Map<dynamic, dynamic>;
      handleEvent(event, map);
    });
  }

  static final MediaProjectionStateListener instance =
      MediaProjectionStateListener._internal();

  final StreamController<MediaProjectionStoppedEvent> _onStopped =
      StreamController.broadcast(sync: true);

  Stream<MediaProjectionStoppedEvent> get onStopped => _onStopped.stream;

  void handleEvent(String event, Map<dynamic, dynamic> map) {
    switch (event) {
      case 'onMediaProjectionStopped':
        _onStopped.add(MediaProjectionStoppedEvent.fromMap(map));
        break;
    }
  }
}
