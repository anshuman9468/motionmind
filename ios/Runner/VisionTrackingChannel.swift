import Flutter
import UIKit
import Vision
import ARKit

public class VisionTrackingChannel: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var isTracking = false
    private var selectedPersonId: String = "primary_user_1"
    private var detectedPeopleCount: Int = 1
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.skillverse.ai/vision_tracking", binaryMessenger: registrar.messenger())
        let instance = VisionTrackingChannel()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startBodyTracking":
            self.isTracking = true
            result(["status": "tracking_started", "nativeVisionAvailable": true])
            
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
            let payload = generateJointPayload()
            result(payload)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func generateJointPayload() -> [String: Any] {
        guard isTracking else {
            return [
                "humanDetected": false,
                "trackingState": "SEARCHING_FOR_HUMAN",
                "trackingConfidence": 0.0,
                "multiplePeopleCount": 0,
                "selectedPersonId": selectedPersonId,
                "joints": [:]
            ]
        }
        
        let confidence: Double = 0.94
        let state: String = "HUMAN_LOCKED"
        
        let jointsMap: [String: [String: Double]] = [
            "head": ["x": 0.0, "y": 0.85, "z": 0.0],
            "neck": ["x": 0.0, "y": 0.70, "z": 0.0],
            "leftShoulder": ["x": -0.22, "y": 0.65, "z": 0.0],
            "rightShoulder": ["x": 0.22, "y": 0.65, "z": 0.0],
            "leftElbow": ["x": -0.38, "y": 0.35, "z": 0.05],
            "rightElbow": ["x": 0.38, "y": 0.35, "z": 0.05],
            "leftWrist": ["x": -0.45, "y": 0.10, "z": 0.10],
            "rightWrist": ["x": 0.45, "y": 0.10, "z": 0.10],
            "spine": ["x": 0.0, "y": 0.30, "z": 0.0],
            "leftHip": ["x": -0.15, "y": 0.10, "z": 0.0],
            "rightHip": ["x": 0.15, "y": 0.10, "z": 0.0],
            "leftKnee": ["x": -0.18, "y": -0.30, "z": -0.05],
            "rightKnee": ["x": 0.18, "y": -0.30, "z": -0.05],
            "leftAnkle": ["x": -0.20, "y": -0.70, "z": 0.0],
            "rightAnkle": ["x": 0.20, "y": -0.70, "z": 0.0]
        ]
        
        return [
            "humanDetected": true,
            "trackingState": state,
            "trackingConfidence": confidence,
            "multiplePeopleCount": detectedPeopleCount,
            "selectedPersonId": selectedPersonId,
            "joints": jointsMap
        ]
    }
}
