# Resource Metrics Methodology

## Overview

This document describes the methodology used to measure resource consumption metrics for the Multi-State Random Forest (MSRF) model deployed on a mobile device. These measurements are essential for validating the feasibility of running complex machine learning models in mobile healthcare applications.

---

## Terminology

### Sample vs Window

| Term | Definition |
|------|------------|
| **1 Sample** | = **1 Window** of PPG (Photoplethysmography) signal data |
| **Features per Sample** | 26 HRV (Heart Rate Variability) features extracted from the window |
| **Output per Sample** | 1 binary risk classification (0 = Low Risk, 1 = High Risk) |

The benchmark processes **1000 samples/windows** to measure resource metrics.

---

## Metrics Collected

### 1. Latency Metrics

| Metric | Description | Formula |
|--------|-------------|---------|
| **Total Latency** | Time to process all samples | `stopwatch.elapsedMicroseconds / 1000.0` (ms) |
| **Latency per Sample** | Average time per sample | `Total Latency / Sample Count` (ms) |
| **Throughput** | Processing rate | `Sample Count / (Total Latency / 1000)` (samples/sec) |

### 2. Memory Metrics

| Metric | Description | Method |
|--------|-------------|--------|
| **Memory Before (KB)** | RSS memory before inference | `ProcessInfo.currentRss` |
| **Memory After (KB)** | RSS memory after inference | `ProcessInfo.currentRss` |
| **Memory Used (KB)** | Actual memory consumed | `After - Before` |

**RSS (Resident Set Size)**: The actual physical memory (RAM) currently being used by the process.

### 3. Battery Metrics

| Metric | Description |
|--------|-------------|
| **Battery Start (%)** | Battery level before inference |
| **Battery End (%)** | Battery level after inference |
| **Battery Drain (%)** | `Battery Start - Battery End` |

### 4. Device Information

| Metric | Description |
|--------|-------------|
| **Device Model** | Manufacturer and model name |
| **OS Version** | Operating system and version |

---

## Flutter Packages Used

### 1. battery_plus (v6.2.3)
- **Purpose**: Measure battery level before and after inference
- **Repository**: https://pub.dev/packages/battery_plus
- **Usage**:
```dart
import 'package:battery_plus/battery_plus.dart';

final Battery _battery = Battery();
int batteryLevel = await _battery.batteryLevel;
```

### 2. device_info_plus (v10.1.2)
- **Purpose**: Retrieve device model and OS version
- **Repository**: https://pub.dev/packages/device_info_plus
- **Usage**:
```dart
import 'package:device_info_plus/device_info_plus.dart';

final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

// For Android
AndroidDeviceInfo info = await _deviceInfo.androidInfo;
String model = '${info.manufacturer} ${info.model}';
String osVersion = 'Android ${info.version.release}';

// For iOS
IosDeviceInfo info = await _deviceInfo.iosInfo;
String model = info.model;
String osVersion = 'iOS ${info.systemVersion}';
```

### 3. Dart dart:developer (Built-in)
- **Purpose**: Actual memory measurement using ProcessInfo.currentRss
- **Documentation**: https://api.dart.dev/stable/dart-io/ProcessInfo-class.html
- **Usage**:
```dart
import 'dart:io';

// Get actual memory usage in bytes
int memoryBytes = ProcessInfo.currentRss;
int memoryKB = memoryBytes ~/ 1024;
```

### 4. Dart Stopwatch (Built-in)
- **Purpose**: High-precision timing for latency measurement
- **Documentation**: https://api.dart.dev/stable/dart-core/Stopwatch-class.html
- **Usage**:
```dart
final Stopwatch stopwatch = Stopwatch()..start();

// Run inference
predictions = classifier.predictBatch(inputData);

stopwatch.stop();
double latencyMs = stopwatch.elapsedMicroseconds / 1000.0;
```

---

## Implementation Details

### Latency Measurement

The latency is measured using Dart's built-in `Stopwatch` class, which provides microsecond precision.

**Code Implementation** ([benchmark_screen.dart](lib/screens/benchmark_screen.dart)):

```dart
Future<void> _runBenchmark() async {
  // Get battery level BEFORE inference
  int batteryStart = await _metricsService.getBatteryLevel();

  // Start high-precision timer
  final Stopwatch stopwatch = Stopwatch()..start();
  
  // Run MSRF inference on all samples
  _predictions = _classifier!.predictBatch(_inputData!);
  
  // Stop timer
  stopwatch.stop();
  double latencyMs = stopwatch.elapsedMicroseconds / 1000.0;

  // Get battery level AFTER inference
  int batteryEnd = await _metricsService.getBatteryLevel();
}
```

**Key Points**:
- Timer starts immediately before inference
- Timer stops immediately after all predictions complete
- Uses `elapsedMicroseconds` for maximum precision
- Converted to milliseconds for readability

### Battery Measurement

Battery levels are captured before and after the inference process using the `battery_plus` package.

**Code Implementation** ([metrics_service.dart](lib/services/metrics_service.dart)):

```dart
Future<int> getBatteryLevel() async {
  try {
    return await _battery.batteryLevel;
  } catch (e) {
    return -1; // Return -1 if battery info unavailable
  }
}
```

**Limitations**:
- Battery percentage is integer-based (1% granularity)
- Short inference times may not show measurable drain
- Battery level can be affected by other running processes

### Memory Measurement

Memory usage is measured using Dart's built-in `ProcessInfo.currentRss` which returns the **Resident Set Size (RSS)** - the actual physical memory currently allocated to the process.

**Code Implementation** ([metrics_service.dart](lib/services/metrics_service.dart)):

```dart
import 'dart:io';

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
```

**Measurement Process** ([benchmark_screen.dart](lib/screens/benchmark_screen.dart)):

```dart
// Get memory BEFORE inference (actual measurement)
int memoryBeforeKB = _metricsService.getCurrentMemoryKB();

// Run inference
_predictions = _classifier!.predictBatch(_inputData!);

// Get memory AFTER inference (actual measurement)
int memoryAfterKB = _metricsService.getCurrentMemoryKB();

// Memory used = After - Before
int memoryUsedKB = memoryAfterKB - memoryBeforeKB;
```

**Key Points**:
- Uses `ProcessInfo.currentRss` from `dart:io` - native Dart API
- Returns RSS (Resident Set Size) - actual physical RAM usage
- Measured in bytes, converted to KB for readability
- Captures memory before AND after inference for accurate delta

### Device Information

Device details are retrieved using the `device_info_plus` package.

**Code Implementation** ([metrics_service.dart](lib/services/metrics_service.dart)):

```dart
Future<Map<String, String>> getDeviceInfo() async {
  String model = 'Unknown';
  String osVersion = 'Unknown';
  
  if (Platform.isAndroid) {
    AndroidDeviceInfo info = await _deviceInfo.androidInfo;
    model = '${info.manufacturer} ${info.model}';
    osVersion = 'Android ${info.version.release}';
  } else if (Platform.isIOS) {
    IosDeviceInfo info = await _deviceInfo.iosInfo;
    model = info.model;
    osVersion = 'iOS ${info.systemVersion}';
  }
  // ... other platforms
  
  return {'model': model, 'osVersion': osVersion};
}
```

---

## Complete Benchmark Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      BENCHMARK PROCESS                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. LOAD DATA                                                   │
│     ├── Load sample_input.csv (1000 samples × 26 features)     │
│     ├── Load HMM parameters (hmm_params.json)                  │
│     └── Initialize MSRF Classifier                              │
│                                                                 │
│  2. PRE-MEASUREMENT                                             │
│     └── Record battery level (battery_plus)                    │
│                                                                 │
│  3. START TIMER                                                 │
│     └── Stopwatch().start()                                     │
│                                                                 │
│  4. RUN INFERENCE (MSRF Pipeline)                              │
│     ├── HMM Forward-Backward Algorithm                         │
│     ├── State Probability Calculation                          │
│     ├── Expert Selection (based on HMM state)                  │
│     └── Random Forest Prediction (expert_0, expert_1, expert_2)│
│                                                                 │
│  5. STOP TIMER                                                  │
│     └── stopwatch.stop()                                        │
│                                                                 │
│  6. POST-MEASUREMENT                                            │
│     ├── Record battery level                                   │
│     └── Get device information (device_info_plus)              │
│                                                                 │
│  7. CALCULATE METRICS                                           │
│     ├── Total Latency = elapsed microseconds / 1000            │
│     ├── Latency/Sample = Total Latency / Sample Count          │
│     ├── Throughput = Sample Count / (Latency / 1000)           │
│     ├── Memory = Estimated from data size + model overhead     │
│     └── Battery Drain = Battery Start - Battery End            │
│                                                                 │
│  8. DISPLAY RESULTS                                             │
│     └── Show all metrics in UI cards                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
lib/
├── main.dart                          # App entry point
├── models/
│   ├── msrf_classifier.dart           # MSRF implementation with HMM
│   └── generated/
│       ├── expert_0.dart              # Random Forest Expert 0 (m2cgen)
│       ├── expert_1.dart              # Random Forest Expert 1 (m2cgen)
│       └── expert_2.dart              # Random Forest Expert 2 (m2cgen)
├── services/
│   ├── data_service.dart              # Load CSV/JSON assets
│   └── metrics_service.dart           # Resource metrics calculation
└── screens/
    └── benchmark_screen.dart          # Benchmark UI and orchestration

assets/
├── data/
│   └── sample_input.csv               # 1000 test samples (26 features each)
└── exports/
    └── hmm_params.json                # HMM start probabilities & transition matrix
```

---

## Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  battery_plus: ^6.0.0          # Battery level measurement
  device_info_plus: ^10.1.0     # Device information
  csv: ^6.0.0                   # CSV parsing for sample data
  path_provider: ^2.1.1         # File path utilities
```

---

## Reproducibility

To reproduce these measurements:

1. **Clone the repository** and install dependencies:
   ```bash
   flutter pub get
   ```

2. **Connect a physical device** (emulators may not provide accurate battery readings)

3. **Run the app**:
   ```bash
   flutter run
   ```

4. **Click "Run Benchmark"** button in the app

5. **Results are displayed** immediately after inference completes

---

## Limitations & Considerations

### Memory Measurement
- RSS (Resident Set Size) measures actual physical memory
- May include memory from garbage collector overhead
- For detailed heap analysis, use Flutter DevTools memory tab

### Battery Measurement
- 1% granularity may not capture small drains
- Background processes can affect readings
- For precise measurement, consider:
  - Multiple runs and averaging
  - Airplane mode to reduce interference
  - Full charge cycle testing

### Latency Measurement
- Debug mode adds overhead; release mode is faster
- First run may include JIT compilation time
- Consider warmup runs for consistent results

---

## Validation Checklist

- [x] Latency measured with microsecond precision (Stopwatch)
- [x] Battery level captured before and after inference (battery_plus)
- [x] Device information retrieved programmatically (device_info_plus)
- [x] Memory measured using actual RSS (ProcessInfo.currentRss)
- [x] All metrics displayed in user interface
- [x] Packages are well-documented and maintained
- [x] NO fake/estimated metrics - all measurements are real

---

## References

1. **battery_plus**: https://pub.dev/packages/battery_plus
2. **device_info_plus**: https://pub.dev/packages/device_info_plus
3. **Dart Stopwatch**: https://api.dart.dev/stable/dart-core/Stopwatch-class.html
4. **m2cgen (Model to Code Generator)**: https://github.com/BayesWitnesses/m2cgen
5. **Flutter Performance Profiling**: https://docs.flutter.dev/perf/app-size

---

*Document generated: February 1, 2026*
*MSRF Mobile Benchmark Application*
