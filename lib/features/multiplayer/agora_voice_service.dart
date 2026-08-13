import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'multiplayer_repository.dart';

/// Best-effort voice session for a single multiplayer match. The game never
/// depends on this service being configured or reachable.
class AgoraVoiceService {
  RtcEngine? _engine;
  String? _gameId;
  String? _channel;
  bool _joined = false;
  bool _muted = true;
  Timer? _renewalTimer;

  bool get isJoined => _joined;
  bool get isMuted => _muted;
  final StreamController<Set<int>> _speakers =
      StreamController<Set<int>>.broadcast();
  Stream<Set<int>> get activeSpeakers => _speakers.stream;

  Future<bool> join({
    required String gameId,
    required AgoraVoiceCredentials credentials,
  }) async {
    if (_joined && _gameId == gameId && _channel == credentials.channel)
      return true;
    await leave();
    try {
      final engine = createAgoraRtcEngine();
      _engine = engine;
      _gameId = gameId;
      _channel = credentials.channel;
      await engine.initialize(RtcEngineContext(appId: credentials.appId));
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onAudioVolumeIndication: (_, speakers, _, _) {
            _speakers.add(
              speakers
                  .where((item) => item.uid != null && (item.volume ?? 0) > 3)
                  .map((item) => item.uid!)
                  .toSet(),
            );
          },
          onTokenPrivilegeWillExpire: (_, _) => unawaited(_renewToken()),
          onRequestToken: (_) => unawaited(_renewToken()),
        ),
      );
      await engine.enableAudio();
      await engine.muteLocalAudioStream(true);
      await engine.enableAudioVolumeIndication(
        interval: 200,
        smooth: 3,
        reportVad: true,
      );
      await engine.joinChannel(
        token: credentials.token,
        channelId: credentials.channel,
        uid: credentials.uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ),
      );
      _joined = true;
      _scheduleRenewal(credentials.expiresAt);
      return true;
    } catch (_) {
      await leave();
      return false;
    }
  }

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    try {
      await _engine?.muteLocalAudioStream(muted);
    } catch (_) {}
  }

  Future<void> _renewToken() async {
    final id = _gameId;
    if (id == null || !_joined) return;
    try {
      final credentials = await MultiplayerRepository().requestVoiceToken(id);
      await _engine?.renewToken(credentials.token);
      _scheduleRenewal(credentials.expiresAt);
    } catch (_) {}
  }

  void _scheduleRenewal(DateTime expiresAt) {
    _renewalTimer?.cancel();
    final delay =
        expiresAt.difference(DateTime.now()) - const Duration(minutes: 2);
    _renewalTimer = Timer(
      delay.isNegative ? const Duration(seconds: 10) : delay,
      _renewToken,
    );
  }

  Future<void> leave() async {
    _renewalTimer?.cancel();
    final engine = _engine;
    _engine = null;
    _joined = false;
    if (engine == null) return;
    try {
      await engine.leaveChannel();
      await engine.release();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await leave();
    await _speakers.close();
  }
}
