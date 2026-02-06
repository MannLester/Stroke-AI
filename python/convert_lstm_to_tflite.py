"""
Convert Keras LSTM model to TensorFlow Lite format for mobile deployment
"""
import tensorflow as tf
import warnings
import os

warnings.filterwarnings('ignore')
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

def main():
    # Load the Keras model
    print("Loading Keras model...")
    model = tf.keras.models.load_model('assets/models/model_LSTM.keras')
    
    # Convert to TensorFlow Lite
    print("Converting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Enable Select TF ops for LSTM compatibility
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS
    ]
    converter._experimental_lower_tensor_list_ops = False
    
    # Target older TFLite version for compatibility with tflite_flutter
    # Don't use DEFAULT optimization which can produce newer op versions
    # converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Ensure we use float32 (no quantization) for maximum compatibility
    converter.target_spec.supported_types = [tf.float32]
    
    # Convert the model
    tflite_model = converter.convert()
    
    # Save the TFLite model
    tflite_path = 'assets/models/model_LSTM.tflite'
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    
    file_size = os.path.getsize(tflite_path) / 1024
    print(f"[SAVED] LSTM TFLite model -> {tflite_path} ({file_size:.2f} KB)")
    
    # Verify by loading and checking
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print("\n=== TFLite Model Details ===")
    print(f"Input shape: {input_details[0]['shape']}")
    print(f"Input dtype: {input_details[0]['dtype']}")
    print(f"Output shape: {output_details[0]['shape']}")
    print(f"Output dtype: {output_details[0]['dtype']}")

if __name__ == "__main__":
    main()
