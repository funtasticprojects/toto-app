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
                Text("Preview").font(.headline)

                if let previewImage = previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .cornerRadius(10)
                } else {
                    ProgressView("Processing Image...")
                        .progressViewStyle(CircularProgressViewStyle())
                }

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
