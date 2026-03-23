import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppStateManager.self) private var appStateManager
    @Environment(\.dismiss) private var dismiss
    
    // Form State
    @State private var heightCm: Int = 170
    @State private var weightKg: Int = 70
    @State private var gender: String = "Female"
    @State private var dateOfBirth: Date = Date()
    @State private var primaryGoal: String = "Maintain Weight"
    @State private var exerciseHours: Int = 3
    
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    let genderOptions = ["Female", "Male", "Other"]
    
    var body: some View {
        Form {
            Section(header: Text("Physical Profile")) {
                Picker("Gender", selection: $gender) {
                    ForEach(genderOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                
                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                
                HStack {
                    Text("Height")
                    Spacer()
                    TextField("Height", value: $heightCm, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("cm")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("Weight", value: $weightKg, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text("kg")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Goals")) {
                Picker("Primary Goal", selection: $primaryGoal) {
                    ForEach(OnboardingData.goalOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                
                Stepper(value: $exerciseHours, in: 0...40) {
                    HStack {
                        Text("Exercise")
                        Spacer()
                        Text("\(exerciseHours) hrs/week")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveSettings()
                }
                .fontWeight(.semibold)
                .disabled(isSaving)
            }
        }
        .overlay {
            if isSaving {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                ProgressView()
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
        }
        .onAppear {
            loadInitialData()
        }
    }
    
    private func loadInitialData() {
        guard let user = appStateManager.currentUser else { return }
        
        heightCm = Int(user.height ?? 170)
        weightKg = Int(user.weight ?? 70)
        gender = user.gender ?? "Female"
        dateOfBirth = user.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -25, to: Date())!
        primaryGoal = user.primaryGoal ?? "Maintain Weight"
        exerciseHours = user.exerciseHoursPerWeek ?? 3
    }
    
    private func saveSettings() {
        guard let token = KeychainManager.shared.retrieveToken(),
              let user = appStateManager.currentUser else { return }
        
        isSaving = true
        errorMessage = nil
        
        // Construct updated DTO
        let dto = OnboardingProfileDTO(
            dateOfBirth: dateOfBirth,
            weightKg: Double(weightKg),
            heightCm: Double(heightCm),
            gender: gender,
            primaryGoal: primaryGoal,
            exerciseHoursPerWeek: exerciseHours,
            allergens: user.allergens,
            preferredCuisines: user.preferredCuisines,
            preferredMealTypes: user.preferredMealTypes,
            preferredDiets: user.preferredDiets
        )
        
        Task {
            do {
                _ = try await UserProfileService().updateProfile(dto, token: token)
                
                // Immediately update local SwiftData model so UI is snappy when we dismiss
                user.dateOfBirth = dateOfBirth
                user.weight = Double(weightKg)
                user.height = Double(heightCm)
                user.gender = gender
                user.primaryGoal = primaryGoal
                user.exerciseHoursPerWeek = exerciseHours
                
                dismiss()
            } catch {
                errorMessage = "Failed to save settings: \(error.localizedDescription)"
            }
            isSaving = false
        }
    }
}
