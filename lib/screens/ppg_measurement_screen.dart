import 'package:flutter/material.dart';
import 'package:heart_bpm/heart_bpm.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import '../models/health_data.dart';
import '../models/ppg_data.dart';
import '../services/database_service.dart';

class PPGMeasurementScreen extends StatefulWidget {
  final HealthData healthData;

  const PPGMeasurementScreen({Key? key, required this.healthData}) : super(key: key);

  @override
  State<PPGMeasurementScreen> createState() => _PPGMeasurementScreenState();
}

class _PPGMeasurementScreenState extends State<PPGMeasurementScreen> {
  final DatabaseService _databaseService = DatabaseService();
  
  bool _isInitialized = false;
  bool _isMeasuring = false;
  bool _hasPermission = false;
  int _currentHeartRate = 0;
  
  // Enhanced data collection for improved accuracy
  List<double> _rawSensorValues = []; // Raw PPG signal from camera
  List<int> _bpmReadings = []; // Individual BPM readings
  List<int> _timestamps = []; // Timestamps for raw values
  List<int> _filteredBpmValues = []; // Filtered BPM values for accuracy
  
  // For signal quality assessment
  int _startTime = 0;
  int _validReadingsCount = 0;
  static const int _minValidReadings = 10; // Minimum readings for reliable result
  static const int _bpmOutlierThreshold = 30; // BPM change threshold for outlier detection
  
  @override
  void initState() {
    super.initState();
    _checkPermissionsAndInitialize();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    final cameraStatus = await Permission.camera.request();
    
    if (cameraStatus.isGranted) {
      setState(() {
        _hasPermission = true;
        _isInitialized = true;
      });
    } else {
      setState(() {
        _hasPermission = false;
      });
    }
  }

  Future<void> _startMeasurement() async {
    if (!_isInitialized) return;

    setState(() {
      _isMeasuring = true;
      _rawSensorValues.clear();
      _bpmReadings.clear();
      _timestamps.clear();
      _filteredBpmValues.clear();
      _currentHeartRate = 0;
      _validReadingsCount = 0;
      _startTime = DateTime.now().millisecondsSinceEpoch;
    });
  }

  Future<void> _stopMeasurement() async {
    if (!_isMeasuring) return;

    setState(() {
      _isMeasuring = false;
    });

    // Save data if we have measurements
    if (_filteredBpmValues.isNotEmpty) {
      await _saveMeasurementData();
    } else if (_bpmReadings.isNotEmpty) {
      // Fallback to unfiltered if no filtered values
      _filteredBpmValues = List.from(_bpmReadings);
      await _saveMeasurementData();
    }
  }

  // Apply outlier rejection using median filter
  void _addBpmReading(int bpm) {
    _bpmReadings.add(bpm);
    
    // Outlier rejection: ignore readings that deviate too much from recent average
    if (_filteredBpmValues.isEmpty) {
      if (bpm >= 40 && bpm <= 200) { // Basic physiological limits
        _filteredBpmValues.add(bpm);
        _validReadingsCount++;
      }
    } else {
      // Calculate recent average (last 5 readings)
      int startIdx = max(0, _filteredBpmValues.length - 5);
      List<int> recent = _filteredBpmValues.sublist(startIdx);
      double recentAvg = recent.reduce((a, b) => a + b) / recent.length;
      
      // Accept reading if within threshold of recent average and physiological limits
      if ((bpm - recentAvg).abs() <= _bpmOutlierThreshold && 
          bpm >= 40 && bpm <= 200) {
        _filteredBpmValues.add(bpm);
        _validReadingsCount++;
      }
    }
  }

  // Calculate Heart Rate Variability (SDNN - Standard Deviation of NN intervals)
  double? _calculateHRV() {
    if (_filteredBpmValues.length < 5) return null;
    
    // Convert BPM to RR intervals (ms)
    List<double> rrIntervals = _filteredBpmValues
        .map((bpm) => 60000.0 / bpm)
        .toList();
    
    // Calculate mean
    double mean = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
    
    // Calculate standard deviation (SDNN)
    double sumSquaredDiff = rrIntervals
        .map((rr) => pow(rr - mean, 2).toDouble())
        .reduce((a, b) => a + b);
    
    double sdnn = sqrt(sumSquaredDiff / rrIntervals.length);
    return sdnn;
  }

  Future<void> _saveMeasurementData() async {
    try {
      // Calculate statistics from filtered values for improved accuracy
      double avgBpm = _filteredBpmValues.reduce((a, b) => a + b) / _filteredBpmValues.length;
      int minBpm = _filteredBpmValues.reduce(min);
      int maxBpm = _filteredBpmValues.reduce(max);
      double? hrv = _calculateHRV();
      
      // Calculate actual duration
      double duration = (DateTime.now().millisecondsSinceEpoch - _startTime) / 1000.0;
      
      final ppgData = PPGData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        healthDataId: widget.healthData.id,
        rawValues: _rawSensorValues, // Store raw sensor data
        bpmReadings: _bpmReadings, // Store all BPM readings
        timestamps: _timestamps, // Store timestamps
        heartRate: avgBpm.round(),
        duration: duration,
        timestamp: DateTime.now(),
        hrv: hrv,
        minBpm: minBpm,
        maxBpm: maxBpm,
      );

      await _databaseService.insertPPGData(ppgData);

      if (mounted) {
        _showResultsDialog(ppgData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving measurement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showResultsDialog(PPGData ppgData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Measurement Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your heart rate measurement has been completed and saved.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Average Heart Rate: ${ppgData.heartRate} BPM'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.trending_down, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('Min: ${ppgData.minBpm ?? "-"} BPM'),
                  const SizedBox(width: 16),
                  const Icon(Icons.trending_up, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('Max: ${ppgData.maxBpm ?? "-"} BPM'),
                ],
              ),
              if (ppgData.hrv != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timeline, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text('HRV (SDNN): ${ppgData.hrv!.toStringAsFixed(1)} ms'),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text('Duration: ${ppgData.duration.toStringAsFixed(1)}s'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Valid readings: $_validReadingsCount / ${_bpmReadings.length}'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(true); // Return to home
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Heart Rate Measurement'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Camera Permission Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Please grant camera permission to measure heart rate.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate Measurement'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Instructions Card
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.favorite, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Heart Rate Measurement',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Place your finger gently on the back camera and keep it still during measurement.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.teal),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'The flash will automatically turn on to improve accuracy.',
                              style: TextStyle(color: Colors.teal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Current Heart Rate Display
            if (_currentHeartRate > 0)
              Card(
                elevation: 2,
                color: Colors.red.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Current Heart Rate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite, color: Colors.red, size: 32),
                          const SizedBox(width: 8),
                          Text(
                            '$_currentHeartRate',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'BPM',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Valid: $_validReadingsCount',
                            style: const TextStyle(color: Colors.green),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Total: ${_bpmReadings.length}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      // Signal quality indicator
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _validReadingsCount >= _minValidReadings 
                            ? 1.0 
                            : _validReadingsCount / _minValidReadings,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _validReadingsCount >= _minValidReadings 
                              ? Colors.green 
                              : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _validReadingsCount >= _minValidReadings 
                            ? 'Ready to save' 
                            : 'Collecting data...',
                        style: TextStyle(
                          fontSize: 12,
                          color: _validReadingsCount >= _minValidReadings 
                              ? Colors.green 
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 20),

            // Heart BPM Widget
            if (_isMeasuring)
              Expanded(
                child: HeartBPMDialog(
                  context: context,
                  onBPM: (value) {
                    setState(() {
                      _currentHeartRate = value;
                      _addBpmReading(value); // Use filtered addition
                    });
                  },
                  onRawData: (value) {
                    // Store raw sensor data for waveform display
                    int currentTime = DateTime.now().millisecondsSinceEpoch - _startTime;
                    setState(() {
                      _rawSensorValues.add(value.value.toDouble());
                      _timestamps.add(currentTime);
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal, width: 2),
                      color: Colors.teal.withOpacity(0.1),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fingerprint, size: 64, color: Colors.teal),
                        SizedBox(height: 16),
                        Text(
                          'Place your finger on the camera',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Keep still for accurate measurement',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey, width: 2),
                    color: Colors.grey.withOpacity(0.1),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Press start to begin measurement',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isMeasuring ? _stopMeasurement : _startMeasurement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isMeasuring ? Colors.red : Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isMeasuring ? Icons.stop : Icons.play_arrow),
                        const SizedBox(width: 8),
                        Text(
                          _isMeasuring ? 'Stop & Save' : 'Start Measurement',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}