import CoreGraphics

/// Il riquadro della persona da dare al modello: tutta la figura con un po' di margine, in proporzione 2:3 come il modello.
public enum PersonFraming {
    public static func frame(imageWidth: Int, imageHeight: Int, body: CGRect) -> CGRect {
        let image = CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        guard !body.isEmpty else { return image }
        let margin = body.height * 0.08
        var height = min(body.height + 2 * margin, image.height)
        var width = max(body.width + 2 * margin, height * 2 / 3)
        if width > image.width {
            width = image.width
            height = min(image.height, max(height, width * 3 / 2))
        }
        let x = min(max(body.midX - width / 2, 0), image.width - width)
        let y = min(max(body.midY - height / 2, 0), image.height - height)
        return CGRect(x: x, y: y, width: width, height: height).integral.intersection(image)
    }

    public static func cropped(_ image: CGImage, around body: CGRect) -> CGImage {
        image.cropping(to: frame(imageWidth: image.width, imageHeight: image.height, body: body)) ?? image
    }
}
