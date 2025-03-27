//
//  ScanTicketView.swift
//  TotoScanner
//
//  Created by mu on 22/3/25.
//
import SwiftUI
import SwiftSoup
import Vision


struct ScanTicketView: View {
    @EnvironmentObject var viewModel: TOTOViewModel
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingCamera = false
    @State private var selectedImage: UIImage?
    @State private var finalResult: String? = nil
    
    @State private var recognizedText: [String] = []
    @State private var totoTicketType: TotoType? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                
                Button("Run OCR") {
                    runOCR(on: selectedImage) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let recognizedStrings):
                                self.recognizedText = recognizedStrings
                                processRecognizedText(recognizedText: recognizedStrings)
                            case .failure(let error):
                                self.recognizedText.removeAll()
                                finalResult = error.localizedDescription
                            }
                        }
                    }
                }
                .padding()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 300)
                    .overlay(Text("No Image Selected"))
            }
            
            HStack {
                Button("Pick from Photo Library") {
                    isShowingPhotoLibrary = true
                }
                .padding()

                Button("Take Photo") {
                    isShowingCamera = true
                }
                .padding()
            }

            if let finalResult = finalResult {
                Text(finalResult)
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $isShowingPhotoLibrary) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraWithOverlayView(selectedImage: $selectedImage, isPresented: $isShowingCamera)
        }
    }
    
    func processRecognizedText(recognizedText: [String]) {
        var strs: [String] = []
        for text in recognizedText {
            strs += text.split(separator: " ").map{ subString -> String in
                return String(subString)
            }
        }
    
        print(strs)
    
    
        totoTicketType = deriveTotoType(recognizedText: strs)
        if (totoTicketType == nil) {

        }
    
        var nums: [Int] = []
        for str in strs {
            if (isInt(str: str)) {
                nums.append(Int(str)!)
            }
        }
    
    
        print("nums: \(nums)")

        let res = checkOrdinaryTotoResult(winningNumbers: viewModel.latestWinningNumber?.winningNumbers ?? [], additionalNumber:viewModel.latestWinningNumber?.additionalNumber ?? -1, userNumbers: nums)

        if (res == nil) {
            finalResult = "you won nothing :("
        } else {
            finalResult = "you won \(res!.description)!"
        }
    }
    
    
    func isInt(str: String) -> Bool {
        return Int(str) != nil
    }
    
    func deriveTotoType(recognizedText: [String]) -> TotoType? {
        for type in TotoType.allValues {
            if (recognizedText.contains(type.rawValue)) {
                return type
            }
        }
        return nil
    }
    
    func runOCR(on image: UIImage, completion: @escaping (Result<[String], Error>) -> Void) {
        // Convert UIImage to CGImage
        guard let cgImage = image.cgImage else {
            let error = NSError(domain: "runOCRError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
            completion(.failure(error))
            return
        }

        // Create a text recognition request
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                // Pass the error back
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                let error = NSError(domain: "runOCRError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No text observations"])
                completion(.failure(error))
                return
            }

            // Collect recognized strings
            var recognizedStrings: [String] = []
            for observation in observations {
                if let topCandidate = observation.topCandidates(1).first {
                    recognizedStrings.append(topCandidate.string)
                }
            }

            // Success — pass back the recognized text
            completion(.success(recognizedStrings))
        }
    
        // Optional: set recognition level
        request.recognitionLevel = .accurate
    
        // Create the request handler
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    
        // Perform OCR in background
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                // Pass back any Vision errors
                completion(.failure(error))
            }
        }
    }
}
