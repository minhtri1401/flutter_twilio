import '../generated/voice_api.g.dart' hide AudioRoute;
import 'audio_route.dart';

class ActiveCall {
  const ActiveCall({
    required this.sid,
    required this.from,
    required this.to,
    required this.direction,
    required this.startedAt,
    required this.isMuted,
    required this.isOnHold,
    required this.isOnSpeaker,
    required this.currentRoute,
    this.connectedAt,
    this.customParameters = const {},
  });

  final String sid;
  final String from;
  final String to;
  final CallDirection direction;

  /// When the call was *initiated* (outgoing: `place()` returned a SID;
  /// incoming: `CallInvite` received). Always non-null. Native-sourced.
  final DateTime startedAt;

  /// When the media path actually connected — first byte of audio flowing.
  /// `null` for missed / rejected / failed-before-connect calls. Use
  /// `now() - connectedAt` for an accurate call-duration ticker.
  final DateTime? connectedAt;

  final bool isMuted;
  final bool isOnHold;

  /// Convenience flag mirroring `currentRoute == AudioRoute.speaker`.
  /// Retained for the deprecation cycle alongside `setSpeaker(bool)`.
  final bool isOnSpeaker;

  /// Active output route at the moment this snapshot was created.
  final AudioRoute currentRoute;

  final Map<String, String> customParameters;

  factory ActiveCall.fromDto(ActiveCallDto dto) => ActiveCall(
        sid: dto.sid,
        from: dto.from,
        to: dto.to,
        direction: dto.direction,
        startedAt: DateTime.fromMillisecondsSinceEpoch(dto.startedAt),
        connectedAt: dto.connectedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(dto.connectedAt!),
        isMuted: dto.isMuted,
        isOnHold: dto.isOnHold,
        isOnSpeaker: dto.isOnSpeaker,
        currentRoute: AudioRoute.fromPigeon(dto.currentRoute),
        customParameters: {
          for (final e in (dto.customParameters ?? const {}).entries)
            if (e.key != null && e.value != null) e.key!: e.value!,
        },
      );
}
