import SwiftUI
import CoreML
import Vision
import UIKit
import AVFoundation
import PhotosUI
import Combine

// MARK: - Food Detection Result Model
struct FoodDetection: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect?
    let source: DetectionSource
    
    enum DetectionSource: String {
        case yolo = "YOLO"
        case keras = "Keras"
    }
    
    static func == (lhs: FoodDetection, rhs: FoodDetection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Food Recognition State
enum RecognitionState: Equatable {
    case idle
    case identifyingFood
    case selectingMeal([FoodDetection])
    case calculatingNutrition(String)
    case completed(String)
    case error(String)
}

// MARK: - Food Recognition Pipeline
class FoodRecognitionPipeline: ObservableObject {
    @Published var state: RecognitionState = .idle
    @Published var topPredictions: [FoodDetection] = []
    @Published var selectedFood: String?
    @Published var isModelLoading: Bool = true
    
    private var yoloModel: VNCoreMLModel?
    private var kerasModel: VNCoreMLModel?
    
    private let confidenceThreshold: Float = 0.6
    
    // Food101 + HK Local classes (sorted alphabetically for Keras model output mapping)
    private let food101Classes: [String] = [
        "apple_pie", "baby_back_ribs", "baklava", "beef_carpaccio", "beef_tartare",
        "beet_salad", "beignets", "bibimbap", "bread_pudding", "breakfast_burrito",
        "bruschetta", "caesar_salad", "cannoli", "caprese_salad", "carrot_cake",
        "ceviche", "cheesecake", "cheese_plate", "chicken_curry", "chicken_quesadilla",
        "chicken_wings", "chocolate_cake", "chocolate_mousse", "churros", "clam_chowder",
        "club_sandwich", "crab_cakes", "creme_brulee", "croque_madame", "cup_cakes",
        "deviled_eggs", "donuts", "dumplings", "edamame", "egg_puffs",
        "egg_tart", "egg_waffle", "eggs_benedict", "escargots", "falafel",
        "filet_mignon", "fish_and_chips", "fishball", "foie_gras", "french_fries",
        "french_onion_soup", "french_toast", "fried_calamari", "fried_rice", "frozen_yogurt",
        "garlic_bread", "gnocchi", "greek_salad", "grilled_cheese_sandwich", "grilled_salmon",
        "guacamole", "gyoza", "hamburger", "hot_and_sour_soup", "hot_dog",
        "huevos_rancheros", "hummus", "ice_cream", "imitation_Shark_Fin_Soup", "lasagna",
        "lobster_bisque", "lobster_roll_sandwich", "macaroni_and_cheese", "macarons", "miso_soup",
        "mussels", "nachos", "omelette", "onion_rings", "oysters",
        "pad_thai", "paella", "pancakes", "panna_cotta", "peking_duck",
        "pho", "pineapple_bun", "pizza", "pork_chop", "poutine",
        "prime_rib", "pulled_pork_sandwich", "ramen", "ravioli", "red_Bean_Fleecy",
        "red_velvet_cake", "risotto", "samosa", "sashimi", "satay_beef_noodle",
        "scallops", "seaweed_salad", "shrimp_and_grits", "singapore_Stir-fried_Noodles", "siu_mai",
        "spaghetti_bolognese", "spaghetti_carbonara", "spring_rolls", "steak", "steam_rice_pudding",
        "stir-fried_Beef_Noodles", "strawberry_shortcake", "sushi", "sweet-and_Sour-Pork", "tacos",
        "takoyaki", "tiramisu", "tuna_tartare", "waffles"
    ].sorted()
    
    init() {
        loadModels()
    }
    
    // MARK: - Load Core ML Models
    private func loadModels() {
        Task.detached(priority: .userInitiated) { [weak self] in
            var loadedYOLO: VNCoreMLModel?
            var loadedKeras: VNCoreMLModel?

            // Load YOLOv8 model
            if let yoloURL = Bundle.main.url(forResource: "food-reg_yolov8s", withExtension: "mlmodelc") ??
                Bundle.main.url(forResource: "food-reg_yolov8s", withExtension: "mlpackage") {
                do {
                    let config = MLModelConfiguration()
                    config.computeUnits = .all
                    let mlModel = try MLModel(contentsOf: yoloURL, configuration: config)
                    loadedYOLO = try VNCoreMLModel(for: mlModel)
                    print("✓ YOLOv8 model loaded successfully")
                } catch {
                    print("Error loading YOLOv8 model: \(error)")
                }
            } else {
                print("YOLOv8 model file not found in bundle")
            }

            // Load Keras fallback model
            if let kerasURL = Bundle.main.url(forResource: "food-reg_food101xhklocal", withExtension: "mlmodelc") ??
                Bundle.main.url(forResource: "food-reg_food101xhklocal", withExtension: "mlpackage") {
                do {
                    let config = MLModelConfiguration()
                    config.computeUnits = .all
                    let mlModel = try MLModel(contentsOf: kerasURL, configuration: config)
                    loadedKeras = try VNCoreMLModel(for: mlModel)
                    print("✓ Keras fallback model loaded successfully")
                } catch {
                    print("Error loading Keras model: \(error)")
                }
            } else {
                print("Keras model file not found in bundle")
            }

            await MainActor.run {
                self?.yoloModel = loadedYOLO
                self?.kerasModel = loadedKeras
                self?.isModelLoading = false
            }
        }
    }
    
    // MARK: - Main Recognition Pipeline
    @MainActor
    func processImage(_ image: UIImage) async {
        guard !isModelLoading else {
            state = .error("Food recognition is still preparing. Please try again in a moment.")
            return
        }

        state = .identifyingFood
        topPredictions = []
        
        guard let cgImage = image.cgImage else {
            state = .error("Failed to process image")
            return
        }
        
        // Run YOLO detection first
        let (yoloDetections, needsFallback) = await runYOLODetection(cgImage: cgImage)
        
        var allDetections: [FoodDetection] = yoloDetections
        
        // If YOLO confidence is low or no detections, use fallback
        if needsFallback {
            print("Low confidence or no YOLO detections. Using fallback classifier...")
            let kerasDetections = await runKerasFallback(cgImage: cgImage)
            allDetections.append(contentsOf: kerasDetections)
        }
        
        // Sort by confidence and get top 3
        let top3 = Array(allDetections.sorted { $0.confidence > $1.confidence }.prefix(3))
        
        await MainActor.run {
            self.topPredictions = top3
            if top3.isEmpty {
                self.state = .error("No food detected")
            } else {
                self.state = .selectingMeal(top3)
            }
        }
    }
    
    // MARK: - YOLO Detection
    private func runYOLODetection(cgImage: CGImage) async -> ([FoodDetection], Bool) {
        guard let model = yoloModel else {
            return ([], true)
        }
        
        return await withCheckedContinuation { continuation in
            var detections: [FoodDetection] = []
            var needsFallback = true
            
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                guard let self = self else {
                    continuation.resume(returning: ([], true))
                    return
                }
                
                if let error = error {
                    print("YOLO detection error: \(error)")
                    continuation.resume(returning: ([], true))
                    return
                }
                
                // Process YOLO results
                if let results = request.results as? [VNRecognizedObjectObservation] {
                    for observation in results {
                        let confidence = observation.confidence
                        let boundingBox = observation.boundingBox
                        
                        if let topLabel = observation.labels.first {
                            let detection = FoodDetection(
                                label: self.formatFoodLabel(topLabel.identifier),
                                confidence: topLabel.confidence,
                                boundingBox: boundingBox,
                                source: .yolo
                            )
                            detections.append(detection)
                            
                            if confidence >= self.confidenceThreshold {
                                needsFallback = false
                            }
                        }
                    }
                } else if let results = request.results as? [VNClassificationObservation] {
                    for (index, observation) in results.prefix(5).enumerated() {
                        let detection = FoodDetection(
                            label: self.formatFoodLabel(observation.identifier),
                            confidence: observation.confidence,
                            boundingBox: nil,
                            source: .yolo
                        )
                        detections.append(detection)
                        
                        if index == 0 && observation.confidence >= self.confidenceThreshold {
                            needsFallback = false
                        }
                    }
                }
                
                continuation.resume(returning: (detections, needsFallback))
            }
            
            request.imageCropAndScaleOption = .scaleFill
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform YOLO request: \(error)")
                continuation.resume(returning: ([], true))
            }
        }
    }
    
    // MARK: - Keras Fallback Classification
    private func runKerasFallback(cgImage: CGImage) async -> [FoodDetection] {
        guard let model = kerasModel else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            var detections: [FoodDetection] = []
            
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                
                if let error = error {
                    print("Keras classification error: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                
                if let results = request.results as? [VNClassificationObservation] {
                    for observation in results.prefix(3) {
                        let detection = FoodDetection(
                            label: self.formatFoodLabel(observation.identifier),
                            confidence: observation.confidence,
                            boundingBox: nil,
                            source: .keras
                        )
                        detections.append(detection)
                    }
                } else if let results = request.results as? [VNCoreMLFeatureValueObservation] {
                    if let firstResult = results.first,
                       let multiArray = firstResult.featureValue.multiArrayValue {
                        let predictions = self.parseMultiArrayPredictions(multiArray)
                        detections = predictions
                    }
                }
                
                continuation.resume(returning: detections)
            }
            
            request.imageCropAndScaleOption = .scaleFill
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform Keras request: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
    
    // MARK: - Parse MultiArray Predictions
    private func parseMultiArrayPredictions(_ multiArray: MLMultiArray) -> [FoodDetection] {
        var predictions: [(Int, Float)] = []
        
        for i in 0..<multiArray.count {
            let confidence = multiArray[i].floatValue
            predictions.append((i, confidence))
        }
        
        let top3 = predictions.sorted { $0.1 > $1.1 }.prefix(3)
        
        return top3.map { (index, confidence) in
            let label = index < food101Classes.count ? food101Classes[index] : "Food_\(index)"
            return FoodDetection(
                label: formatFoodLabel(label),
                confidence: confidence,
                boundingBox: nil,
                source: .keras
            )
        }
    }
    
    // MARK: - Format Food Label
    private func formatFoodLabel(_ label: String) -> String {
        return label
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
    
    // MARK: - Select Food for Nutrition Calculation
    func selectFood(_ food: String) {
        selectedFood = food
        state = .completed(food)
    }
    
    // MARK: - Reset Pipeline
    func reset() {
        state = .idle
        topPredictions = []
        selectedFood = nil
    }
}


// MARK: - Food Recognition Loading View (Plain White, Full Screen)
struct FoodRecognitionLoadingView: View {
    let state: RecognitionState
    var customText: String? = nil

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()  // Solid white background over everything

            VStack(spacing: 24) {
                Spacer()
                LoadingDotsView()
                HStack(spacing: 6) {
                    Text(statusText)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private var statusText: String {
        if let customText {
            return customText
        }

        switch state {
        case .identifyingFood: return "Identifying the food..."
        case .calculatingNutrition: return "Analyzing nutrition..."
        default: return "Processing..."
        }
    }
}

// Helper to ensure perfect centering regardless of parent offsets
extension View {
    func centerInParent() -> some View {
        self.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Loading Dots Animation
struct LoadingDotsView: View {
    @State private var animatingDot = 0
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(animatingDot == index ? Color.black : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                animatingDot = (animatingDot + 1) % 3
            }
        }
    }
}

// MARK: - Meal Selection View (Modified for Bottom Alignment)
struct MealSelectionView: View {
    let predictions: [FoodDetection]
    let capturedImage: UIImage?
    let onSelect: (String) -> Void
    let onCancel: () -> Void
    
    @State private var selectedIndex: Int = 0
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            VStack(spacing: 0) {
                // 1. Top Image Section
                ZStack {
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: isLandscape ? geo.size.height / 4 : geo.size.height / 3)
                            .clipped()
                            .opacity(0.6)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: isLandscape ? geo.size.height / 4 : geo.size.height / 3)
                            .opacity(0.6)
                    }
                    
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Text("What's your meal?")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                            Image(systemName: "sparkle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        Spacer().frame(height: isLandscape ? 15 : 40)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // --- NEW: FLEXIBLE SPACER ---
                // This pushes the controls below to the bottom of the screen
                Spacer() 

                // 2. Action Buttons (Cancel/Confirm)
                HStack {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 17))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button(action: {
                        if selectedIndex < predictions.count {
                            onSelect(predictions[selectedIndex].label)
                        }
                    }) {
                        Text("Confirm")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.2))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
                
                // 3. Food Selection List
                VStack(spacing: 12) {
                    ForEach(Array(predictions.enumerated()), id: \.element.id) { index, prediction in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedIndex = index
                            }
                        }) {
                            Text(prediction.label)
                                .font(.system(size: selectedIndex == index ? 17 : 16,
                                             weight: selectedIndex == index ? .semibold : .regular))
                                .foregroundColor(selectedIndex == index ? .black : .gray.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Group {
                                        if selectedIndex == index {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.gray.opacity(0.15))
                                        }
                                    }
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 40)
                
                // 4. Bottom Safe Area Spacer
                Spacer()
                    .frame(height: isLandscape ? 20 : 60) 
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Color(.systemBackground))
        }
    }
}


// ...existing code...

// MARK: - Enhanced Camera View with Food Recognition
struct FoodRecognitionCameraView: View {
    @State private var capturedImage: UIImage? = nil
    @State private var isCameraAuthorized = false
    @State private var photosPickerItem: PhotosPickerItem?
    @Environment(\.dismiss) var dismiss
    
    @State private var cameraManager = CameraManager()
    @StateObject private var pipeline = FoodRecognitionPipeline()
    @StateObject private var nutritionPipeline = NutritionEstimationPipeline()
    
    var body: some View {
        ZStack {
            // Background - always white
            Color.white
                .ignoresSafeArea()
            
            // Only show camera when idle
            if pipeline.state == .idle {
                cameraContentView
            }
            
            // Overlay other states on top
            switch pipeline.state {
            case .idle:
                if pipeline.isModelLoading {
                    FoodRecognitionLoadingView(
                        state: .identifyingFood,
                        customText: "Preparing food recognition..."
                    )
                    .zIndex(10)
                } else {
                    EmptyView()
                }
                
            case .identifyingFood:
                FoodRecognitionLoadingView(
                    state: pipeline.state
                )
                .zIndex(10)
                
            case .selectingMeal(let predictions):
                MealSelectionView(
                    predictions: predictions,
                    capturedImage: capturedImage,
                    onSelect: { food in
                        pipeline.selectFood(food)
                        if let image = capturedImage {
                            Task {
                                await nutritionPipeline.estimateNutrition(from: image)
                            }
                        }
                    },
                    onCancel: {
                        pipeline.reset()
                        nutritionPipeline.reset()
                        capturedImage = nil
                    }
                )
                .zIndex(10)
                
            case .calculatingNutrition:
                NutritionLoadingView()
                    .zIndex(10)
                
            case .completed(let food):
                Group {
                    switch nutritionPipeline.state {
                    case .calculating:
                        NutritionLoadingView()
                        
                    case .completed(let nutrition):
                        NutritionConfirmationView(
                            foodName: food,
                            capturedImage: capturedImage,
                            baseNutrition: nutrition,
                            onSave: { finalNutrition, servings, editedName, savedDate, mealType in
                                print("Saved: \(editedName) - \(finalNutrition) - \(servings) servings on \(savedDate) [\(mealType)]")
                                pipeline.reset()
                                nutritionPipeline.reset()
                                capturedImage = nil
                                dismiss()
                            },
                            onDelete: {
                                pipeline.reset()
                                nutritionPipeline.reset()
                                capturedImage = nil
                            }
                        )
                        
                    case .error(let message):
                        errorView(message: message)
                        
                    case .idle:
                        NutritionLoadingView()
                            .onAppear {
                                if let image = capturedImage {
                                    Task {
                                        await nutritionPipeline.estimateNutrition(from: image)
                                    }
                                }
                            }
                    }
                }
                .zIndex(10)
                
            case .error(let message):
                errorView(message: message)
                    .zIndex(10)
            }
        }
        .animation(.none, value: pipeline.state)
        .onAppear { checkCameraPermissions() }
        .onChange(of: photosPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.capturedImage = uiImage
                    }
                    await pipeline.processImage(uiImage)
                }
            }
        }
    }
    
    // MARK: - Camera Content View
    private var cameraContentView: some View {
        VStack {
            Spacer()
            
            ZStack {
                if let image = capturedImage {
                    Color.clear
                        .overlay(
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        )
                        .clipped()
                } else if isCameraAuthorized {
                    CameraPreview(session: cameraManager.service.session)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            VStack {
                                Image(systemName: "camera.fill").font(.largeTitle)
                                Text("Camera Preview")
                            }.foregroundColor(.gray)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.8, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .padding()
            
            Spacer()
            
            HStack(spacing: 60) {
                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                }
                
                Button(action: capturePhoto) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.5), lineWidth: 6)
                            .frame(width: 85, height: 85)
                        Circle()
                            .fill(Color.gray.opacity(0.8))
                            .frame(width: 70, height: 70)
                    }
                }
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                pipeline.reset()
                nutritionPipeline.reset()
                capturedImage = nil
            }) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Actions
    private func capturePhoto() {
        cameraManager.service.capturePhoto { image in
            self.capturedImage = image
            Task {
                await pipeline.processImage(image)
            }
        }
    }
    
    private func checkCameraPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            isCameraAuthorized = true
            cameraManager.service.start()
        } else if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.isCameraAuthorized = true
                        self.cameraManager.service.start()
                    }
                }
            }
        }
    }
}

// ...existing code...


// MARK: - Preview
#Preview {
    FoodRecognitionCameraView()
}