import SwiftUI
import AVFoundation

struct CameraScannerView: View {
    let mode: ScanMode
    @Environment(\.dismiss) var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var showingResult = false
    @State private var scanResult: ScanResult?
    @State private var isProcessing = false
    @State private var showingManualEntry = false
    @State private var detectedText: String = ""
    @State private var isScanning = false
    @State private var scanTimer: Timer?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                VStack(spacing: 24) {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.7), lineWidth: 3)
                        .frame(width: UIScreen.main.bounds.width * 0.7, height: UIScreen.main.bounds.height * 0.4)
                        .overlay(
                            VStack(spacing: 12) {
                                Text("Align shoe tag within frame")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                if !detectedText.isEmpty {
                                    VStack(spacing: 8) {
                                        Text("Detected:")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.yellow)
                                        
                                        Text(detectedText)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.yellow)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.black.opacity(0.7))
                                            )
                                    }
                                }
                                
                                if isScanning {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("Scanning...")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                            }
                        )
                    
                    if !detectedText.isEmpty {
                        Button(action: confirmDetection) {
                            Text("Confirm Detection")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.green)
                                )
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    HStack(spacing: 40) {
                        Button(action: { showingManualEntry = true }) {
                            Text("Manual Entry")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.bottom, 60)
            }
            
            if isProcessing {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Analyzing tag...")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showingResult) {
            if let result = scanResult {
                ScanResultView(result: result, mode: mode)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
        .onAppear {
            cameraManager.startSession()
            startContinuousScanning()
        }
        .onDisappear {
            cameraManager.stopSession()
            scanTimer?.invalidate()
            scanTimer = nil
        }
    }
    
    private func startContinuousScanning() {
        scanTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            performScan()
        }
    }
    
    private func performScan() {
        guard !isScanning && !isProcessing else { return }
        
        isScanning = true
        
        cameraManager.capturePhoto { image in
            guard let image = image else {
                Task { @MainActor in
                    isScanning = false
                }
                return
            }
            
            Task {
                await detectText(from: image)
            }
        }
    }
    
    private func detectText(from image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            await MainActor.run {
                isScanning = false
            }
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        
        do {
            let apiResult = try await APIManager.shared.detectShoeTag(imageData: base64Image)
            
            await MainActor.run {
                if let style = apiResult.styleNumber, let color = apiResult.color {
                    detectedText = "\(style) - \(color)"
                } else if let style = apiResult.styleNumber {
                    detectedText = style
                } else {
                    detectedText = ""
                }
                isScanning = false
            }
        } catch {
            await MainActor.run {
                isScanning = false
            }
        }
    }
    
    private func confirmDetection() {
        guard !detectedText.isEmpty else { return }
        
        isProcessing = true
        scanTimer?.invalidate()
        
        cameraManager.capturePhoto { image in
            guard let image = image else {
                Task { @MainActor in
                    isProcessing = false
                    startContinuousScanning()
                }
                return
            }
            
            Task {
                let result = await processImage(image)
                await MainActor.run {
                    scanResult = result
                    isProcessing = false
                    showingResult = true
                }
            }
        }
    }
    
    private func processImage(_ image: UIImage) async -> ScanResult {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return ScanResult(styleNumber: nil, color: nil, confidence: 0, status: .drop, message: "Failed to process image")
        }
        
        let base64Image = imageData.base64EncodedString()
        
        do {
            let apiResult = try await APIManager.shared.detectShoeTag(imageData: base64Image)
            
            if let style = apiResult.styleNumber, let color = apiResult.color {
                let lookupResult = try await APIManager.shared.lookupStyle(styleNumber: style, color: color)
                return ScanResult(
                    styleNumber: style,
                    color: color,
                    confidence: apiResult.confidence,
                    status: ItemStatus(rawValue: lookupResult.status) ?? .drop,
                    message: lookupResult.message,
                    division: lookupResult.division,
                    gender: lookupResult.gender,
                    availableColors: lookupResult.colors
                )
            } else {
                return ScanResult(styleNumber: nil, color: nil, confidence: apiResult.confidence, status: .drop, message: "Could not detect tag clearly")
            }
        } catch {
            return ScanResult(styleNumber: nil, color: nil, confidence: 0, status: .drop, message: "Network error: \(error.localizedDescription)")
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = cameraManager.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Update if needed
    }
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        session.sessionPreset = .high
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
    }
    
    func startSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }
    
    func stopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
            }
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCaptureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoCaptureCompletion?(nil)
            return
        }
        
        photoCaptureCompletion?(image)
    }
}

enum ScanMode {
    case salesRep
    case coordinator
    case catalogBuilder
}

struct ScanResult {
    let styleNumber: String?
    let color: String?
    let confidence: Double
    let status: ItemStatus
    let message: String
    var division: String?
    var gender: String?
    var availableColors: [String]?
}
