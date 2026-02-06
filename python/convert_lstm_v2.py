"""
Convert Keras LSTM model to TensorFlow Lite format with maximum compatibility.
Uses a simplified approach to avoid version issues with tflite_flutter.
"""
import tensorflow as tf
import numpy as np
import warnings
import os

warnings.filterwarnings('ignore')
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

def main():
    print("Loading Keras model...")
    original_model = tf.keras.models.load_model('assets/models/model_LSTM.keras')
    
    print("\nOriginal model structure:")
    original_model.summary()
    
    # Get the model's input shape: (None, 1, 26)
    input_shape = original_model.input_shape[1:]  # (1, 26)
    
    print(f"\nInput shape: {input_shape}")
    
    # Create a concrete function with a fixed batch size
    # This helps TFLite convert the model more reliably
    @tf.function(input_signature=[tf.TensorSpec(shape=[1, 1, 26], dtype=tf.float32)])
    def inference(x):
        return original_model(x, training=False)
    
    # Get concrete function
    concrete_func = inference.get_concrete_function()
    
    print("\nConverting to TFLite with concrete function...")
    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
    
    # Use only builtin ops - avoid Select TF ops for maximum compatibility
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    
    # Allow custom ops if needed (for LSTM)
    converter.allow_custom_ops = True
    
    # Try to convert
    try:
        tflite_model = converter.convert()
        tflite_path = 'assets/models/model_LSTM.tflite'
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        
        file_size = os.path.getsize(tflite_path) / 1024
        print(f"\n[SUCCESS] Saved: {tflite_path} ({file_size:.2f} KB)")
        
    except Exception as e:
        print(f"\nBuiltin-only conversion failed: {e}")
        print("\nTrying with Select TF ops...")
        
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS,
            tf.lite.OpsSet.SELECT_TF_OPS
        ]
        
        tflite_model = converter.convert()
        tflite_path = 'assets/models/model_LSTM.tflite'
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        
        file_size = os.path.getsize(tflite_path) / 1024
        print(f"\n[SUCCESS with Flex ops] Saved: {tflite_path} ({file_size:.2f} KB)")
        print("\nNOTE: This model requires tensorflow-lite-select-tf-ops dependency on Android")

if __name__ == "__main__":
    main()
