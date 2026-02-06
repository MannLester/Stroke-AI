import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'base_classifier.dart';

/// LSTM classifier using TensorFlow Lite
/// Loads the converted .tflite model and runs inference
class LSTMClassifier implements BaseClassifier {
  Interpreter? _interpreter;
  
  @override
  String get modelName => 'LSTM';

  @override
  String get modelDescription =>
      'Long Short-Term Memory neural network for sequential data';

  @override
  Future<void> initialize() async {
    try {
      // Load the TFLite model from assets
      // Path is relative to assets folder as declared in pubspec.yaml
      _interpreter = await Interpreter.fromAsset('assets/models/model_LSTM.tflite');
      
      // Print input/output tensor info for debugging
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      
      print('LSTM Model loaded successfully:');
      print('  Input shape: ${inputTensor.shape}');
      print('  Output shape: ${outputTensor.shape}');
    } catch (e) {
      print('Error loading LSTM model: $e');
      rethrow;
    }
  }

  @override
  int predictSingle(List<double> features) {
    if (_interpreter == null) {
      throw StateError('LSTM model not initialized. Call initialize() first.');
    }
    
    // LSTM expects input shape: [batch_size, timesteps, features] = [1, 1, 26]
    // Reshape the flat 26-feature input to [1, 1, 26]
    final input = [
      [features]
    ]; // Shape: [1, 1, 26]
    
    // Output shape: [1, 1] for binary classification
    final output = List.filled(1, List.filled(1, 0.0));
    
    // Run inference
    _interpreter!.run(input, output);
    
    // Output is a sigmoid value (0-1), threshold at 0.5
    final probability = output[0][0];
    return probability >= 0.5 ? 1 : 0;
  }

  @override
  List<int> predictBatch(List<List<double>> samples) {
    return samples.map((sample) => predictSingle(sample)).toList();
  }

  /// Get raw probability score for a sample
  double predictProba(List<double> features) {
    if (_interpreter == null) {
      throw StateError('LSTM model not initialized. Call initialize() first.');
    }
    
    final input = [
      [features]
    ];
    final output = List.filled(1, List.filled(1, 0.0));
    
    _interpreter!.run(input, output);
    
    return output[0][0];
  }

  /// Clean up resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
