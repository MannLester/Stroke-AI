class PPGData {
  final String id;
  final String healthDataId; // Links to health data
  final List<double> rawValues; // Raw PPG signal values from sensor
  final List<int> bpmReadings; // Individual BPM readings over time
  final List<int> timestamps; // Timestamps for each raw value (milliseconds from start)
  final int heartRate;
  final double duration; // in seconds
  final DateTime timestamp;
  final double? spo2; // Optional for future use
  final double? hrv; // Heart Rate Variability (SDNN in ms)
  final int? minBpm; // Minimum BPM during measurement
  final int? maxBpm; // Maximum BPM during measurement
  
  PPGData({
    required this.id,
    required this.healthDataId,
    required this.rawValues,
    this.bpmReadings = const [],
    this.timestamps = const [],
    required this.heartRate,
    required this.duration,
    required this.timestamp,
    this.spo2,
    this.hrv,
    this.minBpm,
    this.maxBpm,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'health_data_id': healthDataId,
      'raw_values': rawValues.join(','),
      'bpm_readings': bpmReadings.join(','),
      'timestamps': timestamps.join(','),
      'heart_rate': heartRate,
      'duration': duration,
      'timestamp': timestamp.toIso8601String(),
      'spo2': spo2,
      'hrv': hrv,
      'min_bpm': minBpm,
      'max_bpm': maxBpm,
    };
  }

  factory PPGData.fromMap(Map<String, dynamic> map) {
    return PPGData(
      id: map['id'],
      healthDataId: map['health_data_id'],
      rawValues: (map['raw_values'] as String?)?.isNotEmpty == true 
          ? map['raw_values'].split(',').map<double>((e) => double.parse(e)).toList()
          : [],
      bpmReadings: (map['bpm_readings'] as String?)?.isNotEmpty == true
          ? map['bpm_readings'].split(',').map<int>((e) => int.parse(e)).toList()
          : [],
      timestamps: (map['timestamps'] as String?)?.isNotEmpty == true
          ? map['timestamps'].split(',').map<int>((e) => int.parse(e)).toList()
          : [],
      heartRate: map['heart_rate'],
      duration: map['duration'],
      timestamp: DateTime.parse(map['timestamp']),
      spo2: map['spo2'],
      hrv: map['hrv'],
      minBpm: map['min_bpm'],
      maxBpm: map['max_bpm'],
    );
  }

  PPGData copyWith({
    String? id,
    String? healthDataId,
    List<double>? rawValues,
    List<int>? bpmReadings,
    List<int>? timestamps,
    int? heartRate,
    double? duration,
    DateTime? timestamp,
    double? spo2,
    double? hrv,
    int? minBpm,
    int? maxBpm,
  }) {
    return PPGData(
      id: id ?? this.id,
      healthDataId: healthDataId ?? this.healthDataId,
      rawValues: rawValues ?? this.rawValues,
      bpmReadings: bpmReadings ?? this.bpmReadings,
      timestamps: timestamps ?? this.timestamps,
      heartRate: heartRate ?? this.heartRate,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      spo2: spo2 ?? this.spo2,
      hrv: hrv ?? this.hrv,
      minBpm: minBpm ?? this.minBpm,
      maxBpm: maxBpm ?? this.maxBpm,
    );
  }
}