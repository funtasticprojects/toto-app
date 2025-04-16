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
    private var previewSize: CGSize?

    @Published var previewLayer: AVCaptureVideoPreviewLayer?

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
        previewSize = viewSize
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

        let normalizedCropRect = previewLayer.metadataOutputRectConverted(fromLayerRect: cropRect)
        let imageSize = fixedImage.size

        let scaledCropRect = CGRect(
            x: normalizedCropRect.origin.x * imageSize.width,
            y: normalizedCropRect.origin.y * imageSize.height,
            width: normalizedCropRect.size.width * imageSize.width,
            height: normalizedCropRect.size.height * imageSize.height
        ).intersection(CGRect(origin: .zero, size: imageSize))

        if let cgImage = fixedImage.cgImage,
           let cropped = cgImage.cropping(to: scaledCropRect) {
            let result = UIImage(cgImage: cropped, scale: fixedImage.scale, orientation: fixedImage.imageOrientation)
            photoCaptureCompletion?(result)
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
