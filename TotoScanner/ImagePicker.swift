import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    // 1. A binding to store the selected image in the parent view
    @Binding var selectedImage: UIImage?
    
    // 2. A sourceType variable (camera or photo library)
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    // MARK: - UIViewControllerRepresentable Methods
    
    // 3. Create the UIImagePickerController
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    // 4. Update is not used in this case
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    // 5. Create the Coordinator (handles delegate callbacks)
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        // Called when the user picks an image or cancels
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Get the selected image (original or edited). Usually .originalImage is fine
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
