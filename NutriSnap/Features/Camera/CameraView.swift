import SwiftUI
import AVFoundation
import PhotosUI
import UIKit
import Observation
import SwiftData

// MARK: - 1. Camera Engine
@MainActor
class CameraService: NSObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage) -> Void)?

    func start() {
        Task.detached(priority: .background) {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }
            
            await MainActor.run {
                if self.session.canAddInput(input) { self.session.addInput(input) }
                if self.session.canAddOutput(self.output) { self.session.addOutput(self.output) }
                self.session.startRunning()
            }
        }
    }

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        self.captureCompletion = completion
        
        // SAFETY CHECK: Ensure there is an active camera connection
        guard output.connection(with: .video) != nil else {
            print("Simulator: No camera connection found. Photo capture skipped.")
            return
        }
        
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        captureCompletion?(image)
    }
}

// MARK: - 2. State Manager
@Observable @MainActor
class CameraManager {
    let service = CameraService()
}

// MARK: - 3. UI View
struct CameraView: View {
    @State private var isCameraAuthorized = false
    @State private var photosPickerItem: PhotosPickerItem?
    @Environment(\.dismiss) var dismiss
    
    @State private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    @Environment(\.modelContext) private var modelContext
    
    // Bridge to Logic
    @StateObject private var pipeline = FoodRecognitionPipeline()
    @StateObject private var nutritionPipeline = NutritionEstimationPipeline()

    var body: some View {
        ZStack {
            // 1. MAIN CONTENT
            VStack {
                // Navigation Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Text("Add Food")
                        .font(.headline)
                    Spacer()
                    // Balance spacer to keep title centred
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .opacity(pipeline.state == .idle ? 1 : 0)
                
                Spacer()

                // Display Frame (Camera or Result)
                ZStack {
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .padding(.horizontal)

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

                // Bottom Controls (Hidden during processing)
                if pipeline.state == .idle {
                    HStack(spacing: 60) {
                        PhotosPicker(selection: $photosPickerItem, matching: .images) {
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        }

                        if capturedImage != nil {
                            // Magnifier button to trigger food recognition
                            Button(action: {
                                if let image = capturedImage {
                                    Task {
                                        await pipeline.processImage(image)
                                    }
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .stroke(Color(red: 0.6, green: 0.88, blue: 0.6), lineWidth: 6)
                                        .frame(width: 85, height: 85)
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundColor(Color(red: 0.5, green: 0.88, blue: 0.5))
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // Camera shutter button
                            Button(action: {
                                cameraManager.service.capturePhoto { image in
                                    self.capturedImage = image
                                }
                            }) {
                                ZStack {
                                    Circle().stroke(Color.gray, lineWidth: 6).frame(width: 85, height: 85)
                                    Circle().fill(Color.gray).frame(width: 70, height: 70)
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }

                        Button(action: {
                            if capturedImage != nil {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    capturedImage = nil
                                }
                            } else {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: capturedImage != nil)
                    .padding(.bottom, 30)
                }
            }
            
            // 2. OVERLAYS
            switch pipeline.state {
            case .identifyingFood, .calculatingNutrition:
                // USES THE CUSTOM VIEW MATCHING YOUR SCREENSHOT
                ProcessingView(image: capturedImage)
                    .transition(.opacity)
                    .zIndex(2)
                
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
                    }
                )
                .transition(.opacity)
                .zIndex(3)
                
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
                                // Save image to Documents directory
                                var savedImagePath: String? = nil
                                if let image = capturedImage,
                                   let data = image.jpegData(compressionQuality: 0.8) {
                                    let fileName = UUID().uuidString + ".jpg"
                                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                        .appendingPathComponent(fileName)
                                    try? data.write(to: url)
                                    savedImagePath = url.path
                                }
                                let log = FoodLog(
                                    name: editedName,
                                    calories: finalNutrition.calories,
                                    protein: finalNutrition.protein,
                                    carbs: finalNutrition.carbohydrates,
                                    fat: finalNutrition.fat,
                                    imagePath: savedImagePath,
                                    timestamp: savedDate,
                                    mealType: mealType,
                                    mass: finalNutrition.mass
                                )
                                modelContext.insert(log)
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
                        VStack {
                            Text("Error: \(message)").foregroundColor(.red)
                            Button("Retry") {
                                pipeline.reset()
                                nutritionPipeline.reset()
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .zIndex(4)

            case .error(let message):
                VStack {
                    Text("Error: \(message)").foregroundColor(.red)
                    Button("Retry") {
                        pipeline.reset()
                        nutritionPipeline.reset()
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(radius: 5)
                .zIndex(5)

            case .idle:
                EmptyView()
            }

        }
        .background(Color(.systemBackground))
        .onAppear { checkCameraPermissions() }
        .onChange(of: photosPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run { self.capturedImage = uiImage }
                }
            }
        }
    }

    func checkCameraPermissions() {
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

// MARK: - 4. Video Preview Bridge
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.layer.sublayers?.first?.frame = uiView.bounds
    }
}

// MARK: - 5. Custom Loading UI (Matches Your Design)
struct ProcessingView: View {
    var image: UIImage?
    
    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                // 1. Background Image (Faded)
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        // Ensure it matches the frame of the original card
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: .infinity)
                } else {
                    Color.gray.opacity(0.3)
                }
                
                // 2. White Overlay (Heavy fade)
                Color.white.opacity(0.85)
                
                // 3. Centered Content
                VStack(spacing: 20) {
                    // Three Dots Animation
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            DotView(index: index)
                        }
                    }
                    
                    // Text + Sparkle
                    HStack(spacing: 6) {
                        Text("Identifying the food")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                        
                        Image(systemName: "sparkle")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.8, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .padding()
            
            Spacer()
        }
        .background(Color.white.opacity(0.01)) // Transparent touch shield
    }
}

// Helper for the animation dots
struct DotView: View {
    let index: Int
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.5
    
    var body: some View {
        Circle()
            .fill(Color.gray)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                let delay = Double(index) * 0.2
                withAnimation(Animation.easeInOut(duration: 0.6).repeatForever().delay(delay)) {
                    self.scale = 1.3
                    self.opacity = 1.0
                }
            }
    }
}