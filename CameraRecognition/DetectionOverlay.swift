import SwiftUI

/// Draws a box and a text label for each detection on top of the camera preview.
struct DetectionOverlay: View {
    let detections: [Detection]
    /// Size of the analyzed frames, used to match the preview's aspect-fill crop.
    let imageSize: CGSize

    private static let palette: [Color] = [.green, .yellow, .orange, .pink, .cyan, .purple, .red, .blue]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(detections) { detection in
                    let rect = viewRect(for: detection.boundingBox, in: geometry.size)
                    let color = Self.color(for: detection.label)

                    Rectangle()
                        .stroke(color, lineWidth: 3)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)

                    Text("\(detection.label) \(Int(detection.confidence * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(color)
                        .fixedSize()
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }

    /// Converts a Vision rect (normalized, bottom-left origin) into view
    /// coordinates, accounting for the preview's aspect-fill scaling and crop.
    private func viewRect(for box: CGRect, in viewSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2

        return CGRect(
            x: box.minX * scaledWidth + offsetX,
            y: (1 - box.maxY) * scaledHeight + offsetY,
            width: box.width * scaledWidth,
            height: box.height * scaledHeight
        )
    }

    /// Same label always gets the same color.
    private static func color(for label: String) -> Color {
        let sum = label.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }
}
