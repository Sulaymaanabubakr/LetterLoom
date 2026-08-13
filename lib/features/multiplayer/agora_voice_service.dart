import 'dart:async';
import 'package:flutter/foundation.dart';
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
  int? _localUid;
  Timer? _renewalTimer;
  Timer? _speakerExpiryTimer;
  final Map<int, DateTime> _activeUntil = {};
  final StreamController<double> _localVolume =
      StreamController<double>.broadcast();

  bool get isJoined => _joined;
  bool get isMuted => _muted;
  final StreamController<Set<int>> _speakers =
      StreamController<Set<int>>.broadcast();
  Stream<Set<int>> get activeSpeakers => _speakers.stream;
  Stream<double> get localVolume => _localVolume.stream;

  Future<bool> join({
    required String gameId,
    required AgoraVoiceCredentials credentials,
  }) async {
    if (_joined && _gameId == gameId && _channel == credentials.channel) {
      return true;
    }
    await leave();
    try {
      final engine = createAgoraRtcEngine();
      _engine = engine;
      _gameId = gameId;
      _channel = credentials.channel;
      _localUid = credentials.uid;
      await engine.initialize(RtcEngineContext(appId: credentials.appId));
      await engine.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onAudioVolumeIndication: (_, speakers, _, _) {
            final local = speakers.where(
              (item) => item.uid == 0 || item.uid == _localUid,
            );
            if (local.isNotEmpty) {
              final volume = (local.first.volume ?? 0) / 255.0;
              _localVolume.add(volume.clamp(0.0, 1.0));
            }
            final active = speakers
                .where(
                  (item) =>
                      item.uid != null &&
                      ((item.vad ?? 0) == 1 || (item.volume ?? 0) >= 10),
                )
                .map((item) => item.uid == 0 ? _localUid : item.uid)
                .whereType<int>()
                .toSet();
            _markSpeakers(active);
          },
          onActiveSpeaker: (_, uid) {
            _markSpeakers({uid == 0 ? (_localUid ?? 0) : uid});
          },
          onTokenPrivilegeWillExpire: (_, _) => unawaited(_renewToken()),
          onRequestToken: (_) => unawaited(_renewToken()),
        ),
      );
      await engine.enableAudio();
      await engine.muteLocalAudioStream(true);
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
      // Register volume/VAD reporting after joining so Agora has an active
      // channel connection before it starts reporting local and remote audio.
      await engine.enableAudioVolumeIndication(
        interval: 200,
        smooth: 3,
        reportVad: true,
      );
      _joined = true;
      _scheduleRenewal(credentials.expiresAt);
      return true;
    } catch (error, stackTrace) {
      debugPrint('[Agora] Voice join failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await leave();
      return false;
    }
  }

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (muted) _localVolume.add(0);
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
    _speakerExpiryTimer?.cancel();
    _speakerExpiryTimer = null;
    _activeUntil.clear();
    _speakers.add(const {});
    _localVolume.add(0);
    final engine = _engine;
    _engine = null;
    _joined = false;
    _localUid = null;
    if (engine == null) return;
    try {
      await engine.leaveChannel();
      await engine.release();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await leave();
    await _speakers.close();
    await _localVolume.close();
  }

  void _markSpeakers(Set<int> speakers) {
    final until = DateTime.now().add(const Duration(milliseconds: 550));
    for (final uid in speakers) {
      if (uid != 0) _activeUntil[uid] = until;
    }
    _publishActiveSpeakers();
    _speakerExpiryTimer ??= Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _publishActiveSpeakers(),
    );
  }

  void _publishActiveSpeakers() {
    final now = DateTime.now();
    _activeUntil.removeWhere((_, expiry) => expiry.isBefore(now));
    _speakers.add(_activeUntil.keys.toSet());
    if (_activeUntil.isEmpty) {
      _speakerExpiryTimer?.cancel();
      _speakerExpiryTimer = null;
    }
  }
}
