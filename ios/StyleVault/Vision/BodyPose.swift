import CoreGraphics
import Vision

enum Joint: CaseIterable, Hashable {
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

struct Pose {
    /// Punti in pixel, origine in alto a sinistra.
    let points: [Joint: CGPoint]
}

/// Punti del corpo con VNDetectHumanBodyPoseRequest (posa 2D di iOS).
enum BodyPose {
    static let minimumConfidence: Float = 0.3

    static func detect(_ image: CGImage) async throws -> Pose? {
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
