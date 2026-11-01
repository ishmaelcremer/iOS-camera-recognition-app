# Camera Recognition (iOS)

A SwiftUI iPhone app that shows the live camera, recognizes the objects it sees,
draws a box around each one and labels it with simple text (name + confidence).

## Run it

1. Open `CameraRecognition.xcodeproj` in Xcode 15 or later.
2. Select the **CameraRecognition** target → **Signing & Capabilities**, choose your
   Team, and change the bundle ID (`com.example.CameraRecognition`) to something unique.
3. Plug in an iPhone (iOS 16+) and press **Run**. Allow camera access when asked.

Use a real device: the Simulator has no camera.

## How recognition works

`ObjectDetector.swift` uses one of two modes, picked automatically at launch:

- **Built-in Apple Vision (default, nothing to download).** Vision's objectness
  saliency finds where objects are, then Vision's built-in image classifier
  (1,000+ categories) names each region.
- **A Core ML object-detection model (more accurate boxes).** Download e.g.
  **YOLOv3Tiny** or **YOLOv3** from <https://developer.apple.com/machine-learning/models/>,
  drag the `.mlmodel` into the `CameraRecognition` group in Xcode (tick the app target),
  and run again. The app finds any compiled model in its bundle and uses it instead.
  The current mode is shown at the bottom of the screen.

## Files

| File | Purpose |
| --- | --- |
| `CameraManager.swift` | Camera session, permission, sends frames to the detector |
| `ObjectDetector.swift` | Vision / Core ML recognition |
| `CameraPreview.swift` | Full-screen live camera view |
| `DetectionOverlay.swift` | Boxes and text labels drawn over the preview |
| `ContentView.swift` | Puts the preview, overlay and status text together |
