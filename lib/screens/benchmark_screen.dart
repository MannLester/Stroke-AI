// Benchmark Screen - Main UI for MSRF Mobile Testing

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/msrf_classifier.dart';
import '../services/data_service.dart';
import '../services/metrics_service.dart';

class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  // State variables
  bool _isLoading = false;
  bool _isRunning = false;
  bool _dataLoaded = false;
  String _statusMessage = 'Ready to load data';
  String _benchmarkMode = ''; // 'single' or 'all'
  int? _selectedSampleIndex;
  
  // Data
  List<List<double>>? _inputData;
  List<int>? _labels;
  MSRFClassifier? _classifier;
  
  // Results
  BenchmarkResult? _result;
  List<int>? _predictions;
  
  // Services
  final MetricsService _metricsService = MetricsService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading data...';
    });

    try {
      // Load input data
      _inputData = await DataService.loadSampleInput();
      setState(() => _statusMessage = 'Loaded ${_inputData!.length} samples');

      // Load HMM parameters and create classifier
      final hmmParams = await DataService.loadHMMParams();
      _classifier = MSRFClassifier.fromJson(hmmParams);
      setState(() => _statusMessage = 'Model loaded (${_classifier!.nStates} states)');

      // Try to load labels (might not exist)
      _labels = await DataService.loadLabels();
      
      setState(() {
        _dataLoaded = true;
        _isLoading = false;
        _statusMessage = _labels != null 
            ? 'Ready: ${_inputData!.length} samples, ${_labels!.length} labels'
            : 'Ready: ${_inputData!.length} samples (no labels)';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _runAllSamples() async {
    if (_inputData == null || _classifier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please load data first')),
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _benchmarkMode = 'all';
      _statusMessage = 'Running inference on ALL ${_inputData!.length} samples...';
      _result = null;
      _predictions = null;
      _selectedSampleIndex = null;
    });

    try {
      // Get battery level before
      int batteryStart = await _metricsService.getBatteryLevel();
      
      // Get memory BEFORE inference (actual native measurement)
      int memoryBeforeKB = await _metricsService.getCurrentMemoryKB();

      // Warm-up run (exclude from timing)
      if (_inputData!.isNotEmpty) {
        _classifier!.predictSingle(_inputData![0]);
      }

      // Timed inference
      final stopwatch = Stopwatch()..start();
      
      _predictions = _classifier!.predictBatch(_inputData!);
      
      stopwatch.stop();
      double latencyMs = stopwatch.elapsedMicroseconds / 1000.0;
      
      // Get memory AFTER inference (actual native measurement)
      int memoryAfterKB = await _metricsService.getCurrentMemoryKB();

      // Get battery level after
      int batteryEnd = await _metricsService.getBatteryLevel();

      // Calculate performance metrics
      PerformanceMetrics performance = _metricsService.calculatePerformance(
        predictions: _predictions!,
        labels: _labels,
      );

      // Calculate resource metrics
      ResourceMetrics resources = await _metricsService.createResourceMetrics(
        latencyMs: latencyMs,
        sampleCount: _inputData!.length,
        batteryStart: batteryStart,
        batteryEnd: batteryEnd,
        memoryBeforeKB: memoryBeforeKB,
        memoryAfterKB: memoryAfterKB,
      );

      // Create result
      _result = BenchmarkResult(
        performance: performance,
        resources: resources,
        timestamp: DateTime.now(),
        sampleCount: _inputData!.length,
        labelsAvailable: _labels != null,
      );

      setState(() {
        _isRunning = false;
        _statusMessage = 'Benchmark complete! (All ${_inputData!.length} samples)';
      });
    } catch (e) {
      setState(() {
        _isRunning = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _runSingleSample() async {
    if (_inputData == null || _classifier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please load data first')),
      );
      return;
    }

    // Select a random sample
    final random = Random();
    _selectedSampleIndex = random.nextInt(_inputData!.length);
    final singleSample = _inputData![_selectedSampleIndex!];

    setState(() {
      _isRunning = true;
      _benchmarkMode = 'single';
      _statusMessage = 'Running inference on sample #${_selectedSampleIndex! + 1}...';
      _result = null;
      _predictions = null;
    });

    try {
      // Get battery level before
      int batteryStart = await _metricsService.getBatteryLevel();
      
      // Get memory BEFORE inference (actual native measurement)
      int memoryBeforeKB = await _metricsService.getCurrentMemoryKB();

      // Warm-up run (exclude from timing)
      _classifier!.predictSingle(singleSample);

      // Timed inference - single sample
      final stopwatch = Stopwatch()..start();
      
      int prediction = _classifier!.predictSingle(singleSample);
      
      stopwatch.stop();
      double latencyMs = stopwatch.elapsedMicroseconds / 1000.0;
      
      // Get memory AFTER inference (actual native measurement)
      int memoryAfterKB = await _metricsService.getCurrentMemoryKB();

      // Get battery level after
      int batteryEnd = await _metricsService.getBatteryLevel();

      // Store single prediction
      _predictions = [prediction];

      // Calculate performance metrics (single sample)
      List<int>? singleLabel = (_labels != null && _selectedSampleIndex! < _labels!.length) 
          ? [_labels![_selectedSampleIndex!]] 
          : null;
      
      PerformanceMetrics performance = _metricsService.calculatePerformance(
        predictions: _predictions!,
        labels: singleLabel,
      );

      // Calculate resource metrics
      ResourceMetrics resources = await _metricsService.createResourceMetrics(
        latencyMs: latencyMs,
        sampleCount: 1,
        batteryStart: batteryStart,
        batteryEnd: batteryEnd,
        memoryBeforeKB: memoryBeforeKB,
        memoryAfterKB: memoryAfterKB,
      );

      // Create result
      _result = BenchmarkResult(
        performance: performance,
        resources: resources,
        timestamp: DateTime.now(),
        sampleCount: 1,
        labelsAvailable: singleLabel != null,
      );

      setState(() {
        _isRunning = false;
        _statusMessage = 'Single sample benchmark complete! (Sample #${_selectedSampleIndex! + 1})';
      });
    } catch (e) {
      setState(() {
        _isRunning = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MSRF Benchmark'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _loadData,
            tooltip: 'Reload Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(),
            const SizedBox(height: 16),
            
            // Run Button
            _buildRunButton(),
            const SizedBox(height: 16),
            
            // Results
            if (_result != null) ...[
              _buildResourceMetricsCard(),
              const SizedBox(height: 16),
              _buildPerformanceMetricsCard(),
              const SizedBox(height: 16),
              _buildPredictionSummaryCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _dataLoaded ? Icons.check_circle : Icons.info,
                  color: _dataLoaded ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const LinearProgressIndicator()
            else
              Text(_statusMessage),
            if (_inputData != null) ...[
              const SizedBox(height: 8),
              Text(
                'Samples: ${_inputData!.length} | Features: ${_inputData![0].length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Labels: ${_labels != null ? "Available (${_labels!.length})" : "Not available"}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _labels != null ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRunButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Run Single Sample Button
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: (_dataLoaded && !_isRunning) ? _runSingleSample : null,
            icon: _isRunning && _benchmarkMode == 'single'
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person, size: 28),
            label: Text(
              _isRunning && _benchmarkMode == 'single' 
                  ? 'Running...' 
                  : 'Run Single Sample (Random)',
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Run All Samples Button
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: (_dataLoaded && !_isRunning) ? _runAllSamples : null,
            icon: _isRunning && _benchmarkMode == 'all'
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.all_inclusive, size: 28),
            label: Text(
              _isRunning && _benchmarkMode == 'all' 
                  ? 'Running...' 
                  : 'Run All Samples (${_inputData?.length ?? 0})',
              style: const TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResourceMetricsCard() {
    final res = _result!.resources;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Resource Metrics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            _buildMetricRow('Total Latency', '${res.latencyMs.toStringAsFixed(2)} ms'),
            _buildMetricRow('Latency/Sample', '${res.latencyPerSampleMs.toStringAsFixed(4)} ms'),
            _buildMetricRow('Throughput', '${res.throughput.toStringAsFixed(1)} samples/sec'),
            const Divider(),
            Text('Memory (Actual RSS)', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            _buildMetricRow('Before Inference', '${res.memoryBeforeKB} KB'),
            _buildMetricRow('After Inference', '${res.memoryAfterKB} KB'),
            _buildMetricRow('Memory Used', '${res.memoryUsedKB} KB'),
            const Divider(),
            _buildMetricRow('Battery Start', '${res.batteryLevelStart}%'),
            _buildMetricRow('Battery End', '${res.batteryLevelEnd}%'),
            _buildMetricRow('Battery Drain', '${res.estimatedBatteryDrain.toStringAsFixed(0)}%'),
            const Divider(),
            _buildMetricRow('Device', res.deviceModel),
            _buildMetricRow('OS', res.osVersion),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetricsCard() {
    final perf = _result!.performance;
    final hasLabels = _result!.labelsAvailable;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Performance Metrics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            if (!hasLabels)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Labels not available. Add labels.csv to see accuracy metrics.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              _buildMetricRow('Accuracy', '${(perf.accuracy * 100).toStringAsFixed(2)}%'),
              _buildMetricRow('Precision', '${(perf.precision * 100).toStringAsFixed(2)}%'),
              _buildMetricRow('Recall', '${(perf.recall * 100).toStringAsFixed(2)}%'),
              _buildMetricRow('F1 Score', '${(perf.f1Score * 100).toStringAsFixed(2)}%'),
              _buildMetricRow('Specificity', '${(perf.specificity * 100).toStringAsFixed(2)}%'),
              const Divider(),
              _buildMetricRow('True Positives', '${perf.truePositives}'),
              _buildMetricRow('True Negatives', '${perf.trueNegatives}'),
              _buildMetricRow('False Positives', '${perf.falsePositives}'),
              _buildMetricRow('False Negatives', '${perf.falseNegatives}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionSummaryCard() {
    final perf = _result!.performance;
    double riskPercent = perf.riskCount / perf.totalSamples * 100;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Prediction Summary',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            _buildMetricRow('Total Samples', '${perf.totalSamples}'),
            _buildMetricRow('High Risk (1)', '${perf.riskCount} (${riskPercent.toStringAsFixed(1)}%)'),
            _buildMetricRow('Stable (0)', '${perf.stableCount} (${(100-riskPercent).toStringAsFixed(1)}%)'),
            const SizedBox(height: 12),
            // Visual bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: riskPercent / 100,
                backgroundColor: Colors.green.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                minHeight: 20,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Stable', style: Theme.of(context).textTheme.bodySmall),
                Text('High Risk', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }
}
