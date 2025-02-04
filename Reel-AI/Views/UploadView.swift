import SwiftUI
import AVFoundation
import MobileCoreServices
import UIKit
import Photos

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        guard let session = session else { return view }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

class UploadViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var videoURL: URL?
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var captureSession: AVCaptureSession?
    
    private var videoOutput: AVCaptureMovieFileOutput?
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let audioDevice = AVCaptureDevice.default(for: .audio),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
              let captureSession = captureSession else {
            self.errorMessage = "Failed to setup camera"
            self.showError = true
            return
        }
        
        if captureSession.canAddInput(videoInput) && captureSession.canAddInput(audioInput) {
            captureSession.addInput(videoInput)
            captureSession.addInput(audioInput)
        }
        
        videoOutput = AVCaptureMovieFileOutput()
        if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput else {
            errorMessage = "Camera not ready"
            showError = true
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoPath = documentsPath.appendingPathComponent("\(UUID().uuidString).mov")
        videoOutput.startRecording(to: videoPath, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        videoOutput?.stopRecording()
        isRecording = false
    }
    
    func uploadVideo() {
        guard let videoURL = videoURL else {
            errorMessage = "No video to upload"
            showError = true
            return
        }
        
        isUploading = true
        uploadProgress = 0
        
        MuxAPI.createUploadURL { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let uploadURL):
                    self?.uploadVideoToMux(videoURL: videoURL, uploadURL: uploadURL)
                case .failure(let error):
                    self?.errorMessage = "Failed to create upload URL: \(error.localizedDescription)"
                    self?.showError = true
                    self?.isUploading = false
                }
            }
        }
    }
    
    private func uploadVideoToMux(videoURL: URL, uploadURL: URL) {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("video/quicktime", forHTTPHeaderField: "Content-Type")
        
        let task = session.uploadTask(with: request, fromFile: videoURL) { [weak self] _, _, error in
            DispatchQueue.main.async {
                self?.isUploading = false
                if let error = error {
                    self?.errorMessage = "Error uploading video: \(error.localizedDescription)"
                    self?.showError = true
                } else {
                    // Here you would typically save the video metadata to Firestore
                    self?.videoURL = nil // Clear the video URL after successful upload
                }
            }
        }
        
        task.resume()
    }
}

extension UploadViewModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                self?.errorMessage = "Error recording video: \(error.localizedDescription)"
                self?.showError = true
            } else {
                self?.videoURL = outputFileURL
            }
        }
    }
}

extension UploadViewModel: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        DispatchQueue.main.async {
            self.uploadProgress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        }
    }
}

struct UploadView: View {
    @StateObject private var viewModel = UploadViewModel()
    
    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.captureSession)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        } else {
                            viewModel.startRecording()
                        }
                    }) {
                        Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundColor(viewModel.isRecording ? .red : .white)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    
                    if viewModel.videoURL != nil {
                        Button(action: { viewModel.uploadVideo() }) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Upload")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(viewModel.isUploading)
                    }
                }
                .padding()
            }
            
            if viewModel.isUploading {
                VStack {
                    ProgressView("Uploading...", value: viewModel.uploadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding()
                    Text("\(Int(viewModel.uploadProgress * 100))%")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.5))
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.showError = false }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }
}

