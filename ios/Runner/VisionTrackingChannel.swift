import Flutter
import UIKit

public class VisionTrackingChannel: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var isTracking = false
    private var selectedPersonId: String = "primary_user_1"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.skillverse.ai/vision_tracking", binaryMessenger: registrar.messenger())
        let instance = VisionTrackingChannel()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initializePoseLandmarker", "processCameraFrame":
            result(FlutterError(
                code: "IOS_POSE_UNSUPPORTED",
                message: "Real iOS MediaPipe pose inference is not implemented in Phase 3.",
                details: ["status": "UNSUPPORTED_VIEW", "demoOnly": true]
            ))

        case "startBodyTracking":
            self.isTracking = true
            result(["status": "tracking_started", "nativeVisionAvailable": false])

        case "stopBodyTracking":
            self.isTracking = false
            result(["status": "tracking_stopped"])

        case "selectPrimaryPerson":
            if let args = call.arguments as? [String: Any], let personId = args["personId"] as? String {
                self.selectedPersonId = personId
                result(["status": "person_selected", "selectedPersonId": personId])
            } else {
                result(FlutterError(code: "INVALID_ARG", message: "personId required", details: nil))
            }
            
        case "getJointData":
            result([
                "schemaVersion": "1.0",
                "coordinateSpace": "normalized_image",
                "humanDetected": false,
                "trackingState": "TRACKING_LOST",
                "trackingConfidence": 0.0,
                "multiplePeopleCount": 0,
                "selectedPersonId": selectedPersonId,
                "landmarks": [],
                "joints": [:],
                "reason": "iOS pose inference is unsupported in this build."
            ])

        default:
            result(FlutterMethodNotImplemented)
        }
    }

}
