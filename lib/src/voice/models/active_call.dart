import '../generated/voice_api.g.dart';

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
    this.customParameters = const {},
  });

  final String sid;
  final String from;
  final String to;
  final CallDirection direction;
  final DateTime startedAt;
  final bool isMuted;
  final bool isOnHold;
  final bool isOnSpeaker;
  final Map<String, String> customParameters;

  factory ActiveCall.fromDto(ActiveCallDto dto) => ActiveCall(
        sid: dto.sid,
        from: dto.from,
        to: dto.to,
        direction: dto.direction,
        startedAt: DateTime.fromMillisecondsSinceEpoch(dto.startedAt),
        isMuted: dto.isMuted,
        isOnHold: dto.isOnHold,
        isOnSpeaker: dto.isOnSpeaker,
        customParameters: {
          for (final e in (dto.customParameters ?? const {}).entries)
            if (e.key != null && e.value != null) e.key!: e.value!,
        },
      );
}
