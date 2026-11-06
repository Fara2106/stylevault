import CoreGraphics
import Vision

public enum Joint: CaseIterable, Hashable, Sendable {
    case nose, neck, leftShoulder, rightShoulder, leftHip, rightHip
    case leftKnee, rightKnee, leftAnkle, rightAnkle

    fileprivate var visionName: VNHumanBodyPoseObservation.JointName {
        switch self {
        case .nose: return .nose
        case .neck: return .neck
        case .leftShoulder: return .leftShoulder
        case .rightShoulder: return .rightShoulder
        case .leftHip: return .leftHip
        case .rightHip: return .rightHip
        case .leftKnee: return .leftKnee
        case .rightKnee: return .rightKnee
        case .leftAnkle: return .leftAnkle
        case .rightAnkle: return .rightAnkle
        }
    }
}

public struct Pose: Sendable {
    /// Punti in pixel, origine in alto a sinistra.
    public let points: [Joint: CGPoint]

    public init(points: [Joint: CGPoint]) { self.points = points }
}

/// Punti del corpo con VNDetectHumanBodyPoseRequest (posa 2D di iOS).
public enum BodyPose {
    static let minimumConfidence: Float = 0.3

    public static func detect(_ image: CGImage) async throws -> Pose? {
        try await Task.detached(priority: .userInitiated) {
            let request = VNDetectHumanBodyPoseRequest()
            try VNImageRequestHandler(cgImage: image).perform([request])
            guard let observation = request.results?.first else { return nil }
            let width = CGFloat(image.width), height = CGFloat(image.height)
            var points = [Joint: CGPoint]()
            for joint in Joint.allCases {
                guard let point = try? observation.recognizedPoint(joint.visionName),
                      point.confidence >= minimumConfidence else { continue }
                // Vision: normalizzato con origine in basso a sinistra
                points[joint] = CGPoint(x: point.location.x * width, y: (1 - point.location.y) * height)
            }
            return points.isEmpty ? nil : Pose(points: points)
        }.value
    }
}
