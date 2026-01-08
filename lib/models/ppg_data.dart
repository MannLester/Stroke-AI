class PPGData {
  final String id;
  final String healthDataId; // Links to health data
  final List<double> rawValues;
  final int heartRate;
  final double duration; // in seconds
  final DateTime timestamp;
  final double? spo2; // Optional for future use
  
  PPGData({
    required this.id,
    required this.healthDataId,
    required this.rawValues,
    required this.heartRate,
    required this.duration,
    required this.timestamp,
    this.spo2,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'health_data_id': healthDataId,
      'raw_values': rawValues.join(','),
      'heart_rate': heartRate,
      'duration': duration,
      'timestamp': timestamp.toIso8601String(),
      'spo2': spo2,
    };
  }

  factory PPGData.fromMap(Map<String, dynamic> map) {
    return PPGData(
      id: map['id'],
      healthDataId: map['health_data_id'],
      rawValues: map['raw_values'].split(',').map<double>((e) => double.parse(e)).toList(),
      heartRate: map['heart_rate'],
      duration: map['duration'],
      timestamp: DateTime.parse(map['timestamp']),
      spo2: map['spo2'],
    );
  }

  PPGData copyWith({
    String? id,
    String? healthDataId,
    List<double>? rawValues,
    int? heartRate,
    double? duration,
    DateTime? timestamp,
    double? spo2,
  }) {
    return PPGData(
      id: id ?? this.id,
      healthDataId: healthDataId ?? this.healthDataId,
      rawValues: rawValues ?? this.rawValues,
      heartRate: heartRate ?? this.heartRate,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      spo2: spo2 ?? this.spo2,
    );
  }
}