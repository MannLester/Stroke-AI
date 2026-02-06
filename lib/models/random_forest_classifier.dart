// Random Forest Classifier Wrapper

import 'base_classifier.dart';
import 'generated/random_forest.dart' as rf;

class RandomForestClassifier implements BaseClassifier {
  @override
  String get modelName => 'Random Forest';
  
  @override
  String get modelDescription => 'Ensemble of decision trees with majority voting';
  
  @override
  Future<void> initialize() async {
    // No initialization needed for Random Forest
  }
  
  @override
  int predictSingle(List<double> features) {
    // Random Forest returns [prob_class_0, prob_class_1]
    List<double> probs = rf.predictRandomForest(features);
    return probs[1] > probs[0] ? 1 : 0;
  }
  
  @override
  List<int> predictBatch(List<List<double>> samples) {
    return samples.map((s) => predictSingle(s)).toList();
  }
}
