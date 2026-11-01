import AVFoundation
import Combine

/// Owns the capture session, feeds camera frames to the detector and
/// publishes the results for the UI.
final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    /// Latest detections, in Vision's normalized coordinates.
    @Published private(set) var detections: [Detection] = []
    /// Size of the (upright, portrait) frames the detections refer to.
    @Published private(set) var imageSize: CGSize = .zero
    @Published private(set) var permissionDenied = false
    @Published private(set) var detectorName = ""

    private let sessionQueue = DispatchQueue(label: "CameraManager.session")
    private let videoQueue = DispatchQueue(label: "CameraManager.video", qos: .userInitiated)
    private let detector = ObjectDetector()
    private var isConfigured = false

    override init() {
        super.init()
        detectorName = detector.name
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { self.configureAndRun() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.sessionQueue.async { self.configureAndRun() }
                } else {
                    DispatchQueue.main.async { self.permissionDenied = true }
                }
            }
        default:
            permissionDenied = true
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    // MARK: - Setup (runs on sessionQueue)

    private func configureAndRun() {
        if !isConfigured {
            configureSession()
        }
        if isConfigured && !session.isRunning {
            session.startRunning()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            print("CameraManager: no usable back camera")
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: videoQueue)

        guard session.canAddOutput(output) else {
            print("CameraManager: cannot add video output")
            return
        }
        session.addOutput(output)

        // Deliver frames upright in portrait so detection coordinates line up
        // with what the preview shows.
        if let connection = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        isConfigured = true
    }
}

// MARK: - Frame handling

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
                          height: CVPixelBufferGetHeight(pixelBuffer))

        // Runs synchronously on videoQueue; frames that arrive while we are
        // busy are dropped (alwaysDiscardsLateVideoFrames), keeping it real-time.
        let results = detector.detect(in: pixelBuffer)

        DispatchQueue.main.async {
            self.imageSize = size
            self.detections = results
        }
    }
}
