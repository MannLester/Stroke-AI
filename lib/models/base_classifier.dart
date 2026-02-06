// Base Classifier Interface
// All model classifiers implement this interface

abstract class BaseClassifier {
  String get modelName;
  String get modelDescription;
  
  /// Initialize the classifier (load any required parameters)
  Future<void> initialize();
  
  /// Predict for a single sample
  /// Returns: 0 = Low Risk, 1 = High Risk
  int predictSingle(List<double> features);
  
  /// Predict for multiple samples
  List<int> predictBatch(List<List<double>> samples);
}
