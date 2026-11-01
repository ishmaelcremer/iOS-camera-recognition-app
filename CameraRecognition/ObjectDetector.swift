import CoreML
import Vision

/// One recognized object.
struct Detection: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    /// Normalized (0...1) rect with the origin at the bottom-left, as Vision reports it.
    let boundingBox: CGRect
}

/// Finds objects in camera frames and names them.
///
/// Two modes:
/// 1. **Core ML model (best results).** If an object-detection model (e.g.
///    Apple's YOLOv3 or YOLOv3Tiny) has been added to the app target, it is
///    used automatically. These models return boxes and labels directly.
/// 2. **Built-in Apple Vision (default, no download needed).** Vision's
///    objectness saliency finds where the objects are, then Vision's built-in
///    image classifier names each one.
final class ObjectDetector {
    let name: String

    private let modelRequest: VNCoreMLRequest?
    private let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest()

    private let modelMinConfidence: Float = 0.4
    private let classifierMinConfidence: Float = 0.15
    private let maxObjects = 4

    init() {
        if let url = Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil)?.first,
           let mlModel = try? MLModel(contentsOf: url),
           let visionModel = try? VNCoreMLModel(for: mlModel) {
            let request = VNCoreMLRequest(model: visionModel)
            request.imageCropAndScaleOption = .scaleFill
            modelRequest = request
            name = url.deletingPathExtension().lastPathComponent
        } else {
            modelRequest = nil
            name = "Apple Vision"
        }
    }

    /// Call from a single background queue. `pixelBuffer` must be upright.
    func detect(in pixelBuffer: CVPixelBuffer) -> [Detection] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        if let modelRequest {
            return detectWithModel(modelRequest, handler: handler)
        }
        return detectWithBuiltInVision(handler: handler)
    }

    // MARK: - Core ML object detector

    private func detectWithModel(_ request: VNCoreMLRequest, handler: VNImageRequestHandler) -> [Detection] {
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        let observations = request.results as? [VNRecognizedObjectObservation] ?? []
        return observations
            .compactMap { observation -> Detection? in
                guard let top = observation.labels.first, top.confidence >= modelMinConfidence else { return nil }
                return Detection(label: Self.prettify(top.identifier),
                                 confidence: top.confidence,
                                 boundingBox: observation.boundingBox)
            }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxObjects * 2)
            .map { $0 }
    }

    // MARK: - Built-in Vision (saliency + classification)

    private func detectWithBuiltInVision(handler: VNImageRequestHandler) -> [Detection] {
        do {
            try handler.perform([saliencyRequest])
        } catch {
            return []
        }

        let boxes = (saliencyRequest.results?.first?.salientObjects ?? [])
            .map(\.boundingBox)
            .filter { $0.width * $0.height > 0.01 } // ignore tiny specks
            .prefix(maxObjects)

        var detections: [Detection] = []
        for box in boxes {
            let classify = VNClassifyImageRequest()
            classify.regionOfInterest = box
            guard (try? handler.perform([classify])) != nil,
                  let best = classify.results?.max(by: { $0.confidence < $1.confidence }),
                  best.confidence >= classifierMinConfidence
            else { continue }

            detections.append(Detection(label: Self.prettify(best.identifier),
                                        confidence: best.confidence,
                                        boundingBox: box))
        }
        return detections
    }

    /// "teddy_bear" -> "Teddy bear"
    private static func prettify(_ identifier: String) -> String {
        let text = identifier
            .split(separator: ",").first.map(String.init)?   // some models use "a, b, c"
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces) ?? identifier
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
