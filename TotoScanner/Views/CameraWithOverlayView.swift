//
//  CameraWithOverlayView.swift
//  TotoScanner
//
//  Created by mu on 22/3/25.
//

import SwiftUI

struct CameraWithOverlayView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.showsCameraControls = true
        
        // Add overlay frame
        let screenSize = UIScreen.main.bounds
        let overlay = TicketFrameOverlay(frame: CGRect(x: 0, y: 0, width: screenSize.width, height: screenSize.height))
        overlay.isUserInteractionEnabled = false
        overlay.backgroundColor = .clear
        picker.cameraOverlayView = overlay
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraWithOverlayView
        
        init(parent: CameraWithOverlayView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            guard let originalImage = info[.originalImage] as? UIImage else {
                parent.isPresented = false
                return
            }
            
            // Get the crop frame from overlay
            if let overlay = picker.cameraOverlayView as? TicketFrameOverlay {
                let screenSize = UIScreen.main.bounds.size
                let imageSize = originalImage.size
                
                
                let imageAspect = imageSize.width / imageSize.height
                let screenAspect = screenSize.width / screenSize.height
                
                // Calculate what part of the image is visible in the preview
                var visibleImageRect = CGRect.zero
                
                if imageAspect > screenAspect {
                    // Image is wider than screen — left & right are cropped
                    let scale = screenSize.height / imageSize.height
                    let scaledImageWidth = imageSize.width * scale
                    let xOffset = (scaledImageWidth - screenSize.width) / 2 / scale
                    
                    visibleImageRect = CGRect(
                        x: xOffset,
                        y: 0,
                        width: imageSize.width - (2 * xOffset),
                        height: imageSize.height
                    )
                    
                } else {
                    // Image is taller than screen — top & bottom are cropped
                    let scale = screenSize.width / imageSize.width
                    let scaledImageHeight = imageSize.height * scale
                    let yOffset = (scaledImageHeight - screenSize.height) / 2 / scale
                    
                    visibleImageRect = CGRect(
                        x: 0,
                        y: yOffset,
                        width: imageSize.width,
                        height: imageSize.height - (2 * yOffset)
                    )
                }
                
                let cropFrame = overlay.cropFrame
                
                // Translate screen coordinates into visible image rect
                let cropXRatio = cropFrame.origin.x / screenSize.width
                let cropYRatio = cropFrame.origin.y / screenSize.height
                let cropWidthRatio = cropFrame.width / screenSize.width
                let cropHeightRatio = cropFrame.height / screenSize.height
                
                let scaledCropRect = CGRect(
                    x: visibleImageRect.origin.x + (cropXRatio * visibleImageRect.width),
                    y: visibleImageRect.origin.y + (cropYRatio * visibleImageRect.height),
                    width: cropWidthRatio * visibleImageRect.width,
                    height: cropHeightRatio * visibleImageRect.height
                )
                
                if let cgImage = originalImage.cgImage,
                   let croppedCGImage = cgImage.cropping(to: scaledCropRect) {
                    let croppedUIImage = UIImage(cgImage: croppedCGImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
                    parent.selectedImage = croppedUIImage
                } else {
                    parent.selectedImage = originalImage
                }
                
                print("Visible rect in image: \(visibleImageRect)")
                print("Final crop rect: \(scaledCropRect)")
                
                parent.isPresented = false
            }
            
            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                parent.isPresented = false
            }
        }
    }
    
    // MARK: - Ticket Overlay
    
    class TicketFrameOverlay: UIView {
        var cropFrame: CGRect = .zero
        
        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            
            let squareSize = min(rect.width, rect.height) * 0.6
            let x = (rect.width - squareSize) / 2
            let y = (rect.height - squareSize) / 2
            let frameRect = CGRect(x: x, y: y, width: squareSize, height: squareSize)
            self.cropFrame = frameRect
            
            context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
            context.fill(rect)
            context.clear(frameRect)
            
            let pantoneBlue = UIColor(red: 139/255, green: 184/255, blue: 232/255, alpha: 1)
            context.setStrokeColor(pantoneBlue.cgColor)
            context.setLineWidth(4)
            context.stroke(frameRect)
        }
    }
    
}
