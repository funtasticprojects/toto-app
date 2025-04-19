//
//  CameraService.swift
//  TotoScanner
//
//  Created by mu on 16/4/25.
//

import AVFoundation
import UIKit

class CameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    private var latestCropRect: CGRect?
    private var latestViewSize: CGSize?
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var lastScaledCropRect: CGRect?

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input), session.canAddOutput(output) else {
            print("Failed to set up camera input/output")
            return
        }

        session.addInput(input)
        session.addOutput(output)
        session.sessionPreset = .photo
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
                let fullImage = UIImage(data: imageData),
                let cropRect = latestCropRect,
                let previewLayer = previewLayer else {
            photoCaptureCompletion?(nil)
            return
        }

        let fixedImage = fixOrientation(of: fullImage)
        let imageSize = fixedImage.size
        let viewSize = previewLayer.frame.size

        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        let scale: CGFloat
        let xOffset: CGFloat
        let yOffset: CGFloat

        if imageAspect > viewAspect {
            scale = imageSize.height / viewSize.height
            let scaledWidth = viewSize.width * scale
            xOffset = (imageSize.width - scaledWidth) / 2
            yOffset = 0
        } else {
            scale = imageSize.width / viewSize.width
            let scaledHeight = viewSize.height * scale
            xOffset = 0
            yOffset = (imageSize.height - scaledHeight) / 2
        }

        let scaledCropRect = CGRect(
            x: cropRect.origin.x * scale + xOffset,
            y: cropRect.origin.y * scale + yOffset,
            width: cropRect.width * scale,
            height: cropRect.height * scale
        )

        let safeCropRect = scaledCropRect.intersection(CGRect(origin: .zero, size: imageSize))
        self.lastScaledCropRect = safeCropRect

        print("🧩 previewLayer.frame = \(previewLayer.frame)")
        print("📱 viewSize: \(viewSize)")
        print("📷 imageSize: \(imageSize)")
        print("📐 scaledCropRect: \(scaledCropRect)")
        print("📐 Crop rect (in view): \(String(describing: latestCropRect))")

        if let cgImage = fixedImage.cgImage,
            let croppedCGImage = cgImage.cropping(to: safeCropRect) {
            let croppedUIImage = UIImage(cgImage: croppedCGImage, scale: fixedImage.scale, orientation: fixedImage.imageOrientation)
            photoCaptureCompletion?(croppedUIImage)
        } else {
            photoCaptureCompletion?(fixedImage)
        }
    }

    private func fixOrientation(of image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let fixed = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return fixed ?? image
    }
}
