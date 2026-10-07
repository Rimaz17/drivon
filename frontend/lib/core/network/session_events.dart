import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets the network layer report that the session ended (refresh rejected)
/// without depending on the auth feature, which listens and signs out.
class SessionEvents {
  final StreamController<void> _expired = StreamController<void>.broadcast();

  Stream<void> get expired => _expired.stream;

  void notifyExpired() => _expired.add(null);

  Future<void> dispose() => _expired.close();
}

final sessionEventsProvider = Provider<SessionEvents>((ref) {
  final events = SessionEvents();
  ref.onDispose(events.dispose);
  return events;
});
