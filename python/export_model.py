# ==========================================
# MSRF MODEL EXPORT SCRIPT FOR FLUTTER APP
# ==========================================
# Uses m2cgen to convert Random Forests to pure Dart code
# 
# INSTALL FIRST: pip install m2cgen
# ==========================================

import joblib
import json
import numpy as np
import os
from scipy.special import logsumexp
from sklearn.base import BaseEstimator, ClassifierMixin
from sklearn.ensemble import RandomForestClassifier
from sklearn.cluster import KMeans

# ==========================================
# MSRF_Classifier Class Definition (needed for joblib.load)
# ==========================================
class MSRF_Classifier(BaseEstimator, ClassifierMixin):
    def __init__(self, n_states=3, n_iter=10, rf_params=None, n_estimators=50, max_depth=10, 
                 tol=1e-3, verbose=True, mode='confidence', random_state=None):
        self.n_states = n_states
        self.n_iter = n_iter
        self.rf_params = rf_params
        self.n_estimators = n_estimators
        self.max_depth = max_depth
        self.tol = tol
        self.verbose = verbose
        self.mode = mode.lower()
        self.random_state = random_state
        
        self.experts = [] 
        self.startprob_ = None 
        self.transmat_ = None  
        self.monitor_ = []
    
    def _init_params(self, X, y):
        if self.verbose:
            print(f"[Init] MSRF Initialized in '{self.mode}' mode.")
        kmeans = KMeans(n_clusters=self.n_states, n_init=10, random_state=42)
        labels = kmeans.fit_predict(X)
        trans_counts = np.zeros((self.n_states, self.n_states))
        for t in range(len(labels) - 1):
            curr_state = labels[t]
            next_state = labels[t+1]
            trans_counts[curr_state, next_state] += 1
        self.transmat_ = trans_counts / (trans_counts.sum(axis=1, keepdims=True) + 1e-10)
        start_counts = np.bincount(labels, minlength=self.n_states)
        self.startprob_ = start_counts / start_counts.sum()
        self.experts = []
        for i in range(self.n_states):
            if self.rf_params is not None:
                rf = RandomForestClassifier(**self.rf_params)
            else:
                rf = RandomForestClassifier(
                    n_estimators=self.n_estimators, 
                    max_depth=self.max_depth,
                    random_state=None, 
                    class_weight='balanced', 
                    n_jobs=-1
                )
            rf.fit(X, y) 
            self.experts.append(rf)
        if self.verbose:
            print(f"[Init] MSRF Initialized in '{self.mode}' mode.")

    def _get_expert_confidence(self, X):
        n_samples = len(X)
        scores = np.zeros((n_samples, self.n_states))
        if self.mode == 'confidence':
            for k, expert in enumerate(self.experts):
                all_tree_preds = np.array([tree.predict(X) for tree in expert.estimators_])
                variance = np.var(all_tree_preds, axis=0)
                scores[:, k] = 1.0 / (variance + 1e-5)
        elif self.mode == 'risk':
            state_prototypes = np.linspace(0, 1, self.n_states)
            for k, expert in enumerate(self.experts):
                risk_pred = expert.predict_proba(X)[:, 1]
                distance = np.abs(risk_pred - state_prototypes[k])
                scores[:, k] = np.exp(-distance * 5)
        else:
            raise ValueError(f"Unknown mode: {self.mode}")
        row_sums = scores.sum(axis=1, keepdims=True)
        return scores / (row_sums + 1e-10)

    def _forward_backward(self, log_emissions, lengths):
        n_samples = log_emissions.shape[0]
        gamma = np.zeros((n_samples, self.n_states))
        xi_sum = np.zeros((self.n_states, self.n_states))
        log_start = np.log(self.startprob_ + 1e-10)
        log_trans = np.log(self.transmat_ + 1e-10)
        total_log_likelihood = 0
        cursor = 0
        for length in lengths:
            log_B = log_emissions[cursor : cursor + length]
            log_alpha = np.zeros((length, self.n_states))
            log_alpha[0] = log_start + log_B[0]
            for t in range(1, length):
                for j in range(self.n_states):
                    log_alpha[t, j] = logsumexp(log_alpha[t-1] + log_trans[:, j]) + log_B[t, j]
            total_log_likelihood += logsumexp(log_alpha[-1])
            log_beta = np.zeros((length, self.n_states))
            for t in range(length - 2, -1, -1):
                for i in range(self.n_states):
                    log_beta[t, i] = logsumexp(log_trans[i, :] + log_B[t+1] + log_beta[t+1])
            log_gamma = log_alpha + log_beta
            log_gamma -= logsumexp(log_gamma, axis=1, keepdims=True)
            gamma[cursor : cursor + length] = np.exp(log_gamma)
            for t in range(length - 1):
                log_xi = np.zeros((self.n_states, self.n_states))
                for i in range(self.n_states):
                    for j in range(self.n_states):
                        log_xi[i, j] = log_alpha[t, i] + log_trans[i, j] + log_B[t+1, j] + log_beta[t+1, j]
                log_xi -= logsumexp(log_xi)
                xi_sum += np.exp(log_xi)
            cursor += length
        return gamma, xi_sum, total_log_likelihood

    def fit(self, X_input, y_input):
        if isinstance(X_input, list):
            X_flat = np.vstack(X_input)
            y_flat = np.concatenate(y_input)
            lengths = [len(x) for x in X_input]
        else:
            X_flat = X_input
            y_flat = y_input
            lengths = [len(X_input)]
        self._init_params(X_flat, y_flat)
        self.monitor_ = []
        prev_log_likelihood = -np.inf
        if self.verbose:
            print(f"\n[MSRF] Starting EM Loop ({self.mode} mode)...")
        for i in range(self.n_iter):
            expert_confidences = self._get_expert_confidence(X_flat)
            log_emissions = np.log(expert_confidences + 1e-10)
            gamma, xi_sum, curr_log_likelihood = self._forward_backward(log_emissions, lengths)
            self.monitor_.append(curr_log_likelihood)
            delta = curr_log_likelihood - prev_log_likelihood
            if self.verbose:
                print(f"   -> Iteration {i+1}: LL={curr_log_likelihood:.4f}, Delta={delta:.4f}")
            if i > 1 and abs(delta) < self.tol:
                if self.verbose: print("   [Converged] Stopping early.")
                break
            prev_log_likelihood = curr_log_likelihood
            self.transmat_ = xi_sum / xi_sum.sum(axis=1, keepdims=True)
            for k in range(self.n_states):
                weights = gamma[:, k]
                if np.sum(weights) > 1e-5:
                    self.experts[k].fit(X_flat, y_flat, sample_weight=weights)
        return self

    def predict_proba(self, X_input):
        if isinstance(X_input, list):
            X_flat = np.vstack(X_input)
            lengths = [len(x) for x in X_input]
        else:
            X_flat = X_input
            lengths = [len(X_input)]
        expert_confidences = self._get_expert_confidence(X_flat)
        log_emissions = np.log(expert_confidences + 1e-10)
        gamma, _, _ = self._forward_backward(log_emissions, lengths)
        final_risk_prob = np.zeros(len(X_flat))
        for k in range(self.n_states):
            expert_risk = self.experts[k].predict_proba(X_flat)[:, 1]
            final_risk_prob += gamma[:, k] * expert_risk
        return np.vstack([1 - final_risk_prob, final_risk_prob]).T

    def predict(self, X_input):
        probs = self.predict_proba(X_input)
        return (probs[:, 1] > 0.5).astype(int)

# Try to import m2cgen
try:
    import m2cgen as m2c
    M2CGEN_AVAILABLE = True
except ImportError:
    M2CGEN_AVAILABLE = False
    print("⚠️  m2cgen not installed. Run: pip install m2cgen")

# ==========================================
# CONFIGURATION - PATHS (relative to project root)
# ==========================================
# Get project root (parent of python folder)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

DEPLOY_DIR = os.path.join(PROJECT_ROOT, "assets")
MODEL_PATH = os.path.join(DEPLOY_DIR, "models", "model_MSRF.joblib")
INPUT_PATH = os.path.join(DEPLOY_DIR, "data", "sample_input.csv")
OUTPUT_DIR = os.path.join(DEPLOY_DIR, "exports")
DART_OUTPUT_DIR = os.path.join(PROJECT_ROOT, "lib", "models", "generated")

# Create output directories
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(DART_OUTPUT_DIR, exist_ok=True)

print("=" * 60)
print(" MSRF MODEL EXPORT FOR FLUTTER (m2cgen)")
print("=" * 60)

# ==========================================
# 1. LOAD MODEL AND DATA
# ==========================================
print("\n[1] Loading model and data...")

try:
    model = joblib.load(MODEL_PATH)
    print(f"    ✓ Model loaded: {type(model).__name__}")
    print(f"    → Mode: {model.mode}")
    print(f"    → States: {model.n_states}")
    print(f"    → Experts: {len(model.experts)}")
except Exception as e:
    print(f"    ✗ Failed to load model: {e}")
    exit(1)

try:
    X_test = np.loadtxt(INPUT_PATH, delimiter=",")
    if X_test.ndim == 1:
        X_test = X_test.reshape(1, -1)
    print(f"    ✓ Input data loaded: {X_test.shape[0]} samples, {X_test.shape[1]} features")
except Exception as e:
    print(f"    ✗ Failed to load input data: {e}")
    exit(1)

# ==========================================
# 2. EXPORT RANDOM FORESTS TO DART (m2cgen)
# ==========================================
print("\n[2] Converting Random Forests to Dart code...")

if M2CGEN_AVAILABLE:
    for idx, expert in enumerate(model.experts):
        print(f"    → Converting Expert {idx}...")
        
        # Generate Dart code for this expert
        dart_code = m2c.export_to_dart(expert, function_name=f"predictExpert{idx}")
        
        # Save to file
        dart_path = os.path.join(DART_OUTPUT_DIR, f"expert_{idx}.dart")
        with open(dart_path, "w") as f:
            f.write(f"// Auto-generated by m2cgen - Expert {idx}\n")
            f.write(f"// DO NOT EDIT MANUALLY\n\n")
            f.write(dart_code)
        
        size_kb = os.path.getsize(dart_path) / 1024
        print(f"    ✓ Expert {idx} saved: {dart_path} ({size_kb:.1f} KB)")
else:
    print("    ✗ Skipping Dart export (m2cgen not installed)")

# ==========================================
# 3. EXPORT HMM PARAMETERS
# ==========================================
print("\n[3] Exporting HMM parameters...")

try:
    hmm_params = {
        "model_type": "MSRF_Classifier",
        "n_states": model.n_states,
        "mode": model.mode,
        "n_features": X_test.shape[1],
        
        # HMM Parameters
        "startprob": model.startprob_.tolist() if model.startprob_ is not None else None,
        "transmat": model.transmat_.tolist() if model.transmat_ is not None else None,
    }
    
    # Save to JSON
    params_path = os.path.join(OUTPUT_DIR, "hmm_params.json")
    with open(params_path, "w") as f:
        json.dump(hmm_params, f, indent=2)
    
    print(f"    ✓ HMM parameters saved: {params_path}")
    print(f"    → Start probabilities: {[f'{p:.4f}' for p in hmm_params['startprob']]}")
    print(f"    → Transition matrix shape: {len(hmm_params['transmat'])}x{len(hmm_params['transmat'][0])}")
    
except Exception as e:
    print(f"    ✗ Failed to export HMM parameters: {e}")
    import traceback
    traceback.print_exc()

# ==========================================
# 4. GENERATE PREDICTIONS (for validation)
# ==========================================
print("\n[4] Generating predictions for validation...")

try:
    # Get probability predictions
    proba = model.predict_proba(X_test)
    predictions = model.predict(X_test)
    
    # Save predictions
    pred_path = os.path.join(OUTPUT_DIR, "predictions.csv")
    np.savetxt(pred_path, predictions, delimiter=",", fmt='%d')
    print(f"    ✓ Predictions saved: {pred_path}")
    
    # Save probabilities
    proba_path = os.path.join(OUTPUT_DIR, "probabilities.csv")
    np.savetxt(proba_path, proba[:, 1], delimiter=",", fmt='%.6f')
    print(f"    ✓ Probabilities saved: {proba_path}")
    
    # Summary
    risk_count = np.sum(predictions)
    print(f"    → Risk predictions: {risk_count}/{len(predictions)} ({100*risk_count/len(predictions):.1f}%)")
    
except Exception as e:
    print(f"    ✗ Failed to generate predictions: {e}")

# ==========================================
# 5. EXPORT GROUND TRUTH LABELS (IF AVAILABLE)
# ==========================================
print("\n[5] Ground truth labels...")
print("    ⚠ You need to export y_test labels from your notebook.")
print("    Add this code where y_test is defined:")
print()
print("    np.savetxt('assets/exports/labels.csv', y_test_h_sel[:1000], delimiter=',', fmt='%d')")
print()

# ==========================================
# 6. SUMMARY
# ==========================================
print("\n" + "=" * 60)
print(" EXPORT COMPLETE")
print("=" * 60)

print("""
Files created:
├── lib/models/generated/
│   ├── expert_0.dart    (Random Forest Expert 0)
│   ├── expert_1.dart    (Random Forest Expert 1)  
│   └── expert_2.dart    (Random Forest Expert 2)
├── assets/exports/
│   ├── hmm_params.json  (HMM transition/start probabilities)
│   ├── predictions.csv  (Pre-computed predictions for validation)
│   └── probabilities.csv (Risk probabilities)

Model structure:
- {} HMM states with '{}' switching mode
- {} Random Forest experts
- {} trees per expert
- {} input features

Next steps:
1. Export ground truth labels (see code above)
2. The Flutter app will:
   - Import expert_*.dart files directly
   - Load hmm_params.json for HMM logic
   - Run TRUE on-device inference!
""".format(
    model.n_states,
    model.mode,
    len(model.experts),
    len(model.experts[0].estimators_) if model.experts else 0,
    X_test.shape[1]
))
