# 🩺 Smartphone PPG Medical AI: Pipeline Documentation

This documentation provides a comprehensive walkthrough of the PPG-based Medical AI Pipeline. This system is designed to take raw sensor data from a wearable device and predict patient health risks while ensuring the AI is efficient enough to run on a mobile processor.

---

## 1. Data Loading & Clinical Labeling
**Function:** `ClinicalDataManager`
The pipeline begins by acting as a **"Medical Record Librarian."**

* **The `TAU` Rule:** It calculates a clinical risk score for each patient based on static data (Age, Diabetes, BMI, etc.).
* **Binary Classification:** If a patient has $\ge$ `TAU` (default is 2) risk factors, they are labeled **Class 1 (High Risk)**. Otherwise, they are **Class 0 (Stable)**.
* **Demographic Analysis:** It ensures the dataset is balanced so the AI doesn't become biased toward one specific group.

---

## 2. Signal Processing & Feature Extraction
**Function:** `FeatureExtractor.process_file`
Before the AI can "think," it needs to turn "noisy waves" into clean numbers.

* **Bandpass Filtering:** Raw PPG data is messy. The code filters the signal to keep only the 0.5Hz–3.0Hz range, removing electrical noise and slow body movements.
* **Quality Control (The Bouncer):** * **SNR (Signal-to-Noise Ratio):** If the heart signal is too "fuzzy" compared to the background noise, the window is discarded.
    * **Motion Threshold:** If the accelerometer shows the user was moving their arm too much, the data is ignored to prevent "garbage in, garbage out."
* **Windowing:** The 100Hz signal is sliced into **60-second windows** with a 30-second overlap (stride).
* **Feature Math:** It extracts time-domain (HRV, RMSSD) and morphological features (the "shape" of the heart pulse like Rise Time and Area).



---

## 3. Statistical Feature Selection
**Class:** `StatisticalFeatureSelector`
To prevent the AI from getting confused by "noisy" or redundant data, this class performs two major checks:

1.  **Redundancy Check (Pearson Correlation):** If two features are 90% identical (e.g., Pulse Width and Pulse Area), it drops one to keep the model lean.
2.  **Relevance Check (P-Values):** It performs statistical tests (**Chi-Square** for categories or **Mann-Whitney U** for numbers). 
    * If a feature's **p-value is < 0.05**, it means that feature is a "significant" predictor of health risk.
    * Features that don't pass this test are dropped.



---

## 4. The Model Tournament (Cross-Validation)
**Function:** `Main Execution Loop`
The pipeline holds a competition between six different AI "athletes" to see which handles PPG data best.

* **Grouped Cross-Validation:** The code uses `StratifiedGroupKFold`. This ensures that data from the **same patient** is never in the training set and the testing set at the same time. This proves the AI works on "total strangers."
* **The Models:**
    * **LogReg:** The simple, interpretable baseline.
    * **Random Forest / XGBoost:** Advanced "Decision Tree" models that find complex patterns.
    * **MSRF:** A specialized "Multi-State" model for sequential data.
    * **LSTM:** A Deep Learning Neural Network that understands the "rhythm" of the heart over time.

---

## 5. Smartphone Efficiency Metrics
**Function:** `measure_smartphone_metrics`
Since this is for a phone/watch, we measure the "Physical Cost" of each AI model:

* **Latency (ms):** How many milliseconds it takes to make one prediction.
* **Storage (KB):** The file size of the model.
* **Inf RAM (KB):** The peak memory usage while the AI is running.

---

## 6. Optimization & Final Grading
**Functions:** `calculate_metrics` & `Post-Processing`
The final step is to move beyond simple accuracy and optimize for medical safety.

* **Threshold Optimization:** Most AI uses a "50/50" coin flip for decisions. This code tests **1,000 different threshold steps** (0.001 to 0.999) to find the "Sweet Spot" that maximizes the **F1-Score**.
* **Bootstrapping:** It re-calculates results 1,000 times to create **95% Confidence Intervals**. This proves the results aren't just a "lucky" fluke.
* **Key Metrics:**
    * **Recall:** How many of the high-risk patients did we successfully catch?
    * **Specificity:** How good are we at not bothering healthy people with false alarms?
    * **MCC:** A single score from -1 to +1 that determines the overall quality of the prediction.



---

### How to interpret the results:
The pipeline saves an `optimized_results.csv` and several charts.
- **Top F1-Score:** The best overall balance of Precision and Recall.
- **Low Latency:** Necessary if you want "Real-Time" heart monitoring on a smartwatch.
- **Confusion Matrix:** Look for the **"False Stable (DANGER)"** box. In a medical context, we want this number to be as close to zero as possible.