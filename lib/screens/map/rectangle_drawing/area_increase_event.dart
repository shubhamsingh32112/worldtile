/// Represents an area increase event for tracking rectangle growth
class AreaIncreaseEvent {
  final DateTime timestamp;
  final double deltaMetersSquared;
  final double previousArea;
  final double newArea;

  AreaIncreaseEvent({
    required this.timestamp,
    required this.deltaMetersSquared,
    required this.previousArea,
    required this.newArea,
  });

  /// Convert to JSON for MongoDB storage
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'deltaMetersSquared': deltaMetersSquared,
        'previousArea': previousArea,
        'newArea': newArea,
      };

  /// Create from JSON (MongoDB data)
  factory AreaIncreaseEvent.fromJson(Map<String, dynamic> json) {
    return AreaIncreaseEvent(
      timestamp: DateTime.parse(json['timestamp']),
      deltaMetersSquared: (json['deltaMetersSquared'] as num).toDouble(),
      previousArea: (json['previousArea'] as num).toDouble(),
      newArea: (json['newArea'] as num).toDouble(),
    );
  }
}

