/// Asynchronous event broadcasted from Flutter to Mini Apps.
class BridgeEvent {
  final String event;
  final Map<String, dynamic> payload;
  final int timestamp;

  const BridgeEvent({
    required this.event,
    required this.payload,
    required this.timestamp,
  });

  factory BridgeEvent.create(String event, [Map<String, dynamic>? payload]) {
    return BridgeEvent(
      event: event,
      payload: payload ?? {},
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
    'event': event,
    'payload': payload,
    'timestamp': timestamp,
  };
}
