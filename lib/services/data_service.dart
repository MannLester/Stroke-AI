// Data Loading Service
// Handles loading CSV data and model parameters from assets

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class DataService {
  /// Load sample input data from CSV
  static Future<List<List<double>>> loadSampleInput() async {
    try {
      final csvString = await rootBundle.loadString('assets/data/sample_input.csv');
      final lines = csvString.trim().split('\n');
      
      List<List<double>> data = [];
      for (String line in lines) {
        if (line.trim().isEmpty) continue;
        List<double> row = line.split(',').map((s) => double.parse(s.trim())).toList();
        data.add(row);
      }
      
      return data;
    } catch (e) {
      throw Exception('Failed to load sample_input.csv: $e');
    }
  }
  
  /// Load HMM parameters from JSON
  static Future<Map<String, dynamic>> loadHMMParams() async {
    try {
      final jsonString = await rootBundle.loadString('assets/exports/hmm_params.json');
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load hmm_params.json: $e');
    }
  }
  
  /// Load ground truth labels (if available)
  static Future<List<int>?> loadLabels() async {
    try {
      final csvString = await rootBundle.loadString('assets/exports/labels.csv');
      final lines = csvString.trim().split('\n');
      
      List<int> labels = [];
      for (String line in lines) {
        if (line.trim().isEmpty) continue;
        labels.add(int.parse(line.trim().split(',')[0]));
      }
      
      return labels;
    } catch (e) {
      // Labels might not exist yet - this is okay
      print('Labels not found: $e');
      return null;
    }
  }
  
  /// Load pre-computed predictions (for validation)
  static Future<List<int>?> loadPredictions() async {
    try {
      final csvString = await rootBundle.loadString('assets/exports/predictions.csv');
      final lines = csvString.trim().split('\n');
      
      List<int> predictions = [];
      for (String line in lines) {
        if (line.trim().isEmpty) continue;
        predictions.add(int.parse(line.trim().split(',')[0]));
      }
      
      return predictions;
    } catch (e) {
      print('Pre-computed predictions not found: $e');
      return null;
    }
  }
  
  /// Load pre-computed probabilities
  static Future<List<double>?> loadProbabilities() async {
    try {
      final csvString = await rootBundle.loadString('assets/exports/probabilities.csv');
      final lines = csvString.trim().split('\n');
      
      List<double> probs = [];
      for (String line in lines) {
        if (line.trim().isEmpty) continue;
        probs.add(double.parse(line.trim()));
      }
      
      return probs;
    } catch (e) {
      print('Pre-computed probabilities not found: $e');
      return null;
    }
  }
  
  /// Load scaler parameters
  static Future<Map<String, dynamic>?> loadScalerParams() async {
    try {
      final jsonString = await rootBundle.loadString('assets/config/scaler_parameters.json');
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Scaler parameters not found: $e');
      return null;
    }
  }
}
