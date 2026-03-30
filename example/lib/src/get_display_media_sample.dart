import 'dart:async';
import 'dart:core';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_webrtc_example/src/widgets/screen_select_dialog.dart';

/*
 * getDisplayMedia sample
 */
class GetDisplayMediaSample extends StatefulWidget {
  static String tag = 'get_display_media_sample';

  @override
  _GetDisplayMediaSampleState createState() => _GetDisplayMediaSampleState();
}

class _GetDisplayMediaSampleState extends State<GetDisplayMediaSample>
    with WidgetsBindingObserver {
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  bool _wantsScreenShare = false;
  bool _needsScreenShareRestart = false;
  bool _isRestartingScreenShare = false;
  DesktopCapturerSource? selected_source_;
  StreamSubscription<MediaProjectionStoppedEvent>? _projectionStoppedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initRenderers();
    _projectionStoppedSub =
        MediaProjectionStateListener.instance.onStopped.listen(
      _handleProjectionStopped,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _projectionStoppedSub?.cancel();
    _wantsScreenShare = false;
    _needsScreenShareRestart = false;
    _disposeLocalStream();
    _localRenderer.srcObject = null;
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      restartScreenShareIfNeeded();
    }
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
  }

  Future<void> selectScreenSourceDialog(BuildContext context) async {
    if (WebRTC.platformIsDesktop) {
      final source = await showDialog<DesktopCapturerSource>(
        context: context,
        builder: (context) => ScreenSelectDialog(),
      );
      if (source != null) {
        await _makeCall(source);
      }
    } else {
      if (WebRTC.platformIsAndroid) {
        Future<void> requestBackgroundPermission([bool isRetry = false]) async {
          try {
            var hasPermissions = await FlutterBackground.hasPermissions;
            if (!isRetry) {
              const androidConfig = FlutterBackgroundAndroidConfig(
                notificationTitle: 'Screen Sharing',
                notificationText: 'LiveKit Example is sharing the screen.',
                notificationImportance: AndroidNotificationImportance.normal,
                notificationIcon: AndroidResource(
                    name: 'livekit_ic_launcher', defType: 'mipmap'),
              );
              hasPermissions = await FlutterBackground.initialize(
                  androidConfig: androidConfig);
            }
            if (hasPermissions &&
                !FlutterBackground.isBackgroundExecutionEnabled) {
              await FlutterBackground.enableBackgroundExecution();
            }
          } catch (e) {
            if (!isRetry) {
              return Future<void>.delayed(const Duration(seconds: 1), () {
                return requestBackgroundPermission(true);
              });
            }
            print('could not publish video: $e');
          }
        }

        await requestBackgroundPermission();
      }
      await _makeCall(null);
    }
  }

  Future<void> _makeCall(DesktopCapturerSource? source) async {
    _wantsScreenShare = true;
    final stream = await _getDisplayMediaStream(source);
    if (stream == null) {
      _wantsScreenShare = false;
      return;
    }

    await _setLocalStream(stream);
    if (!mounted) return;

    setState(() {
      _inCalling = true;
      _needsScreenShareRestart = false;
    });
  }

  Future<void> _stop() async {
    try {
      await _disposeLocalStream();
      _localRenderer.srcObject = null;
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _disposeLocalStream() async {
    final localStream = _localStream;
    _localStream = null;
    if (localStream == null) {
      return;
    }

    if (kIsWeb) {
      localStream.getTracks().forEach((track) => track.stop());
    }
    await localStream.dispose();
  }

  Future<MediaStream?> _getDisplayMediaStream(
      DesktopCapturerSource? source) async {
    setState(() {
      selected_source_ = source;
    });

    try {
      final stream =
          await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
        'video': selected_source_ == null
            ? true
            : {
                'deviceId': {'exact': selected_source_!.id},
                'mandatory': {'frameRate': 30.0}
              }
      });
      stream.getVideoTracks()[0].onEnded = () {
        print(
            'By adding a listener on onEnded you can: 1) catch stop video sharing on Web');
      };
      return stream;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<void> _setLocalStream(MediaStream stream) async {
    try {
      await _disposeLocalStream();
      _localStream = stream;
      _localRenderer.srcObject = _localStream;
    } catch (e) {
      print(e.toString());
      await stream.dispose();
      rethrow;
    }
  }

  Future<void> _handleProjectionStopped(
      MediaProjectionStoppedEvent event) async {
    if (!mounted || !_wantsScreenShare || !WebRTC.platformIsAndroid) {
      return;
    }

    final videoTracks = _localStream?.getVideoTracks();
    if (event.trackId != null &&
        videoTracks != null &&
        videoTracks.isNotEmpty &&
        videoTracks.first.id != event.trackId) {
      return;
    }

    await _stop();
    if (!mounted) return;

    setState(() {
      _inCalling = false;
      _needsScreenShareRestart = true;
    });
  }

  Future<void> restartScreenShareIfNeeded() async {
    if (!WebRTC.platformIsAndroid ||
        !_wantsScreenShare ||
        !_needsScreenShareRestart ||
        _isRestartingScreenShare) {
      return;
    }

    _isRestartingScreenShare = true;
    try {
      final stream = await _getDisplayMediaStream(selected_source_);
      if (stream == null) {
        return;
      }

      await _setLocalStream(stream);
      if (!mounted) return;

      setState(() {
        _inCalling = true;
        _needsScreenShareRestart = false;
      });
    } catch (e) {
      print(e.toString());
    } finally {
      _isRestartingScreenShare = false;
    }
  }

  Future<void> _hangUp() async {
    _wantsScreenShare = false;
    _needsScreenShareRestart = false;
    await _stop();
    if (!mounted) return;

    setState(() {
      _inCalling = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GetDisplayMedia source: ' +
            (selected_source_ != null ? selected_source_!.name : '')),
        actions: [],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Center(
              child: Container(
            width: MediaQuery.of(context).size.width,
            color: Colors.white10,
            child: Stack(children: <Widget>[
              if (_inCalling)
                Container(
                  margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  decoration: BoxDecoration(color: Colors.black54),
                  child: RTCVideoView(_localRenderer),
                )
            ]),
          ));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _inCalling ? _hangUp() : selectScreenSourceDialog(context);
        },
        tooltip: _inCalling ? 'Hangup' : 'Call',
        child: Icon(_inCalling ? Icons.call_end : Icons.phone),
      ),
    );
  }
}
