import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Setup method channel for memory measurement
    let controller = window?.rootViewController as! FlutterViewController
    let memoryChannel = FlutterMethodChannel(
      name: "com.msrf_app/memory",
      binaryMessenger: controller.binaryMessenger
    )
    
    memoryChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getMemoryUsage" {
        let memoryBytes = self.getMemoryUsage()
        result(memoryBytes)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  /// Get current memory usage (RSS) in bytes using iOS task_info
  private func getMemoryUsage() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    
    if result == KERN_SUCCESS {
      return Int64(info.resident_size)
    }
    return -1
  }
}
