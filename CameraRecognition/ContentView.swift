import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraManager()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            DetectionOverlay(detections: camera.detections, imageSize: camera.imageSize)
                .ignoresSafeArea()

            VStack {
                Spacer()
                Text(statusText)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(.bottom, 24)
            }

            if camera.permissionDenied {
                permissionMessage
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    private var statusText: String {
        let count = camera.detections.count
        let objects = count == 1 ? "1 object" : "\(count) objects"
        return "\(objects) · \(camera.detectorName)"
    }

    private var permissionMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.largeTitle)
            Text("Camera access is needed")
                .font(.headline)
            Text("Enable camera access for this app in Settings to start recognizing objects.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundColor(.white)
        .padding(24)
        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
        .padding(32)
    }
}
