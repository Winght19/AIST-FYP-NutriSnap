import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(AppStateManager.self) private var appStateManager
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 0
    @State private var onboardingData = OnboardingData()
    @State private var isCreatingProfile = false
    @State private var isProfileReady = false

    private let totalSteps = 6

    var progress: CGFloat {
        CGFloat(currentStep + 1) / CGFloat(totalSteps)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isCreatingProfile && !isProfileReady {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.90, green: 0.35, blue: 0.35))
                            .frame(width: geometry.size.width * progress, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Step content
                TabView(selection: $currentStep) {
                    GenderStepView(
                        selectedGender: $onboardingData.gender,
                        onContinue: nextStep
                    )
                    .tag(0)

                    HeightWeightStepView(
                        height: $onboardingData.height,
                        weight: $onboardingData.weight,
                        onContinue: nextStep
                    )
                    .tag(1)

                    GoalStepView(
                        selectedGoal: $onboardingData.primaryGoal,
                        onContinue: nextStep
                    )
                    .tag(2)

                    AgeStepView(
                        dateOfBirth: $onboardingData.dateOfBirth,
                        onContinue: nextStep
                    )
                    .tag(3)

                    ExerciseStepView(
                        exerciseHours: $onboardingData.exerciseHours,
                        onContinue: nextStep
                    )
                    .tag(4)

                    AllergenStepView(
                        selectedAllergens: $onboardingData.selectedAllergens,
                        onCreateProfile: createProfile
                    )
                    .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)

            } else if isCreatingProfile {
                ProfileCreatingView()

            } else if isProfileReady {
                ProfileReadyView(onStartTracking: {
                    appStateManager.finishOnboarding()
                })
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    private func nextStep() {
        withAnimation {
            if currentStep < totalSteps - 1 {
                currentStep += 1
            }
        }
    }

    private func createProfile() {
        Task {
            withAnimation { isCreatingProfile = true }

            let profileDTO = OnboardingProfileDTO(
                dateOfBirth: onboardingData.dateOfBirth ?? Date(),
                weightKg: Double(onboardingData.weight),
                heightCm: Double(onboardingData.height),
                gender: onboardingData.gender,
                primaryGoal: onboardingData.primaryGoal,
                exerciseHoursPerWeek: onboardingData.exerciseHours,
                allergens: Array(onboardingData.selectedAllergens)
            )
            await appStateManager.completeOnboarding(with: profileDTO, modelContext: modelContext)

            // Only transition to the "ready" screen if the backend call succeeded.
            // If completeOnboarding set appState to .error, RootView will show ErrorView instead.
            if case .error = appStateManager.appState {
                return  // RootView handles the error screen
            }

            withAnimation {
                isCreatingProfile = false
                isProfileReady = true
            }
        }
    }
}

// MARK: - Reusable Wheel Picker Overlay

struct WheelPickerOverlay: View {
    let title: String
    let unit: String
    let range: ClosedRange<Int>
    @Binding var selection: Int
    @Binding var isPresented: Bool
    
    @State private var tempSelection: Int = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { isPresented = false }
                }
            
            // Picker card pinned to bottom
            VStack(spacing: 0) {
                // Header with Cancel / Confirm
                HStack {
                    Button("Cancel") {
                        withAnimation { isPresented = false }
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Confirm") {
                        selection = tempSelection
                        withAnimation { isPresented = false }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.40, green: 0.75, blue: 0.50))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                
                Divider()
                
                // Wheel picker
                HStack(spacing: 4) {
                    Picker(title, selection: $tempSelection) {
                        ForEach(Array(range), id: \.self) { value in
                            Text("\(value)")
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(.horizontal, 20)
                .frame(height: 200)
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16, corners: [.topLeft, .topRight])
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            tempSelection = selection
        }
    }
}

// Helper to round specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Reusable Value Display Button

struct ValuePickerButton: View {
    let placeholder: String
    let value: Int
    let unit: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if value > 0 {
                    Text("\(value)")
                        .font(.body)
                        .foregroundColor(.primary)
                } else {
                    Text(placeholder)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(unit)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Step 1: Gender

struct GenderStepView: View {
    @Binding var selectedGender: String
    var onContinue: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 60)
            
            Text("Gender")
                .font(.system(size: 32, weight: .bold))
                .padding(.horizontal, 32)
            
            Spacer().frame(height: 32)
            
            HStack(spacing: 16) {
                genderButton(title: "Female", value: "Female")
                genderButton(title: "Male", value: "Male")
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        selectedGender.isEmpty
                            ? Color.gray.opacity(0.4)
                            : Color(red: 0.40, green: 0.75, blue: 0.50)
                    )
                    .cornerRadius(26)
            }
            .disabled(selectedGender.isEmpty)
            .padding(.horizontal, 32)
            .safeAreaPadding(.bottom, 16)
        }
    }
    
    private func genderButton(title: String, value: String) -> some View {
        Button(action: { selectedGender = value }) {
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(selectedGender == value ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    selectedGender == value
                        ? Color(red: 0.40, green: 0.75, blue: 0.50)
                        : Color(UIColor.secondarySystemGroupedBackground)
                )
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            selectedGender == value
                                ? Color.clear
                                : Color.gray.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
    }
}

// MARK: - Step 2: Height & Weight

struct HeightWeightStepView: View {
    @Binding var height: Int
    @Binding var weight: Int
    var onContinue: () -> Void
    
    @State private var showHeightPicker = false
    @State private var showWeightPicker = false
    
    var isValid: Bool {
        height > 0 && weight > 0
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 60)
                
                // Height
                Text("Height")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 32)
                
                Spacer().frame(height: 12)
                
                ValuePickerButton(
                    placeholder: "e.g. 165",
                    value: height,
                    unit: "cm",
                    action: { showHeightPicker = true }
                )
                .padding(.horizontal, 32)
                
                Spacer().frame(height: 32)
                
                // Weight
                Text("Weight")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 32)
                    
                
                Spacer().frame(height: 12)
                
                ValuePickerButton(
                    placeholder: "e.g. 70",
                    value: weight,
                    unit: "kg",
                    action: { showWeightPicker = true }
                )
                .padding(.horizontal, 32)
                
                Spacer().frame(height: 50)
                
                // Illustration
                HStack {
                    Spacer()
                    Image(systemName: "figure.stand")
                        .font(.system(size: 80))
                        .foregroundColor(Color(red: 0.40, green: 0.75, blue: 0.50).opacity(0.4))
                    Spacer()
                }
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(isValid ? Color(red: 0.40, green: 0.75, blue: 0.50) : Color.gray.opacity(0.4))
                        .cornerRadius(26)
                }
                .disabled(!isValid)
                .padding(.horizontal, 32)
                .safeAreaPadding(.bottom, 16)
            }
            
            // Picker overlays
            if showHeightPicker {
                WheelPickerOverlay(
                    title: "Height",
                    unit: "cm",
                    range: 100...220,
                    selection: $height,
                    isPresented: $showHeightPicker
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            if showWeightPicker {
                WheelPickerOverlay(
                    title: "Weight",
                    unit: "kg",
                    range: 30...200,
                    selection: $weight,
                    isPresented: $showWeightPicker
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showHeightPicker)
        .animation(.easeInOut(duration: 0.3), value: showWeightPicker)
    }
}

// MARK: - Step 3: Primary Goal

struct GoalStepView: View {
    @Binding var selectedGoal: String
    var onContinue: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 60)
            
            Text("Your Primary Goal")
                .font(.system(size: 28, weight: .bold))
                .padding(.horizontal, 32)
            
            Spacer().frame(height: 24)
            
            VStack(spacing: 12) {
                ForEach(OnboardingData.goalOptions, id: \.self) { goal in
                    Button(action: { selectedGoal = goal }) {
                        Text(goal)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(selectedGoal == goal ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                selectedGoal == goal
                                    ? Color(red: 0.40, green: 0.75, blue: 0.50)
                                    : Color(red: 0.40, green: 0.75, blue: 0.50).opacity(0.15)
                            )
                            .cornerRadius(25)
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Spacer().frame(height: 50)
            
            HStack {
                Spacer()
                Image(systemName: "trophy.fill")
                    .font(.system(size: 70))
                    .foregroundColor(Color(red: 0.40, green: 0.75, blue: 0.50).opacity(0.4))
                Spacer()
            }
            
            Spacer()
            
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(selectedGoal.isEmpty ? Color.gray.opacity(0.4) : Color(red: 0.40, green: 0.75, blue: 0.50))
                    .cornerRadius(26)
            }
            .disabled(selectedGoal.isEmpty)
            .padding(.horizontal, 32)
            .safeAreaPadding(.bottom, 16)
        }
    }
}

// MARK: - Step 4: Date of Birth

struct AgeStepView: View {
    @Binding var dateOfBirth: Date?
    var onContinue: () -> Void

    @State private var showDatePicker = false
    @State private var pendingDate: Date = {
        // Default the wheel to a sensible starting point (22 years ago)
        Calendar.current.date(byAdding: .year, value: -22, to: Date()) ?? Date()
    }()

    private var isValid: Bool { dateOfBirth != nil }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 60)

                Text("Date of Birth")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.horizontal, 32)

                Spacer().frame(height: 8)

                Text("Used to keep your calorie targets accurate as you age.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 24)

                Button(action: { showDatePicker = true }) {
                    HStack {
                        if let dob = dateOfBirth {
                            Text(dob, format: .dateTime.day().month(.wide).year())
                                .font(.body)
                                .foregroundColor(.primary)
                        } else {
                            Text("Select your date of birth")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 40)

                HStack {
                    Spacer()
                    Image(systemName: "birthday.cake.fill")
                        .font(.system(size: 70))
                        .foregroundColor(Color(red: 0.40, green: 0.75, blue: 0.50).opacity(0.4))
                    Spacer()
                }

                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(isValid ? Color(red: 0.40, green: 0.75, blue: 0.50) : Color.gray.opacity(0.4))
                        .cornerRadius(26)
                }
                .disabled(!isValid)
                .padding(.horizontal, 32)
                .safeAreaPadding(.bottom, 16)
            }

            if showDatePicker {
                DatePickerOverlay(
                    selection: $pendingDate,
                    isPresented: $showDatePicker,
                    onConfirm: { dateOfBirth = pendingDate }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showDatePicker)
        .onAppear {
            // Pre-load the wheel to the already-selected date if the user comes back
            if let dob = dateOfBirth { pendingDate = dob }
        }
    }
}

// MARK: - Date Picker Overlay

struct DatePickerOverlay: View {
    @Binding var selection: Date
    @Binding var isPresented: Bool
    var onConfirm: () -> Void

    private var maximumDate: Date {
        // Must be at least 10 years old
        Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
    }
    private var minimumDate: Date {
        Calendar.current.date(byAdding: .year, value: -120, to: Date()) ?? Date()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }

            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") {
                        withAnimation { isPresented = false }
                    }
                    .foregroundColor(.secondary)

                    Spacer()

                    Button("Confirm") {
                        onConfirm()
                        withAnimation { isPresented = false }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.40, green: 0.75, blue: 0.50))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider()

                DatePicker(
                    "",
                    selection: $selection,
                    in: minimumDate...maximumDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.horizontal, 20)
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16, corners: [.topLeft, .topRight])
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Step 5: Exercise

struct ExerciseStepView: View {
    @Binding var exerciseHours: Int
    var onContinue: () -> Void
    
    @State private var showExercisePicker = false
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 60)
                
                HStack(spacing: 4) {
                    Text("Exercise")
                        .font(.system(size: 28, weight: .bold))
                    Text("(per week)")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .offset(y: 4)
                }
                .padding(.horizontal, 32)
                
                Spacer().frame(height: 24)
                
                ValuePickerButton(
                    placeholder: "e.g. 3",
                    value: exerciseHours,
                    unit: "hours",
                    action: { showExercisePicker = true }
                )
                .padding(.horizontal, 32)
                
                Spacer().frame(height: 50)
                
                HStack {
                    Spacer()
                    Image(systemName: "figure.run")
                        .font(.system(size: 80))
                        .foregroundColor(Color(red: 0.40, green: 0.75, blue: 0.50).opacity(0.4))
                    Spacer()
                }
                
                Spacer()
                
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(exerciseHours > 0 ? Color(red: 0.40, green: 0.75, blue: 0.50) : Color.gray.opacity(0.4))
                        .cornerRadius(26)
                }
                .disabled(exerciseHours <= 0)
                .padding(.horizontal, 32)
                .safeAreaPadding(.bottom, 16)
            }
            
            if showExercisePicker {
                WheelPickerOverlay(
                    title: "Exercise",
                    unit: "hours",
                    range: 1...40,
                    selection: $exerciseHours,
                    isPresented: $showExercisePicker
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showExercisePicker)
    }
}

// MARK: - Step 6: Allergens

struct AllergenStepView: View {
    @Binding var selectedAllergens: Set<String>
    var onCreateProfile: () -> Void
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 60)
            
            Text("Allergen")
                .font(.system(size: 32, weight: .bold))
                .padding(.horizontal, 32)
            
            Spacer().frame(height: 24)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(OnboardingData.allergenOptions, id: \.self) { allergen in
                    Button(action: {
                        if selectedAllergens.contains(allergen) {
                            selectedAllergens.remove(allergen)
                        } else {
                            selectedAllergens.insert(allergen)
                        }
                    }) {
                        Text(allergen)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(
                                selectedAllergens.contains(allergen) ? .white : .primary
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                selectedAllergens.contains(allergen)
                                    ? Color(red: 0.40, green: 0.75, blue: 0.50)
                                    : Color(red: 0.40, green: 0.75, blue: 0.50).opacity(0.15)
                            )
                            .cornerRadius(22)
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Spacer().frame(height: 24)
            
            HStack {
                Spacer()
                Image(systemName: "leaf.fill")
                    .font(.system(size: 70))
                    .foregroundColor(Color(red: 0.40, green: 0.75, blue: 0.50).opacity(0.4))
                Spacer()
            }
            
            Spacer()
            
            Button(action: onCreateProfile) {
                Text("Create Profile")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(red: 0.40, green: 0.75, blue: 0.50))
                    .cornerRadius(26)
            }
            .padding(.horizontal, 32)
            .safeAreaPadding(.bottom, 16)
        }
    }
}

// MARK: - Creating Profile (Loading)

struct ProfileCreatingView: View {
    @State private var dotCount = 0
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color(red: 0.40, green: 0.75, blue: 0.50))
                            .frame(width: 12, height: 12)
                            .scaleEffect(dotCount == index ? 1.3 : 0.7)
                            .opacity(dotCount == index ? 1.0 : 0.4)
                            .animation(
                                .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: dotCount
                            )
                    }
                }
                
                HStack(spacing: 4) {
                    Text("Creating your profile")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("✨")
                        .font(.title3)
                }
                
                Text("This may take a minute")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .onAppear {
            dotCount = 2
        }
    }
}

// MARK: - Profile Ready (Finish)

struct ProfileReadyView: View {
    var onStartTracking: () -> Void
    @State private var showCheckmark = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color(red: 0.40, green: 0.75, blue: 0.50))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(showCheckmark ? 1.0 : 0.5)
                .opacity(showCheckmark ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)
                
                Text("You're all set!")
                    .font(.system(size: 28, weight: .bold))
                
                Text("We've personalized your plan. You're\nready to start tracking.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                Button(action: onStartTracking) {
                    Text("Start Tracking")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(red: 0.40, green: 0.75, blue: 0.50))
                        .cornerRadius(26)
                }
                .padding(.horizontal, 32)
                .safeAreaPadding(.bottom, 16)
            }
        }
        .onAppear {
            showCheckmark = true
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppStateManager())
}
