import 'base_classifier.dart';
import 'generated/xgboost.dart' as xgb;

/// XGBoost classifier wrapper
/// Uses m2cgen-exported XGBoost model
class XGBoostClassifier implements BaseClassifier {
  @override
  String get modelName => 'XGBoost';

  @override
  String get modelDescription =>
      'Gradient Boosting ensemble using decision trees with regularization';

  @override
  Future<void> initialize() async {
    // No initialization needed for m2cgen exported model
  }

  @override
  int predictSingle(List<double> features) {
    // XGBoost binary classifier returns [prob_class_0, prob_class_1]
    final probabilities = xgb.predictXGBoost(features);
    
    // Return class with highest probability
    return probabilities[1] > probabilities[0] ? 1 : 0;
  }

  @override
  List<int> predictBatch(List<List<double>> samples) {
    return samples.map((sample) => predictSingle(sample)).toList();
  }

  /// Get raw probability scores for a sample
  List<double> predictProba(List<double> features) {
    return xgb.predictXGBoost(features);
  }
}
