class HealthData {
  final String id;
  final int age;
  final double bmi;
  final DateTime timestamp;
  final Map<String, dynamic>? additionalData; // For scalability

  HealthData({
    required this.id,
    required this.age,
    required this.bmi,
    required this.timestamp,
    this.additionalData,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'age': age,
      'bmi': bmi,
      'timestamp': timestamp.toIso8601String(),
      'additional_data': additionalData != null 
          ? _encodeAdditionalData(additionalData!) 
          : null,
    };
  }

  factory HealthData.fromMap(Map<String, dynamic> map) {
    return HealthData(
      id: map['id'],
      age: map['age'],
      bmi: map['bmi'],
      timestamp: DateTime.parse(map['timestamp']),
      additionalData: map['additional_data'] != null 
          ? _decodeAdditionalData(map['additional_data'])
          : null,
    );
  }

  // Simple JSON encoding for additional data
  static String _encodeAdditionalData(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  static Map<String, dynamic> _decodeAdditionalData(String data) {
    Map<String, dynamic> result = {};
    for (String pair in data.split(',')) {
      List<String> keyValue = pair.split(':');
      if (keyValue.length == 2) {
        result[keyValue[0]] = keyValue[1];
      }
    }
    return result;
  }

  HealthData copyWith({
    String? id,
    int? age,
    double? bmi,
    DateTime? timestamp,
    Map<String, dynamic>? additionalData,
  }) {
    return HealthData(
      id: id ?? this.id,
      age: age ?? this.age,
      bmi: bmi ?? this.bmi,
      timestamp: timestamp ?? this.timestamp,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}