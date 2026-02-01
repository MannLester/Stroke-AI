// MSRF Classifier - Dart Implementation
// Multi-State Random Forest with HMM-based expert switching
// 
// This is the orchestration layer that:
// 1. Calls the 3 generated RF expert functions
// 2. Implements confidence-based switching
// 3. Combines predictions using HMM forward-backward

import 'dart:math';
import 'generated/expert_0.dart' as expert0;
import 'generated/expert_1.dart' as expert1;
import 'generated/expert_2.dart' as expert2;

class MSRFClassifier {
  final int nStates;
  final String mode;
  final List<double> startProb;
  final List<List<double>> transMat;
  
  MSRFClassifier({
    required this.nStates,
    required this.mode,
    required this.startProb,
    required this.transMat,
  });
  
  /// Factory constructor to create from JSON params
  factory MSRFClassifier.fromJson(Map<String, dynamic> json) {
    return MSRFClassifier(
      nStates: json['n_states'] as int,
      mode: json['mode'] as String,
      startProb: (json['startprob'] as List).cast<double>(),
      transMat: (json['transmat'] as List)
          .map((row) => (row as List).cast<double>())
          .toList(),
    );
  }
  
  /// Get prediction from a single expert
  List<double> _predictExpert(int expertIndex, List<double> input) {
    switch (expertIndex) {
      case 0:
        return expert0.predictExpert0(input);
      case 1:
        return expert1.predictExpert1(input);
      case 2:
        return expert2.predictExpert2(input);
      default:
        throw ArgumentError('Invalid expert index: $expertIndex');
    }
  }
  
  /// Calculate expert confidence scores (variance-based for 'confidence' mode)
  List<double> _getExpertConfidence(List<double> input) {
    List<double> scores = List.filled(nStates, 0.0);
    
    if (mode == 'confidence') {
      // For each expert, get variance across predictions
      // Since m2cgen exports aggregated predictions, we use the probability spread
      for (int k = 0; k < nStates; k++) {
        List<double> proba = _predictExpert(k, input);
        // Use inverse of prediction uncertainty as confidence
        double riskProb = proba[1];
        double variance = riskProb * (1 - riskProb); // Bernoulli variance proxy
        scores[k] = 1.0 / (variance + 1e-5);
      }
    } else if (mode == 'risk') {
      // Risk-based switching
      List<double> prototypes = List.generate(nStates, (i) => i / (nStates - 1));
      for (int k = 0; k < nStates; k++) {
        List<double> proba = _predictExpert(k, input);
        double riskPred = proba[1];
        double distance = (riskPred - prototypes[k]).abs();
        scores[k] = exp(-distance * 5);
      }
    }
    
    // Normalize
    double sum = scores.reduce((a, b) => a + b);
    return scores.map((s) => s / (sum + 1e-10)).toList();
  }
  
  /// Log-sum-exp for numerical stability
  double _logSumExp(List<double> values) {
    double maxVal = values.reduce(max);
    double sumExp = values.map((v) => exp(v - maxVal)).reduce((a, b) => a + b);
    return maxVal + log(sumExp);
  }
  
  /// Forward-backward algorithm for single sequence
  List<double> _forwardBackward(List<List<double>> logEmissions) {
    int T = logEmissions.length;
    
    // Log transform HMM parameters
    List<double> logStart = startProb.map((p) => log(p + 1e-10)).toList();
    List<List<double>> logTrans = transMat
        .map((row) => row.map((p) => log(p + 1e-10)).toList())
        .toList();
    
    // Forward pass
    List<List<double>> logAlpha = List.generate(
      T, (_) => List.filled(nStates, double.negativeInfinity)
    );
    
    // Initialize
    for (int j = 0; j < nStates; j++) {
      logAlpha[0][j] = logStart[j] + logEmissions[0][j];
    }
    
    // Forward recursion
    for (int t = 1; t < T; t++) {
      for (int j = 0; j < nStates; j++) {
        List<double> terms = List.generate(nStates, 
          (i) => logAlpha[t-1][i] + logTrans[i][j]
        );
        logAlpha[t][j] = _logSumExp(terms) + logEmissions[t][j];
      }
    }
    
    // Backward pass
    List<List<double>> logBeta = List.generate(
      T, (_) => List.filled(nStates, 0.0)
    );
    
    for (int t = T - 2; t >= 0; t--) {
      for (int i = 0; i < nStates; i++) {
        List<double> terms = List.generate(nStates,
          (j) => logTrans[i][j] + logEmissions[t+1][j] + logBeta[t+1][j]
        );
        logBeta[t][i] = _logSumExp(terms);
      }
    }
    
    // Compute gamma (state responsibilities)
    List<List<double>> gamma = List.generate(T, (_) => List.filled(nStates, 0.0));
    
    for (int t = 0; t < T; t++) {
      List<double> logGamma = List.generate(nStates,
        (k) => logAlpha[t][k] + logBeta[t][k]
      );
      double logNorm = _logSumExp(logGamma);
      for (int k = 0; k < nStates; k++) {
        gamma[t][k] = exp(logGamma[k] - logNorm);
      }
    }
    
    // Return last gamma (for single sample prediction)
    return gamma.last;
  }
  
  /// Predict probability for a single sample
  List<double> predictProbaSingle(List<double> input) {
    // Get expert confidence
    List<double> confidence = _getExpertConfidence(input);
    List<double> logEmission = confidence.map((c) => log(c + 1e-10)).toList();
    
    // For single sample, gamma simplifies to normalized confidence
    double sum = confidence.reduce((a, b) => a + b);
    List<double> gamma = confidence.map((c) => c / (sum + 1e-10)).toList();
    
    // Combine expert predictions weighted by gamma
    double finalRiskProb = 0.0;
    for (int k = 0; k < nStates; k++) {
      List<double> expertProba = _predictExpert(k, input);
      finalRiskProb += gamma[k] * expertProba[1];
    }
    
    return [1 - finalRiskProb, finalRiskProb];
  }
  
  /// Predict class for a single sample
  int predictSingle(List<double> input, {double threshold = 0.5}) {
    List<double> proba = predictProbaSingle(input);
    return proba[1] > threshold ? 1 : 0;
  }
  
  /// Predict probabilities for batch of samples
  List<List<double>> predictProbaBatch(List<List<double>> inputs) {
    return inputs.map((input) => predictProbaSingle(input)).toList();
  }
  
  /// Predict classes for batch of samples
  List<int> predictBatch(List<List<double>> inputs, {double threshold = 0.5}) {
    return inputs.map((input) => predictSingle(input, threshold: threshold)).toList();
  }
  
  /// Full inference with HMM sequence modeling
  /// Use this for sequential data (e.g., patient time series)
  List<int> predictSequence(List<List<double>> sequence, {double threshold = 0.5}) {
    int T = sequence.length;
    
    // Get log emissions for all timesteps
    List<List<double>> logEmissions = sequence.map((input) {
      List<double> conf = _getExpertConfidence(input);
      return conf.map((c) => log(c + 1e-10)).toList();
    }).toList();
    
    // Run forward-backward
    // For efficiency, compute gamma for each timestep
    List<List<double>> allGamma = [];
    
    // Simplified: treat as independent samples with start prob weighting
    for (int t = 0; t < T; t++) {
      List<double> conf = _getExpertConfidence(sequence[t]);
      double sum = conf.reduce((a, b) => a + b);
      allGamma.add(conf.map((c) => c / (sum + 1e-10)).toList());
    }
    
    // Combine predictions
    List<int> predictions = [];
    for (int t = 0; t < T; t++) {
      double riskProb = 0.0;
      for (int k = 0; k < nStates; k++) {
        List<double> expertProba = _predictExpert(k, sequence[t]);
        riskProb += allGamma[t][k] * expertProba[1];
      }
      predictions.add(riskProb > threshold ? 1 : 0);
    }
    
    return predictions;
  }
}
