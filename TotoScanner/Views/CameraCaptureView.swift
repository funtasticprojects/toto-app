//
//  CameraCaptureView.swift
//  TotoScanner
//
//  Created by mu on 5/4/25.
//

import SwiftUI
import AVFoundation

struct CameraCaptureView: View {
    @Binding var capturedImage: UIImage?
    @Binding var isPresented: Bool

    @StateObject private var cameraService = CameraService()
    @State private var showConfirmation = false
    @State private var previewImage: UIImage? = nil

    var body: some View {
        ZStack {
            CameraPreview(session: cameraService.session, videoPreviewLayer: $cameraService.previewLayer)
                .ignoresSafeArea()

            GeometryReader { geometry in
                let width = geometry.size.width * 0.7
                let height = width
                let x = (geometry.size.width - width) / 2
                let y = (geometry.size.height - height) / 2
                let cropRect = CGRect(x: x, y: y, width: width, height: height)

                // Crop Frame Overlay with Instruction and Animation
                ZStack(alignment: .top) {
                    Rectangle()
                        .path(in: cropRect)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, dash: [10]))
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: cropRect)

                    Text("📏 Align your ticket within the box")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.top, cropRect.minY - 30)
                }

                VStack {
                    Spacer()
                    Button(action: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            cameraService.capturePhoto(cropRect: cropRect, viewSize: geometry.size) { image in
                                DispatchQueue.main.async {
                                    previewImage = image
                                }
                            }
                        }
                    }) {
                        Text("📸 Take Photo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            cameraService.startSession()
        }
        .onDisappear {
            cameraService.stopSession()
        }
        .sheet(isPresented: $showConfirmation) {
            VStack(spacing: 20) {
                Text("Preview")
                    .font(.headline)

                if let previewImage = previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .cornerRadius(10)

                    HStack(spacing: 30) {
                        Button("Retake") {
                            showConfirmation = false
                        }

                        Button("Use Photo") {
                            capturedImage = previewImage
                            showConfirmation = false
                            isPresented = false
                        }
                    }
                } else {
                    ProgressView("Processing Image...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .padding()
        }
        .onChange(of: previewImage) { newImage in
            if newImage != nil {
                showConfirmation = true
            }
        }
    }
}

// MARK: - Camera Preview Wrapper
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    @Binding var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        DispatchQueue.main.async {
            videoPreviewLayer = previewLayer
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Camera Service
class CameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    private var latestCropRect: CGRect?
    private var latestViewSize: CGSize?
    @Published var previewLayer: AVCaptureVideoPreviewLayer?

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        session.beginConfiguration()

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            print("❌ Failed to setup camera input")
            return
        }

        if session.canAddOutput(output) {
            session.addInput(input)
            session.addOutput(output)
            session.sessionPreset = .photo
        }

        session.commitConfiguration()
    }

    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capturePhoto(cropRect: CGRect, viewSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        latestCropRect = cropRect
        latestViewSize = viewSize
        photoCaptureCompletion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let fullImage = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.photoCaptureCompletion?(nil)
            }
            return
        }

        let fixedImage = fixOrientation(of: fullImage)

        guard let cropRect = latestCropRect,
              let viewSize = latestViewSize else {
            DispatchQueue.main.async {
                self.photoCaptureCompletion?(fixedImage)
            }
            return
        }

        let imageSize = fixedImage.size
        let scaleX = imageSize.width / viewSize.width
        let scaleY = imageSize.height / viewSize.height

        let scaledCropRect = CGRect(
            x: cropRect.origin.x * scaleX,
            y: cropRect.origin.y * scaleY,
            width: cropRect.size.width * scaleX,
            height: cropRect.size.height * scaleY
        )

        let safeCropRect = scaledCropRect.intersection(CGRect(origin: .zero, size: imageSize))

        DispatchQueue.main.async {
            if let cgImage = fixedImage.cgImage,
               let croppedCGImage = cgImage.cropping(to: safeCropRect) {
                let croppedUIImage = UIImage(cgImage: croppedCGImage, scale: fixedImage.scale, orientation: fixedImage.imageOrientation)
                self.photoCaptureCompletion?(croppedUIImage)
            } else {
                self.photoCaptureCompletion?(fixedImage)
            }
        }
    }

    private func fixOrientation(of image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? image
    }
}
