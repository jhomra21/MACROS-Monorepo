import AVFoundation

@MainActor
struct FoodCameraTorch {
    private let device: AVCaptureDevice?

    init() {
        let preferred = AVCaptureDevice.userPreferredCamera
        if let preferred, preferred.position == .back {
            device = preferred
            return
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        device = discovery.devices.first
    }

    var isAvailable: Bool {
        guard let device else { return false }
        return device.hasTorch && device.isTorchAvailable
    }

    mutating func set(on: Bool) {
        guard isAvailable, let device else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.torchMode = on ? .on : .off
        } catch {
            self = FoodCameraTorch(device: nil)
        }
    }

    private init(device: AVCaptureDevice?) {
        self.device = device
    }
}
