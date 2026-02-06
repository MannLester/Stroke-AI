// Logistic Regression Classifier Wrapper

import 'dart:math';
import 'base_classifier.dart';
import 'generated/logistic_regression.dart' as lr;

class LogisticRegressionClassifier implements BaseClassifier {
  @override
  String get modelName => 'Logistic Regression';
  
  @override
  String get modelDescription => 'Linear classifier with sigmoid activation';
  
  @override
  Future<void> initialize() async {
    // No initialization needed for Logistic Regression
  }
  
  /// Sigmoid function to convert log-odds to probability
  double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }
  
  @override
  int predictSingle(List<double> features) {
    // Logistic Regression returns log-odds (single value)
    double logOdds = lr.predictLogisticRegression(features);
    double probability = _sigmoid(logOdds);
    return probability > 0.5 ? 1 : 0;
  }
  
  @override
  List<int> predictBatch(List<List<double>> samples) {
    return samples.map((s) => predictSingle(s)).toList();
  }
}
