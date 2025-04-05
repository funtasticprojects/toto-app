//
//  CameraCaptureView.swift
//  TotoScanner
//
//  Created by mu on 5/4/25.
//

import SwiftUI
import AVFoundation

struct CameraCaptureView: View {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool

    @StateObject private var cameraService = CameraService()
    @State private var showConfirmation = false
    @State private var previewImage: UIImage? = nil

    var body: some View {
        ZStack {
            CameraPreview(session: cameraService.session)
                .ignoresSafeArea()

            // Crop Frame Overlay
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

                // Capture Button
                VStack {
                    Spacer()
                    Button(action: {
                        cameraService.capturePhoto(cropRect: cropRect, viewSize: geometry.size) { image in
                            if let image = image {
                                previewImage = image
                                showConfirmation = true
                            } else {
                                isPresented = false
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
            if let previewImage = previewImage {
                VStack(spacing: 20) {
                    Text("Preview")
                        .font(.headline)

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
                            selectedImage = previewImage
                            showConfirmation = false
                            isPresented = false
                        }
                    }
                    .padding()
                }
                .padding()
            }
        }
    }
}

// MARK: - Camera Preview Wrapper
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
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
    
    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        session.beginConfiguration()

        // Use back camera
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
            photoCaptureCompletion?(nil)
            return
        }

        let fixedImage = fixOrientation(of: fullImage)

        if let cropRect = latestCropRect, let viewSize = latestViewSize {
            let imageSize = fixedImage.size

            let cropXRatio = cropRect.origin.x / viewSize.width
            let cropYRatio = cropRect.origin.y / viewSize.height
            let cropWidthRatio = cropRect.size.width / viewSize.width
            let cropHeightRatio = cropRect.size.height / viewSize.height

            let scaledCropRect = CGRect(
                x: cropXRatio * imageSize.width,
                y: cropYRatio * imageSize.height,
                width: cropWidthRatio * imageSize.width,
                height: cropHeightRatio * imageSize.height
            )

            if let cgImage = fixedImage.cgImage,
               let croppedCGImage = cgImage.cropping(to: scaledCropRect) {
                let croppedUIImage = UIImage(cgImage: croppedCGImage, scale: fixedImage.scale, orientation: fixedImage.imageOrientation)
                photoCaptureCompletion?(croppedUIImage)
            } else {
                photoCaptureCompletion?(fixedImage)
            }
        } else {
            photoCaptureCompletion?(fixedImage)
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
