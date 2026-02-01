// Metrics Service
// Handles calculation of performance metrics and resource monitoring

import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Performance metrics for model evaluation
class PerformanceMetrics {
  final double accuracy;
  final double precision;
  final double recall;
  final double f1Score;
  final double specificity;
  final int truePositives;
  final int trueNegatives;
  final int falsePositives;
  final int falseNegatives;
  final int totalSamples;
  final int riskCount;
  final int stableCount;
  
  PerformanceMetrics({
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1Score,
    required this.specificity,
    required this.truePositives,
    required this.trueNegatives,
    required this.falsePositives,
    required this.falseNegatives,
    required this.totalSamples,
    required this.riskCount,
    required this.stableCount,
  });
  
  /// Create metrics without ground truth (predictions only)
  factory PerformanceMetrics.predictionsOnly({
    required List<int> predictions,
  }) {
    int riskCount = predictions.where((p) => p == 1).length;
    int stableCount = predictions.where((p) => p == 0).length;
    
    return PerformanceMetrics(
      accuracy: double.nan,
      precision: double.nan,
      recall: double.nan,
      f1Score: double.nan,
      specificity: double.nan,
      truePositives: 0,
      trueNegatives: 0,
      falsePositives: 0,
      falseNegatives: 0,
      totalSamples: predictions.length,
      riskCount: riskCount,
      stableCount: stableCount,
    );
  }
}

/// Resource consumption metrics
class ResourceMetrics {
  final double latencyMs;           // Total inference time
  final double latencyPerSampleMs;  // Per-sample latency
  final double throughput;          // Samples per second
  final int batteryLevelStart;
  final int batteryLevelEnd;
  final double estimatedBatteryDrain;
  final int memoryBeforeKB;         // Memory before inference (actual)
  final int memoryAfterKB;          // Memory after inference (actual)
  final int memoryUsedKB;           // Memory used during inference (actual)
  final String deviceModel;
  final String osVersion;
  
  ResourceMetrics({
    required this.latencyMs,
    required this.latencyPerSampleMs,
    required this.throughput,
    required this.batteryLevelStart,
    required this.batteryLevelEnd,
    required this.estimatedBatteryDrain,
    required this.memoryBeforeKB,
    required this.memoryAfterKB,
    required this.memoryUsedKB,
    required this.deviceModel,
    required this.osVersion,
  });
}

/// Combined benchmark results
class BenchmarkResult {
  final PerformanceMetrics performance;
  final ResourceMetrics resources;
  final DateTime timestamp;
  final int sampleCount;
  final bool labelsAvailable;
  
  BenchmarkResult({
    required this.performance,
    required this.resources,
    required this.timestamp,
    required this.sampleCount,
    required this.labelsAvailable,
  });
}

class MetricsService {
  final Battery _battery = Battery();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  /// Calculate performance metrics from predictions and labels
  PerformanceMetrics calculatePerformance({
    required List<int> predictions,
    List<int>? labels,
  }) {
    if (labels == null || labels.isEmpty) {
      return PerformanceMetrics.predictionsOnly(predictions: predictions);
    }
    
    // Ensure same length
    int n = predictions.length < labels.length ? predictions.length : labels.length;
    
    int tp = 0, tn = 0, fp = 0, fn = 0;
    
    for (int i = 0; i < n; i++) {
      int pred = predictions[i];
      int actual = labels[i];
      
      if (pred == 1 && actual == 1) tp++;
      else if (pred == 0 && actual == 0) tn++;
      else if (pred == 1 && actual == 0) fp++;
      else if (pred == 0 && actual == 1) fn++;
    }
    
    double accuracy = (tp + tn) / (tp + tn + fp + fn + 1e-10);
    double precision = tp / (tp + fp + 1e-10);
    double recall = tp / (tp + fn + 1e-10);
    double f1 = 2 * precision * recall / (precision + recall + 1e-10);
    double specificity = tn / (tn + fp + 1e-10);
    
    int riskCount = predictions.where((p) => p == 1).length;
    int stableCount = predictions.where((p) => p == 0).length;
    
    return PerformanceMetrics(
      accuracy: accuracy,
      precision: precision,
      recall: recall,
      f1Score: f1,
      specificity: specificity,
      truePositives: tp,
      trueNegatives: tn,
      falsePositives: fp,
      falseNegatives: fn,
      totalSamples: n,
      riskCount: riskCount,
      stableCount: stableCount,
    );
  }
  
  /// Get current battery level
  Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      return -1;
    }
  }
  
  /// Get device information
  Future<Map<String, String>> getDeviceInfo() async {
    String model = 'Unknown';
    String osVersion = 'Unknown';
    
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo info = await _deviceInfo.androidInfo;
        model = '${info.manufacturer} ${info.model}';
        osVersion = 'Android ${info.version.release}';
      } else if (Platform.isIOS) {
        IosDeviceInfo info = await _deviceInfo.iosInfo;
        model = info.model;
        osVersion = 'iOS ${info.systemVersion}';
      } else if (Platform.isWindows) {
        WindowsDeviceInfo info = await _deviceInfo.windowsInfo;
        model = info.computerName;
        osVersion = 'Windows';
      } else if (Platform.isMacOS) {
        MacOsDeviceInfo info = await _deviceInfo.macOsInfo;
        model = info.model;
        osVersion = 'macOS ${info.osRelease}';
      } else if (Platform.isLinux) {
        LinuxDeviceInfo info = await _deviceInfo.linuxInfo;
        model = info.prettyName;
        osVersion = 'Linux';
      }
    } catch (e) {
      print('Error getting device info: $e');
    }
    
    return {'model': model, 'osVersion': osVersion};
  }
  
  /// Get current memory usage in KB using Dart's ProcessInfo
  /// This returns the Resident Set Size (RSS) - actual physical memory used
  int getCurrentMemoryKB() {
    try {
      // ProcessInfo.currentRss returns memory in bytes
      return ProcessInfo.currentRss ~/ 1024;
    } catch (e) {
      print('Error getting memory info: $e');
      return -1;
    }
  }
  
  /// Create resource metrics from timing data
  Future<ResourceMetrics> createResourceMetrics({
    required double latencyMs,
    required int sampleCount,
    required int batteryStart,
    required int batteryEnd,
    required int memoryBeforeKB,
    required int memoryAfterKB,
  }) async {
    Map<String, String> deviceInfo = await getDeviceInfo();
    
    return ResourceMetrics(
      latencyMs: latencyMs,
      latencyPerSampleMs: latencyMs / sampleCount,
      throughput: sampleCount / (latencyMs / 1000),
      batteryLevelStart: batteryStart,
      batteryLevelEnd: batteryEnd,
      estimatedBatteryDrain: (batteryStart - batteryEnd).toDouble(),
      memoryBeforeKB: memoryBeforeKB,
      memoryAfterKB: memoryAfterKB,
      memoryUsedKB: memoryAfterKB - memoryBeforeKB,
      deviceModel: deviceInfo['model'] ?? 'Unknown',
      osVersion: deviceInfo['osVersion'] ?? 'Unknown',
    );
  }
}
