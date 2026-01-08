# PPG Health Data Collection App

A Flutter mobile application for collecting PPG (Photoplethysmography) data and health information for research purposes.

## Features

- **Health Information Collection**: Age, BMI, and scalable additional health parameters
- **PPG Measurement**: Camera-based heart rate detection using phone's camera and flashlight  
- **Local Data Storage**: SQLite database for storing measurements locally
- **Data History**: View and manage collected measurements
- **Research-Ready**: Designed for feeding data to AI stroke prediction models

## Project Structure

```
lib/
├── models/
│   ├── health_data.dart       # Health information data model
│   └── ppg_data.dart         # PPG measurement data model
├── services/
│   ├── database_service.dart  # Local SQLite database operations
│   └── ppg_service.dart      # PPG measurement and signal processing
├── screens/
│   ├── home_screen.dart      # Main app screen
│   ├── health_info_screen.dart # Health data input form
│   ├── ppg_measurement_screen.dart # PPG measurement interface
│   └── data_history_screen.dart   # View collected data
└── main.dart                 # App entry point
```

## Setup Instructions

### Prerequisites

1. Flutter SDK installed
2. Android development environment set up
3. Physical Android device (camera access required for PPG)

### Important Setup Steps

#### 1. Enable Developer Mode (Required for Windows)
- Open Windows Settings
- Run: `start ms-settings:developers`
- Enable "Developer Mode" to support symlinks

#### 2. Path Considerations
If your project path contains spaces (like "Mann lee"), you may encounter build issues. Consider:
- Moving the project to a path without spaces (e.g., `C:\thesis-app`)
- Or using short path names

#### 3. Android SDK Configuration
The app requires Android SDK 36 and NDK 27.0.12077973. These are automatically configured in the build.gradle.kts file.

### Installation

1. Clone or download the project
2. Navigate to the project directory:
   ```bash
   cd thesis-app
   ```

3. Enable Developer Mode (see above)

4. Get Flutter dependencies:
   ```bash
   flutter pub get
   ```

5. Connect an Android device with USB debugging enabled

6. Run the app:
   ```bash
   flutter run
   ```

## Usage Instructions

### Taking a PPG Measurement

1. **Enter Health Information**
   - Open the app and tap "Start New Measurement"
   - Enter your age, weight, and height
   - BMI will be calculated automatically

2. **PPG Measurement**
   - Place your fingertip gently over the back camera
   - Ensure your finger covers both the camera lens and flashlight
   - Keep your hand steady during the 30-second measurement
   - Avoid bright external lights

3. **View Results**
   - Heart rate and measurement duration are displayed
   - Data is automatically saved locally
   - Access history through "View Data History"

### Best Practices for PPG Measurement

- Use in a dimly lit room
- Keep the phone steady
- Apply gentle, consistent finger pressure
- Avoid movement during measurement
- Ensure finger fully covers camera and flash

## Data Storage

All data is stored locally using SQLite database:
- **Health Data**: Age, BMI, timestamps, additional parameters
- **PPG Data**: Raw signal values, heart rate, measurement metadata
- **Scalable Design**: Easy to add new health parameters

## Technical Details

### PPG Signal Processing

- Sampling rate: 30 Hz
- Window size: 150 samples (5 seconds)
- Heart rate range: 40-200 BPM
- Simple bandpass filtering and peak detection
- Real-time signal visualization

### Database Schema

**health_data table:**
- id, age, bmi, timestamp, additional_data

**ppg_data table:**
- id, health_data_id, raw_values, heart_rate, duration, timestamp, spo2

### Permissions Required

- `CAMERA`: For PPG measurement
- `FLASHLIGHT`: For illuminating finger during measurement
- `WRITE_EXTERNAL_STORAGE`: For data storage
- `READ_EXTERNAL_STORAGE`: For data access

## Troubleshooting

### Common Issues

1. **Camera Permission Denied**
   - Grant camera permission when prompted
   - Check app permissions in device settings

2. **Build Fails with Path Errors**
   - Move project to path without spaces
   - Enable Developer Mode on Windows

3. **PPG Measurement Not Working**
   - Ensure finger covers camera completely
   - Use in dimly lit environment
   - Check camera permissions

4. **No Heart Rate Detected**
   - Apply gentle, steady pressure
   - Keep finger still during measurement
   - Ensure good contact with camera

### Performance Tips

- Restart app if camera becomes unresponsive
- Clear app data to reset database if needed
- Use on devices with rear-facing flash for best results

## Future Enhancements

- Additional health parameters (blood pressure, smoking status, etc.)
- Remote database synchronization
- Advanced PPG signal analysis
- Export functionality for research data
- Integration with AI stroke prediction models

## Development Notes

This is a research prototype designed for data collection purposes. The PPG measurement algorithm uses basic signal processing techniques suitable for initial data gathering. For production use, consider more sophisticated algorithms and validation against medical-grade devices.
