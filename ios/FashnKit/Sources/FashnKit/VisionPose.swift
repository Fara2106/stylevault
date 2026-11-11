import CoreGraphics
import Foundation
import Vision

/// La posa con Apple Vision al posto di DWPose: corpo, mani e viso, nel formato che `PoseSketch` disegna.
public enum VisionPose {
    /// Sotto questa confidenza un punto non conta, come nell'originale (`KEYPOINT_VISIBILITY_THRESHOLD`).
    static let minimumConfidence: Float = 0.3

    /// I 18 punti di OpenPose con i nomi di Vision. Il collo si calcola a parte, come fa DWPose: metà tra le spalle.
    static let bodyJoints: [VNHumanBodyPoseObservation.JointName?] = [
        .nose, nil, .rightShoulder, .rightElbow, .rightWrist, .leftShoulder, .leftElbow, .leftWrist,
        .rightHip, .rightKnee, .rightAnkle, .leftHip, .leftKnee, .leftAnkle, .rightEye, .leftEye, .rightEar, .leftEar,
    ]

    static let handJoints: [VNHumanHandPoseObservation.JointName] = [
        .wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip, .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip, .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip,
    ]

    public static func detect(_ image: CGImage) throws -> PoseKeypoints {
        let width = CGFloat(image.width), height = CGFloat(image.height)
        // Vision: coordinate da 0 a 1 con l'origine in basso a sinistra
        func pixel(_ location: CGPoint) -> CGPoint { CGPoint(x: location.x * width, y: (1 - location.y) * height) }

        let bodyRequest = VNDetectHumanBodyPoseRequest()
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2
        let faceRequest = VNDetectFaceLandmarksRequest()
        try VNImageRequestHandler(cgImage: image).perform([bodyRequest, handRequest, faceRequest])

        var pose = PoseKeypoints()
        // Con più persone vale quella che occupa più spazio, come nell'originale
        let bodies = (bodyRequest.results ?? []).map { observation -> [CGPoint?] in
            bodyJoints.map { name in
                guard let name, let point = try? observation.recognizedPoint(name), point.confidence > minimumConfidence else { return nil }
                return pixel(point.location)
            }
        }
        if var body = bodies.max(by: { area($0) < area($1) }) {
            if let right = body[2], let left = body[5] { body[1] = CGPoint(x: (right.x + left.x) / 2, y: (right.y + left.y) / 2) }
            pose.body = body
        }

        pose.hands = (handRequest.results ?? []).map { observation in
            handJoints.map { name in
                guard let point = try? observation.recognizedPoint(name), point.confidence > minimumConfidence else { return nil }
                return pixel(point.location)
            }
        }

        if let face = (faceRequest.results ?? []).max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }),
           let points = face.landmarks?.allPoints {
            pose.face = points.pointsInImage(imageSize: CGSize(width: width, height: height)).map { CGPoint(x: $0.x, y: height - $0.y) }
        }
        return pose
    }

    private static func area(_ body: [CGPoint?]) -> CGFloat {
        let points = body.compactMap { $0 }
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return 0 }
        return (maxX - minX) * (maxY - minY)
    }
}
