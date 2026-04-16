import 'active_call.dart';
import 'call_event.dart';

/// Snapshot delivered alongside a [CallEvent] via the voice event stream.
class Call {
  const Call({required this.event, this.active});

  final CallEvent event;
  final ActiveCall? active;
}
