import '../generated/voice_api.g.dart' as pigeon;

/// Public-facing audio output route. Mirrors `pigeon.AudioRoute`.
/// Keep in sync with `pigeons/voice_api.dart`.
enum AudioRoute {
  earpiece,
  speaker,
  bluetooth,
  wired;

  static AudioRoute fromPigeon(pigeon.AudioRoute r) {
    switch (r) {
      case pigeon.AudioRoute.earpiece:
        return AudioRoute.earpiece;
      case pigeon.AudioRoute.speaker:
        return AudioRoute.speaker;
      case pigeon.AudioRoute.bluetooth:
        return AudioRoute.bluetooth;
      case pigeon.AudioRoute.wired:
        return AudioRoute.wired;
    }
  }

  pigeon.AudioRoute toPigeon() {
    switch (this) {
      case AudioRoute.earpiece:
        return pigeon.AudioRoute.earpiece;
      case AudioRoute.speaker:
        return pigeon.AudioRoute.speaker;
      case AudioRoute.bluetooth:
        return pigeon.AudioRoute.bluetooth;
      case AudioRoute.wired:
        return pigeon.AudioRoute.wired;
    }
  }
}

/// Snapshot of one audio route with availability + label.
class AudioRouteInfo {
  const AudioRouteInfo({
    required this.route,
    required this.isActive,
    this.deviceName,
  });

  final AudioRoute route;
  final bool isActive;

  /// Human-readable device label for non-built-in routes (e.g. `"AirPods Pro"`).
  /// Always `null` for `earpiece` and `speaker`. Display-only.
  final String? deviceName;

  factory AudioRouteInfo.fromDto(pigeon.AudioRouteInfo dto) => AudioRouteInfo(
        route: AudioRoute.fromPigeon(dto.route),
        isActive: dto.isActive,
        deviceName: dto.deviceName,
      );
}
