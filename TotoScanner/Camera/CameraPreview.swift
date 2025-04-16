//
//  CameraPreview.swift
//  TotoScanner
//
//  Created by mu on 16/4/25.
//

import SwiftUI
import AVFoundation

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
