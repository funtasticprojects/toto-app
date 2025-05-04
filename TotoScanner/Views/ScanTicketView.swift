//
//  ScanTicketView.swift
//  TotoScanner
//
//  Created by mu on 22/3/25.
//
import SwiftUI
import SwiftSoup
import Vision
import Accelerate


struct ScanTicketView: View {
    @EnvironmentObject var viewModel: TOTOViewModel
    @State private var isShowingPhotoLibrary = false
    @State private var isShowingCamera = false
    @State private var finalResult: String? = nil
    
    @State private var capturedImage: UIImage? = nil

    @State private var recognizedText: [String] = []
    @State private var totoTicketType: TotoType? = nil
    
    @State private var debugPreprocessedImage: UIImage? = nil
    @State private var contrastLevel: Double = 3
    
    @State private var hueMin: Float = 10
    @State private var hueMax: Float = 25
    @State private var brightnessThreshold: Float = 0.60
    @State private var saturationThreshold: Float = 1


    
    var body: some View {
        VStack(spacing: 20) {
            if let selectedImage = capturedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                
                
                if let debugImage = debugPreprocessedImage {
                    VStack(spacing: 8) {
                        Text("🔍 Preprocessed Image for OCR")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Image(uiImage: debugImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .border(Color.red, width: 1)
                        
                        // 🔧 Contrast Slider
                        VStack {
                            Text("Contrast: \(String(format: "%.2f", contrastLevel))")
                            Slider(value: $contrastLevel, in: 0.5...3.0, step: 0.1)
                                .padding(.horizontal)
                                .onChange(of: contrastLevel) { _ in
                                    if let original = capturedImage {
                                        debugPreprocessedImage = preprocessForOCR(original)
                                    }
                                }
                        }
                        Group {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("🎛 Brightness Threshold: \(String(format: "%.2f", brightnessThreshold))")
                                Slider(value: $brightnessThreshold, in: 0.0...1.0, step: 0.05)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("🎛 Saturation Threshold: \(String(format: "%.2f", saturationThreshold))")
                                Slider(value: $saturationThreshold, in: 0.0...1.0, step: 0.05)
                            }
                        }
                        .padding(.horizontal)
                        .onChange(of: brightnessThreshold) { _ in
                            if let original = capturedImage {
                                debugPreprocessedImage = preprocessForOCR(original)
                            }
                        }
                        .onChange(of: saturationThreshold) { _ in
                            if let original = capturedImage {
                                debugPreprocessedImage = preprocessForOCR(original)
                            }
                        }
                    }
                }
                
                
                
                Button("Run OCR") {
                    print("running ORC")
                    if let original = capturedImage {
                        print("before applyVImageThreshold")
                        let preprocessed = preprocessForOCR(original) ?? original
                        print("after applyVImageThreshold")
                        debugPreprocessedImage = preprocessed //
                        print("after preprocessing")
                        
                        runOCR(on: preprocessed) { result in
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
            ImagePicker(selectedImage: $capturedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureView(capturedImage: $capturedImage, isPresented: $isShowingCamera)
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
        
        if let type = totoTicketType {
            print("totoTicketType: \(type.rawValue)")
        } else {
            finalResult = "Unable to process the ticket "
            return
        }

        let numOfSet = (totoTicketType == .ordinary) ? 6 : 7
        let sets = extractNumberSets(from: strs, expectedCount: numOfSet)
        print("sets: \(sets)")
        
        // Fallback if no sets found
        if sets.isEmpty {
            finalResult = "OCR failed :( please retake the photo"
            return
        }
        
        
        
        if let drawIndex = strs.firstIndex(of: "DRAW:"),
           recognizedText.count > drawIndex + 2 {
            let drawDateString = recognizedText[drawIndex + 2] // e.g., "31/03/25"
            print("🗓 Draw date = \(drawDateString)")
                
        
        let nums = sets.first ?? []
        

        let winningNumbers = viewModel.selectedWinningNumber?.winningNumbers ?? []
        let additionalNumber = viewModel.selectedWinningNumber?.additionalNumber ?? -1

        let res: Int? = {
            switch totoTicketType {
            case .ordinary:
                return checkOrdinaryTotoResult(winningNumbers: winningNumbers, additionalNumber: additionalNumber, userNumbers: nums)
            case .system7:
                return checkSystem7TotoResult(winningNumbers: winningNumbers, additionalNumber: additionalNumber, userNumbers: nums)
            default:
                return nil
            }
        }()

            
        if (res == nil) {
            finalResult = "you won nothing :("
        } else {
            finalResult = "you won \(res!.description)!"
        }
    }
    

    func extractNumberSets(from text: [String], expectedCount: Int) -> [[Int]] {
        var results: [[Int]] = []
        var current: [Int] = []
        var collecting = false

        for token in text {
            let upperToken = token.uppercased()

            // Early-stop keywords
            let stopWords = ["PRICE:", "DRAW:", "QP"]

            // Detect and split merged label+number, like "A.23", "1.45"
            if let match = token.range(of: #"^([A-Za-z0-9])\.(\d+)$"#, options: .regularExpression) {
                if !current.isEmpty, current.count == expectedCount {
                    results.append(current)
                }
                current = []
                collecting = true
                let numberPart = String(token[match].split(separator: ".")[1])
                if let num = Int(numberPart) {
                    current.append(num)
                }
                continue
            }

            // New line like "A.", "B.", "1."
            if token.count == 2 && token.last == "." &&
                (token.first?.isLetter == true || token.first?.isNumber == true) {
                if current.count == expectedCount {
                    results.append(current)
                }
                current = []
                collecting = true
                continue
            }

            // STOP collecting if we hit a known keyword
            if collecting && stopWords.contains(upperToken) {
                collecting = false
                if current.count == expectedCount {
                    results.append(current)
                }
                current = []
                continue
            }

            if collecting, let num = Int(token) {
                current.append(num)
                if current.count == expectedCount {
                    results.append(current)
                    current = []
                    collecting = false
                }
            }
        }

        // Final check at end
        if current.count == expectedCount {
            results.append(current)
        }

        return results
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


    func preprocessForOCR(_ image: UIImage) -> UIImage? {
        if let cleaned = removeColorPixelsExceptBlack(from: image, brightnessThreshold: brightnessThreshold, saturationThreshold: saturationThreshold) {
            return enhanceContrast(cleaned, contrast: contrastLevel)
        }
        return nil
    }




    
    
    func removeColorPixelsExceptBlack(from image: UIImage, brightnessThreshold: Float = 0.4, saturationThreshold: Float = 0.3) -> UIImage? {
        guard let inputCGImage = image.cgImage else { return nil }
        let width = inputCGImage.width
        let height = inputCGImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let buffer = context.data else { return nil }

        let pixelBuffer = buffer.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = Float(pixelBuffer[offset])
                let g = Float(pixelBuffer[offset + 1])
                let b = Float(pixelBuffer[offset + 2])

                var h: Float = 0, s: Float = 0, v: Float = 0
                rgbToHsv(r: r, g: g, b: b, h: &h, s: &s, v: &v)

                // Keep only dark, desaturated pixels (i.e. black or dark gray)
                if v > brightnessThreshold || s > saturationThreshold {
                    pixelBuffer[offset + 0] = 255 // R
                    pixelBuffer[offset + 1] = 255 // G
                    pixelBuffer[offset + 2] = 255 // B
                }
            }
        }

        guard let outputCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
    }


    
    func rgbToHsv(r: Float, g: Float, b: Float, h: inout Float, s: inout Float, v: inout Float) {
        let r = r / 255, g = g / 255, b = b / 255
        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        v = maxVal
        let delta = maxVal - minVal
        s = maxVal == 0 ? 0 : delta / maxVal

        if delta == 0 {
            h = 0
        } else if maxVal == r {
            h = (g - b) / delta
        } else if maxVal == g {
            h = 2 + (b - r) / delta
        } else {
            h = 4 + (r - g) / delta
        }

        h *= 60
        if h < 0 { h += 360 }
    }



    

    
    
    
    func removeWatermarkHueFilter(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // Step 1: Convert to HSV equivalent via CIHueAdjust (mock effect for targeting hue range)
        let hueFilter = CIFilter(name: "CIHueAdjust")
        hueFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        hueFilter?.setValue(0, forKey: kCIInputAngleKey) // no hue shift

        guard let adjustedHue = hueFilter?.outputImage else { return nil }

        // Step 2: Reduce watermark hue by applying a color matrix (low saturation in reddish tone)
        let colorMatrix = CIFilter(name: "CIColorMatrix")!
        colorMatrix.setValue(adjustedHue, forKey: kCIInputImageKey)

        // Dim reddish tones: target R-heavy areas
        colorMatrix.setValue(CIVector(x: 0.3, y: -0.2, z: -0.1, w: 0), forKey: "inputRVector")
        colorMatrix.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
        colorMatrix.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
        colorMatrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")

        guard let filtered = colorMatrix.outputImage else { return nil }

        // Step 3: Convert to UIImage
        let context = CIContext()
        if let cgImage = context.createCGImage(filtered, from: filtered.extent) {
            return UIImage(cgImage: cgImage)
        }

        return nil
    }


    
    
    
    
    
    


    func enhanceContrast(_ image: UIImage, contrast: Double) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(0.0, forKey: kCIInputSaturationKey)
        filter?.setValue(0.0, forKey: kCIInputBrightnessKey)
        filter?.setValue(contrast, forKey: kCIInputContrastKey)

        let context = CIContext()
        guard let output = filter?.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }


    func removeRedWatermark(from image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // Step 1: Desaturate but keep luminance
        let desaturated = ciImage.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 1.0, // keep saturation initially
            kCIInputBrightnessKey: 0.0,
            kCIInputContrastKey: 1.0
        ])

        // Step 2: Extract red/orange hue mask
        let hueMask = desaturated.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": 64,
            "inputCubeData": generateHueMaskCubeData(),
            "inputColorSpace": CGColorSpaceCreateDeviceRGB()
        ])

        // Step 3: Blend by dimming the watermark
        let blend = CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputBackgroundImageKey: desaturated,
            kCIInputMaskImageKey: hueMask
        ])?.outputImage

        // Step 4: Convert back to UIImage
        if let result = blend {
            let context = CIContext()
            if let cgImage = context.createCGImage(result, from: result.extent) {
                return UIImage(cgImage: cgImage)
            }
        }

        return nil
    }
    
    func generateHueMaskCubeData() -> Data {
        let size = 64
        var cubeData = [Float](repeating: 0, count: size * size * size * 4)

        for z in 0..<size {
            for y in 0..<size {
                for x in 0..<size {
                    let offset = ((z * size * size) + (y * size) + x) * 4
                    let r = Float(x) / Float(size - 1)
                    let g = Float(y) / Float(size - 1)
                    let b = Float(z) / Float(size - 1)

                    // Convert to HSV
                    let maxVal = max(r, g, b)
                    let minVal = min(r, g, b)
                    let delta = maxVal - minVal
                    var hue: Float = 0

                    if delta != 0 {
                        if maxVal == r {
                            hue = (g - b) / delta
                        } else if maxVal == g {
                            hue = 2 + (b - r) / delta
                        } else {
                            hue = 4 + (r - g) / delta
                        }
                        hue *= 60
                        if hue < 0 { hue += 360 }
                    }

                    // Alpha mask: keep reddish hues (hue ~ 0-30 or 330-360)
                    let isRedHue = (hue < 30 || hue > 330)
                    let alpha: Float = isRedHue ? 1.0 : 0.0

                    cubeData[offset + 0] = r
                    cubeData[offset + 1] = g
                    cubeData[offset + 2] = b
                    cubeData[offset + 3] = alpha
                }
            }
        }

        return Data(buffer: UnsafeBufferPointer(start: &cubeData, count: cubeData.count))
    }


    




    func applyVImageThreshold(_ image: UIImage, threshold: UInt8) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        // Set format for input image
        var format = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: nil,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )

        // Initialize source buffer
        var sourceBuffer = vImage_Buffer()
        defer { free(sourceBuffer.data) }

        guard vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, cgImage, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return nil
        }

        let width = Int(sourceBuffer.width)
        let height = Int(sourceBuffer.height)
        let count = width * height

        // Allocate planar R, G, B buffers
        var r = [UInt8](repeating: 0, count: count)
        var g = [UInt8](repeating: 0, count: count)
        var b = [UInt8](repeating: 0, count: count)
        var gray = [UInt8](repeating: 0, count: count)

        r.withUnsafeMutableBytes { rPtr in
            g.withUnsafeMutableBytes { gPtr in
                b.withUnsafeMutableBytes { bPtr in
                    var red = vImage_Buffer(data: rPtr.baseAddress!, height: sourceBuffer.height, width: sourceBuffer.width, rowBytes: width)
                    var green = vImage_Buffer(data: gPtr.baseAddress!, height: sourceBuffer.height, width: sourceBuffer.width, rowBytes: width)
                    var blue = vImage_Buffer(data: bPtr.baseAddress!, height: sourceBuffer.height, width: sourceBuffer.width, rowBytes: width)

                    vImageConvert_RGB888toPlanar8(
                        &sourceBuffer, &red, &green, &blue,
                        vImage_Flags(kvImageNoFlags)
                    )
                }
            }
        }

        // Convert to grayscale by averaging RGB
        for i in 0..<count {
            gray[i] = UInt8((UInt16(r[i]) + UInt16(g[i]) + UInt16(b[i])) / 3)
        }

        // Apply threshold
        let binarized = gray.map { $0 >= threshold ? UInt8(255) : UInt8(0) }

        // Create output CGImage
        let providerRef = CGDataProvider(data: NSData(bytes: binarized, length: count) as CFData)!

        let cgResult = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: providerRef,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )

        return cgResult.map { UIImage(cgImage: $0) }
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
