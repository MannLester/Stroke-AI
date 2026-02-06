# ==========================================
# EXPORT ALL MODELS TO DART FOR FLUTTER APP
# ==========================================
# Uses m2cgen to convert sklearn/xgboost models to pure Dart code
# 
# INSTALL FIRST: 
#   pip install m2cgen joblib scikit-learn xgboost
# ==========================================

import joblib
import json
import numpy as np
import os
import m2cgen as m2c
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
        pass
    
    def _get_expert_confidence(self, X):
        pass
    
    def _forward_backward(self, log_emissions, lengths):
        pass
    
    def fit(self, X, y, lengths=None):
        pass
    
    def predict(self, X, lengths=None):
        pass
    
    def predict_proba(self, X, lengths=None):
        pass


# ==========================================
# EXPORT FUNCTIONS
# ==========================================

def export_msrf_model(model_path, output_dir):
    """Export MSRF model - exports HMM params and each expert separately"""
    print("\n" + "="*50)
    print("EXPORTING MSRF MODEL")
    print("="*50)
    
    msrf = joblib.load(model_path)
    
    # Export HMM parameters
    hmm_params = {
        'n_states': msrf.n_states,
        'mode': msrf.mode,
        'start_prob': msrf.startprob_.tolist(),
        'trans_mat': msrf.transmat_.tolist()
    }
    
    hmm_path = os.path.join(output_dir, 'hmm_params.json')
    with open(hmm_path, 'w') as f:
        json.dump(hmm_params, f, indent=2)
    print(f"[SAVED] HMM parameters → {hmm_path}")
    
    # Export each expert as Dart
    generated_dir = os.path.join(output_dir, 'generated')
    os.makedirs(generated_dir, exist_ok=True)
    
    for i, expert in enumerate(msrf.experts):
        dart_code = m2c.export_to_dart(expert, function_name=f'predictExpert{i}')
        dart_path = os.path.join(generated_dir, f'expert_{i}.dart')
        with open(dart_path, 'w') as f:
            f.write(dart_code)
        file_size = os.path.getsize(dart_path) / (1024 * 1024)
        print(f"[SAVED] Expert {i} → {dart_path} ({file_size:.2f} MB)")
    
    print(f"[DONE] MSRF model exported with {len(msrf.experts)} experts")
    return True


def export_simple_model(model_path, output_dir, model_name, function_name):
    """Export a simple sklearn model (DecisionTree, LogisticRegression, RandomForest)"""
    print("\n" + "="*50)
    print(f"EXPORTING {model_name.upper()} MODEL")
    print("="*50)
    
    model = joblib.load(model_path)
    
    # Generate Dart code
    dart_code = m2c.export_to_dart(model, function_name=function_name)
    
    # Save to file
    generated_dir = os.path.join(output_dir, 'generated')
    os.makedirs(generated_dir, exist_ok=True)
    
    dart_path = os.path.join(generated_dir, f'{model_name.lower()}.dart')
    with open(dart_path, 'w') as f:
        f.write(dart_code)
    
    file_size = os.path.getsize(dart_path) / 1024  # KB
    if file_size > 1024:
        print(f"[SAVED] {model_name} → {dart_path} ({file_size/1024:.2f} MB)")
    else:
        print(f"[SAVED] {model_name} → {dart_path} ({file_size:.2f} KB)")
    
    return True


def export_xgboost_model(model_path, output_dir):
    """Export XGBoost model"""
    print("\n" + "="*50)
    print("EXPORTING XGBOOST MODEL")
    print("="*50)
    
    model = joblib.load(model_path)
    
    # Generate Dart code
    dart_code = m2c.export_to_dart(model, function_name='predictXGBoost')
    
    # Save to file
    generated_dir = os.path.join(output_dir, 'generated')
    os.makedirs(generated_dir, exist_ok=True)
    
    dart_path = os.path.join(generated_dir, 'xgboost.dart')
    with open(dart_path, 'w') as f:
        f.write(dart_code)
    
    file_size = os.path.getsize(dart_path) / 1024  # KB
    if file_size > 1024:
        print(f"[SAVED] XGBoost → {dart_path} ({file_size/1024:.2f} MB)")
    else:
        print(f"[SAVED] XGBoost → {dart_path} ({file_size:.2f} KB)")
    
    return True


# ==========================================
# MAIN EXECUTION
# ==========================================

if __name__ == "__main__":
    # Paths
    models_dir = "assets/models"
    output_dir = "lib/models"
    
    print("\n" + "="*60)
    print("   MODEL EXPORT SCRIPT FOR FLUTTER APP")
    print("   Converting sklearn/xgboost models to Dart using m2cgen")
    print("="*60)
    
    # Check if models directory exists
    if not os.path.exists(models_dir):
        print(f"\n[ERROR] Models directory not found: {models_dir}")
        print("Please ensure the models are in the assets/models folder")
        exit(1)
    
    # List available models
    print(f"\n[INFO] Scanning {models_dir} for models...")
    available_models = [f for f in os.listdir(models_dir) if f.endswith('.joblib')]
    print(f"[INFO] Found {len(available_models)} models: {available_models}")
    
    # Export each model
    success_count = 0
    
    # 1. MSRF Model
    msrf_path = os.path.join(models_dir, "model_MSRF.joblib")
    if os.path.exists(msrf_path):
        try:
            export_msrf_model(msrf_path, output_dir)
            success_count += 1
        except Exception as e:
            print(f"[ERROR] Failed to export MSRF: {e}")
    
    # 2. Decision Tree
    dt_path = os.path.join(models_dir, "model_DecisionTree.joblib")
    if os.path.exists(dt_path):
        try:
            export_simple_model(dt_path, output_dir, "decision_tree", "predictDecisionTree")
            success_count += 1
        except Exception as e:
            print(f"[ERROR] Failed to export DecisionTree: {e}")
    
    # 3. Logistic Regression
    lr_path = os.path.join(models_dir, "model_LogReg.joblib")
    if os.path.exists(lr_path):
        try:
            export_simple_model(lr_path, output_dir, "logistic_regression", "predictLogisticRegression")
            success_count += 1
        except Exception as e:
            print(f"[ERROR] Failed to export LogisticRegression: {e}")
    
    # 4. Random Forest
    rf_path = os.path.join(models_dir, "model_RandomForest.joblib")
    if os.path.exists(rf_path):
        try:
            export_simple_model(rf_path, output_dir, "random_forest", "predictRandomForest")
            success_count += 1
        except Exception as e:
            print(f"[ERROR] Failed to export RandomForest: {e}")
    
    # 5. XGBoost
    xgb_path = os.path.join(models_dir, "model_XGBoost.joblib")
    if os.path.exists(xgb_path):
        try:
            export_xgboost_model(xgb_path, output_dir)
            success_count += 1
        except Exception as e:
            print(f"[ERROR] Failed to export XGBoost: {e}")
    
    # Summary
    print("\n" + "="*60)
    print(f"   EXPORT COMPLETE: {success_count}/{len(available_models)} models exported")
    print("="*60)
    print("\n[NEXT STEPS]")
    print("1. Check lib/models/generated/ for the Dart files")
    print("2. Run 'flutter pub get' to refresh")
    print("3. Run the Flutter app to test all models")
