// Decision Tree Classifier Wrapper

import 'base_classifier.dart';
import 'generated/decision_tree.dart' as dt;

class DecisionTreeClassifier implements BaseClassifier {
  @override
  String get modelName => 'Decision Tree';
  
  @override
  String get modelDescription => 'Simple decision tree classifier with fast inference';
  
  @override
  Future<void> initialize() async {
    // No initialization needed for Decision Tree
  }
  
  @override
  int predictSingle(List<double> features) {
    // Decision Tree returns [prob_class_0, prob_class_1]
    List<double> probs = dt.predictDecisionTree(features);
    return probs[1] > probs[0] ? 1 : 0;
  }
  
  @override
  List<int> predictBatch(List<List<double>> samples) {
    return samples.map((s) => predictSingle(s)).toList();
  }
}
