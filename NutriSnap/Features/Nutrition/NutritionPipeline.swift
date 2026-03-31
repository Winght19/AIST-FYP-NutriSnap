import SwiftUI
import CoreML
import Vision
import UIKit
import Accelerate
import Combine

// MARK: - Nutrition Data Model
struct NutritionData: Equatable {
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var mass: Double
    
    static let zero = NutritionData(calories: 0, protein: 0, carbohydrates: 0, fat: 0, mass: 0)
    
    func scaled(by factor: Double) -> NutritionData {
        return NutritionData(
            calories: calories * factor,
            protein: protein * factor,
            carbohydrates: carbohydrates * factor,
            fat: fat * factor,
            mass: mass * factor
        )
    }
}

// MARK: - Nutrition Estimation State
enum NutritionEstimationState: Equatable {
    case idle
    case calculating
    case completed(NutritionData)
    case error(String)
    
    // Explicit Equatable conformance
    static func == (lhs: NutritionEstimationState, rhs: NutritionEstimationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.calculating, .calculating): return true
        case (.completed(let a), .completed(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Nutrition Estimation Pipeline
class NutritionEstimationPipeline: ObservableObject {
    @Published var state: NutritionEstimationState = .idle
    @Published var nutritionData: NutritionData = .zero
    
    private var segmentationModel: VNCoreMLModel?
    private var regressionModel: MLModel?
    
    // ImageNet normalization constants
    private let imagenetMean: [Float] = [0.485, 0.456, 0.406]
    private let imagenetStd: [Float] = [0.229, 0.224, 0.225]
    
    // Segmentation settings
    private let segImageSize = 320
    
    // Regression settings
    private let regInputSize = 224
    private let regResizeSize = 256
    
    // Segmentation encoder normalization (ResNet34 / ImageNet)
    private let segMean: [Float] = [0.485, 0.456, 0.406]
    private let segStd: [Float] = [0.229, 0.224, 0.225]
    
    init() {
        loadModels()
    }
    
    // MARK: - Load Core ML Models
    private func loadModels() {
        // Load Segmentation model (U-Net with ResNet34 encoder)
        if let segURL = Bundle.main.url(forResource: "segmentation", withExtension: "mlmodelc") ??
            Bundle.main.url(forResource: "segmentation", withExtension: "mlpackage") {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all
                let mlModel = try MLModel(contentsOf: segURL, configuration: config)
                segmentationModel = try VNCoreMLModel(for: mlModel)
                print("✓ Segmentation model loaded successfully")
            } catch {
                print("Error loading segmentation model: \(error)")
            }
        } else {
            print("Segmentation model file not found in bundle")
        }
        
        // Load Regression model (ResNet-101 with SE module)
        if let regURL = Bundle.main.url(forResource: "nutrition_regressor", withExtension: "mlmodelc") ??
            Bundle.main.url(forResource: "nutrition_regressor", withExtension: "mlpackage") {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all
                regressionModel = try MLModel(contentsOf: regURL, configuration: config)
                print("✓ Nutrition regression model loaded successfully")
            } catch {
                print("Error loading regression model: \(error)")
            }
        } else {
            print("Nutrition regression model file not found in bundle")
        }
    }
    
    // MARK: - Main Estimation Pipeline
    @MainActor
    func estimateNutrition(from image: UIImage) async {
        state = .calculating
        
        guard let cgImage = image.cgImage else {
            state = .error("Failed to process image")
            return
        }
        
        do {
            // Step 1: Segment the food from background
            let mask = try await segmentFood(cgImage: cgImage)
            
            // Step 2: Create cutout (food only, background removed)
            let cutout = createCutout(cgImage: cgImage, mask: mask)
            
            // Step 3: Predict nutrition from cutout
            let nutrition = try await predictNutrition(cutoutImage: cutout)
            
            self.nutritionData = nutrition
            self.state = .completed(nutrition)
        } catch {
            self.state = .error("Nutrition estimation failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Step 1: Segmentation
    private func segmentFood(cgImage: CGImage) async throws -> [[Float]] {
        guard let model = segmentationModel else {
            throw NSError(domain: "NutritionPipeline", code: 1, userInfo: [NSLocalizedDescriptionKey: "Segmentation model not loaded"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Try to get the result as a pixel buffer or feature value
                if let results = request.results as? [VNCoreMLFeatureValueObservation],
                   let firstResult = results.first,
                   let multiArray = firstResult.featureValue.multiArrayValue {
                    
                    let height = multiArray.shape[multiArray.shape.count - 2].intValue
                    let width = multiArray.shape[multiArray.shape.count - 1].intValue
                    
                    var mask = [[Float]](repeating: [Float](repeating: 0, count: width), count: height)
                    
                    let pointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: multiArray.count)
                    
                    for h in 0..<height {
                        for w in 0..<width {
                            let index: Int
                            if multiArray.shape.count == 4 {
                                // Shape: [1, 1, H, W]
                                index = h * width + w
                            } else if multiArray.shape.count == 3 {
                                // Shape: [1, H, W]
                                index = h * width + w
                            } else {
                                // Shape: [H, W]
                                index = h * width + w
                            }
                            let value = pointer[index]
                            mask[h][w] = value > 0.5 ? 1.0 : 0.0
                        }
                    }
                    
                    continuation.resume(returning: mask)
                } else if let results = request.results as? [VNPixelBufferObservation],
                          let firstResult = results.first {
                    let pixelBuffer = firstResult.pixelBuffer
                    let mask = self.pixelBufferToMask(pixelBuffer)
                    continuation.resume(returning: mask)
                } else {
                    // Fallback: return all-ones mask (no segmentation)
                    print("⚠️ Could not parse segmentation output, using full image")
                    let h = cgImage.height
                    let w = cgImage.width
                    let mask = [[Float]](repeating: [Float](repeating: 1.0, count: w), count: h)
                    continuation.resume(returning: mask)
                }
            }
            
            request.imageCropAndScaleOption = .scaleFill
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func pixelBufferToMask(_ pixelBuffer: CVPixelBuffer) -> [[Float]] {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var mask = [[Float]](repeating: [Float](repeating: 0, count: width), count: height)
        
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
            
            for y in 0..<height {
                for x in 0..<width {
                    let pixel = buffer[y * bytesPerRow + x]
                    mask[y][x] = pixel > 128 ? 1.0 : 0.0
                }
            }
        }
        
        return mask
    }
    
    // MARK: - Step 2: Create Cutout
    private func createCutout(cgImage: CGImage, mask: [[Float]]) -> CGImage {
        let width = cgImage.width
        let height = cgImage.height
        let maskHeight = mask.count
        let maskWidth = mask.isEmpty ? 0 : mask[0].count
        
        // Create context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return cgImage
        }
        
        // Draw original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else {
            return cgImage
        }
        
        let data = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        // Apply mask - set background pixels to black
        for y in 0..<height {
            for x in 0..<width {
                // Map pixel coordinates to mask coordinates
                let maskY = min(Int(Float(y) * Float(maskHeight) / Float(height)), maskHeight - 1)
                let maskX = min(Int(Float(x) * Float(maskWidth) / Float(width)), maskWidth - 1)
                
                let maskValue = mask[maskY][maskX]
                
                if maskValue < 0.5 {
                    // Background pixel - set to black
                    let offset = (y * width + x) * 4
                    data[offset] = 0     // R
                    data[offset + 1] = 0 // G
                    data[offset + 2] = 0 // B
                    data[offset + 3] = 255 // A
                }
            }
        }
        
        return context.makeImage() ?? cgImage
    }
    
    // MARK: - Step 3: Predict Nutrition
    private func predictNutrition(cutoutImage: CGImage) async throws -> NutritionData {
        guard let model = regressionModel else {
            throw NSError(domain: "NutritionPipeline", code: 2, userInfo: [NSLocalizedDescriptionKey: "Regression model not loaded"])
        }
        
        // Preprocess: Resize to 256, center crop to 224
        let processedImage = preprocessForRegression(cgImage: cutoutImage)
        
        // The CoreML model expects an Image input (not MultiArray).
        // It handles normalization internally (scale/bias baked into the model).
        _ = try cgImageToPixelBuffer(processedImage, width: regInputSize, height: regInputSize)
        
        // Get model input description to find the correct input name
        let inputDescription = model.modelDescription.inputDescriptionsByName
        guard let inputName = inputDescription.keys.first else {
            throw NSError(domain: "NutritionPipeline", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot determine model input name"])
        }
        
        // Create prediction input with image type
        let imageConstraint = inputDescription[inputName]?.imageConstraint
        let featureValue: MLFeatureValue
        if let constraint = imageConstraint {
            featureValue = try MLFeatureValue(cgImage: processedImage, constraint: constraint)
        } else {
            featureValue = try MLFeatureValue(cgImage: processedImage, pixelsWide: regInputSize, pixelsHigh: regInputSize, pixelFormatType: kCVPixelFormatType_32BGRA)
        }
        
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [inputName: featureValue])
        
        // Run prediction
        let output = try await model.prediction(from: inputFeatures)
        
        // Parse output
        let nutrition = parseNutritionOutput(output)
        
        return nutrition
    }
    
    // MARK: - CGImage to CVPixelBuffer
    private func cgImageToPixelBuffer(_ cgImage: CGImage, width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                          kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw NSError(domain: "NutritionPipeline", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer"])
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw NSError(domain: "NutritionPipeline", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext for pixel buffer"])
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
    
    private func preprocessForRegression(cgImage: CGImage) -> CGImage {
        // Step 1: Resize to 256 (shorter side)
        let resized = resizeImage(cgImage, toSize: CGSize(width: regResizeSize, height: regResizeSize))
        
        // Step 2: Center crop to 224x224
        let cropped = centerCrop(resized, toSize: CGSize(width: regInputSize, height: regInputSize))
        
        return cropped
    }
    
    private func resizeImage(_ cgImage: CGImage, toSize size: CGSize) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return cgImage
        }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        return context.makeImage() ?? cgImage
    }
    
    private func centerCrop(_ cgImage: CGImage, toSize size: CGSize) -> CGImage {
        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        
        let cropX = (originalWidth - size.width) / 2.0
        let cropY = (originalHeight - size.height) / 2.0
        
        let cropRect = CGRect(x: cropX, y: cropY, width: size.width, height: size.height)
        
        return cgImage.cropping(to: cropRect) ?? cgImage
    }
    
    
    private func parseNutritionOutput(_ output: MLFeatureProvider) -> NutritionData {
        // The regression model outputs: [total_mass, total_calories, total_fat, total_carb, total_protein]
        let outputNames = output.featureNames
        
        for name in outputNames {
            if let multiArray = output.featureValue(for: name)?.multiArrayValue {
                let count = multiArray.count
                let pointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
                
                if count >= 5 {
                    let mass = max(0, Double(pointer[0]))
                    let calories = max(0, Double(pointer[1]))
                    let fat = max(0, Double(pointer[2]))
                    let carbs = max(0, Double(pointer[3]))
                    let protein = max(0, Double(pointer[4]))
                    
                    return NutritionData(
                        calories: calories,
                        protein: protein,
                        carbohydrates: carbs,
                        fat: fat,
                        mass: mass
                    )
                }
            }
        }
        
        // Fallback: return zeros
        print("⚠️ Could not parse regression output")
        return .zero
    }
    
    // MARK: - Reset
    func reset() {
        state = .idle
        nutritionData = .zero
    }
}

// MARK: - Nutrition Loading View
struct NutritionLoadingView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                LoadingDotsView()
                HStack(spacing: 6) {
                    Text("Calculating the nutritions for you")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Nutrition Confirmation View (Review Your Meal)
struct NutritionConfirmationView: View {
    let foodName: String
    let capturedImage: UIImage?
    let baseNutrition: NutritionData
    let onSave: (NutritionData, Double, String, Date, String) -> Void
    let onDelete: () -> Void
    
    @State private var servings: Double = 1.0
    @State private var editedFoodName: String = ""
    @State private var isEditingFoodName: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker: Bool = false
    @State private var selectedTime: Date = Date()
    @State private var showTimePicker: Bool = false
    @State private var selectedMealType: String = "Meal"
    @State private var editedCalories: String = ""
    @State private var editedProtein: String = ""
    @State private var editedCarbs: String = ""
    @State private var editedFat: String = ""
    @State private var editedMass: String = ""
    @FocusState private var focusedNutritionField: String?
    @FocusState private var isFoodNameFocused: Bool
    
    private var scaledNutrition: NutritionData {
        return NutritionData(
            calories: Double(editedCalories) ?? baseNutrition.calories,
            protein: Double(editedProtein) ?? baseNutrition.protein,
            carbohydrates: Double(editedCarbs) ?? baseNutrition.carbohydrates,
            fat: Double(editedFat) ?? baseNutrition.fat,
            mass: Double(editedMass) ?? baseNutrition.mass * servings
        )
    }
    
    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: selectedTime)
    }
    
    private var combinedDateTime: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        return calendar.date(from: combined) ?? selectedDate
    }
    
    private let mealTypeOptions = ["Breakfast", "Lunch", "Tea", "Dinner", "Late Night", "Snack"]
    
    private func defaultMealType(for time: Date) -> String {
        let hour = Calendar.current.component(.hour, from: time)
        switch hour {
        case 5..<11: return "Breakfast"
        case 11..<15: return "Lunch"
        case 15..<18: return "Tea"
        case 18..<22: return "Dinner"
        default: return "Late Night"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Navigation Bar
            HStack {
                Button(action: onDelete) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Review Your Meal")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Invisible spacer for centering
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Food Image
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 240)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                    }

                    VStack(spacing: 14) {
                        // MARK: - Food Name & Date
                        HStack(alignment: .center) {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.55))
                                    .onTapGesture {
                                        isEditingFoodName = true
                                        isFoodNameFocused = true
                                    }
                                
                                if isEditingFoodName {
                                    TextField("Food name", text: $editedFoodName)
                                        .font(.title3.weight(.bold))
                                        .foregroundColor(.primary)
                                        .focused($isFoodNameFocused)
                                        .onSubmit {
                                            isEditingFoodName = false
                                        }
                                } else {
                                    Text(editedFoodName)
                                        .font(.title3.weight(.bold))
                                        .foregroundColor(.primary)
                                        .onTapGesture {
                                            isEditingFoodName = true
                                            isFoodNameFocused = true
                                        }
                                }
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Text(currentDateString)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .onTapGesture {
                                        showDatePicker = true
                                    }
                                Text(currentTimeString)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .onTapGesture {
                                        showTimePicker = true
                                    }
                            }
                        }
                        
                        // MARK: - Mass Display
                        HStack(spacing: 4) {
                            TextField("0", text: $editedMass)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.leading)
                                .fixedSize()
                                .focused($focusedNutritionField, equals: "mass")
                            Text("g")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .onTapGesture { focusedNutritionField = "mass" }
                      
                        .sheet(isPresented: $showDatePicker) {
                            VStack(spacing: 0) {
                                HStack {
                                    Spacer()
                                    Button("Done") {
                                        showDatePicker = false
                                    }
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.55))
                                    .padding()
                                }
                                DatePicker(
                                    "Select Date",
                                    selection: $selectedDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .tint(Color(red: 0.85, green: 0.55, blue: 0.55))
                                .padding()
                                Spacer()
                            }
                            .presentationDetents([.medium])
                        }
                        .sheet(isPresented: $showTimePicker) {
                            VStack(spacing: 0) {
                                HStack {
                                    Spacer()
                                    Button("Done") {
                                        showTimePicker = false
                                    }
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.55))
                                    .padding()
                                }
                                DatePicker(
                                    "Select Time",
                                    selection: $selectedTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .padding()
                                Spacer()
                            }
                            .presentationDetents([.medium])
                        }
                        
                        // MARK: - Serving Adjuster
                        HStack {
                            Button(action: {
                                if servings > 0.5 {
                                    let oldServings = servings
                                    servings -= 0.5
                                    scaleNutritionFields(by: servings / oldServings)
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color(red: 0.85, green: 0.55, blue: 0.55))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Text(servings == 1.0 ? "1 Serving" : String(format: "%.1f Serving", servings))
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                let oldServings = servings
                                servings += 0.5
                                scaleNutritionFields(by: servings / oldServings)
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color(red: 0.85, green: 0.55, blue: 0.55))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(25)
                        
                        // MARK: - Meal Type Selector
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Meal Type")
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(mealTypeOptions, id: \.self) { type in
                                        Button(action: { selectedMealType = type }) {
                                            Text(type)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundColor(
                                                    selectedMealType == type
                                                        ? .white
                                                        : Color(red: 0.85, green: 0.55, blue: 0.55)
                                                )
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    selectedMealType == type
                                                        ? Color(red: 0.85, green: 0.55, blue: 0.55)
                                                        : Color(red: 0.85, green: 0.55, blue: 0.55).opacity(0.1)
                                                )
                                                .cornerRadius(20)
                                        }
                                    }
                                }
                            }
                        }
                        // MARK: - Nutrition Section
                        VStack(spacing: 14) {
                            HStack {
                                Text("Nutrition")
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            // Calories
                            nutritionRow(
                                label: "Calories",
                                editValue: $editedCalories,
                                suffix: "kcal",
                                fieldKey: "calories"
                            )
                            
                            Divider().background(Color.gray.opacity(0.3))
                            
                            // Protein
                            nutritionRow(
                                label: "Protein",
                                editValue: $editedProtein,
                                suffix: "g",
                                fieldKey: "protein"
                            )
                            
                            Divider().background(Color.gray.opacity(0.3))
                            
                            // Carbohydrates
                            nutritionRow(
                                label: "Carbohydrates",
                                editValue: $editedCarbs,
                                suffix: "g",
                                fieldKey: "carbs"
                            )
                            
                            Divider().background(Color.gray.opacity(0.3))
                            
                            // Fat
                            nutritionRow(
                                label: "Fat",
                                editValue: $editedFat,
                                suffix: "g",
                                fieldKey: "fat"
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }
            
            // MARK: - Bottom Buttons
            HStack(spacing: 16) {
                Button(action: onDelete) {
                    Text("Delete")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.85, green: 0.55, blue: 0.55))
                        .cornerRadius(25)
                }
                
                Button(action: {
                    onSave(scaledNutrition, servings, editedFoodName, combinedDateTime, selectedMealType)
                }) {
                    Text("Save")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.85, green: 0.55, blue: 0.55))
                        .cornerRadius(25)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .padding(.top, 8)
        }
        .background(Color(uiColor: .systemBackground))
        .onTapGesture {
            isFoodNameFocused = false
            focusedNutritionField = nil
            if isEditingFoodName {
                isEditingFoodName = false
            }
        }
        .onAppear {
            editedFoodName = foodName
            editedCalories = String(format: "%.0f", baseNutrition.calories)
            editedProtein = String(format: "%.1f", baseNutrition.protein)
            editedCarbs = String(format: "%.1f", baseNutrition.carbohydrates)
            editedFat = String(format: "%.1f", baseNutrition.fat)
            editedMass = String(format: "%.0f", baseNutrition.mass)
            selectedMealType = defaultMealType(for: selectedTime)
        }
        .onChange(of: selectedTime) { _, newTime in
            selectedMealType = defaultMealType(for: newTime)
        }
    }
    
    // MARK: - Scale Nutrition Fields
    private func scaleNutritionFields(by ratio: Double) {
        if let cal = Double(editedCalories) {
            editedCalories = String(format: "%.0f", cal * ratio)
        }
        if let pro = Double(editedProtein) {
            editedProtein = String(format: "%.1f", pro * ratio)
        }
        if let carb = Double(editedCarbs) {
            editedCarbs = String(format: "%.1f", carb * ratio)
        }
        if let fat = Double(editedFat) {
            editedFat = String(format: "%.1f", fat * ratio)
        }
        if let mass = Double(editedMass) {
            editedMass = String(format: "%.0f", mass * ratio)
        }
    }
    
    // MARK: - Nutrition Row
    @ViewBuilder
    private func nutritionRow(label: String, editValue: Binding<String>, suffix: String, fieldKey: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 4) {
                TextField("", text: editValue)
                    .font(.body)
                    .foregroundColor(.primary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($focusedNutritionField, equals: fieldKey)
                
                Text(suffix)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            .onTapGesture {
                focusedNutritionField = fieldKey
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    NutritionConfirmationView(
        foodName: "Saucy Ramen Noodles",
        capturedImage: nil,
        baseNutrition: NutritionData(
            calories: 285,
            protein: 11,
            carbohydrates: 4.5,
            fat: 11,
            mass: 350
        ),
        onSave: { _, _, _, _, _ in },
        onDelete: { }
    )
}