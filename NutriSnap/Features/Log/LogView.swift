import SwiftUI
import SwiftData

struct LogsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppStateManager.self) private var appStateManager
    @Query private var allLogs: [FoodLog]
    @State private var selectedDate = Date()
    @State private var showDatePicker = false

    private let syncService = SyncService()

    var logsForSelectedDate: [FoodLog] {
        let calendar = Calendar.current
        return allLogs
            .filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Date Selector
            HStack {
                Button(action: { previousDay() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: { showDatePicker.toggle() }) {
                    HStack(spacing: 4) {
                        Text(selectedDate, format: .dateTime.month(.wide).day().year())
                            .font(.headline)
                            .fontWeight(.bold)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: { nextDay() }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            
            
            Divider()
            
            // Card-based meal list
            ScrollView {
                VStack(spacing: 16) {
                    if logsForSelectedDate.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("No meals logged")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Tap + to add a meal")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    } else {
                        ForEach(logsForSelectedDate) { log in
                            LogEntryRow(
                                log: log,
                                onDelete: { syncService.deleteFoodLog(log, modelContext: modelContext) }
                            )
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDatePicker) {
            VStack {
                HStack {
                    Spacer()
                    Button("Done") {
                        showDatePicker = false
                    }
                    .padding()
                }
                
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                
                Spacer()
            }
            .presentationDetents([.medium])
        }
        .task {
            FoodLogImageStore.shared.reconcileStorage(modelContext: modelContext)
        }
    }
    
    private func previousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    private func nextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }

    private func delete(_ log: FoodLog) {
        FoodLogImageStore.shared.deleteImage(at: log.imagePath)
        modelContext.delete(log)
        try? modelContext.save()
    }
}

struct LogEntryRow: View {
    let log: FoodLog
    let onDelete: () -> Void

    private var loadedImage: UIImage? {
        FoodLogImageStore.shared.image(for: log.imagePath)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: log.timestamp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Time and meal type
            HStack {
                Text("\(timeString) • \(log.mealType.uppercased())")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }

            // Card with NavigationLink + trash overlay
            ZStack(alignment: .topTrailing) {
                NavigationLink(destination: FoodLogDetailView(log: log)) {
                    HStack(alignment: .center, spacing: 16) {
                        // Food image
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Group {
                                    if let uiImage = loadedImage {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "photo")
                                            .font(.title)
                                            .foregroundColor(.gray.opacity(0.5))
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Food details
                        VStack(alignment: .leading, spacing: 12) {
                            Text(log.foodName)
                                .font(.headline)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .foregroundColor(.primary)
                                .padding(.trailing, 32)

                            // Nutrition grid (2x2)
                            VStack(spacing: 8) {
                                HStack(spacing: 0) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("CALORIES")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                        Text("\(Int(log.Calories)) kcal")
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("PROTEIN")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                        Text("\(Int(log.Protein)) g")
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                HStack(spacing: 0) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("CARBS")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                        Text("\(Int(log.Carbohydrate)) g")
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("FAT")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                        Text("\(Int(log.Fat)) g")
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                // Trash delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.55))
                        .padding(16)
                }
            }
        }
    }
}

// MARK: - Food Log Detail View
struct FoodLogDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let log: FoodLog

    @State private var editedFoodName: String = ""
    @State private var isEditingFoodName: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker: Bool = false
    @State private var selectedTime: Date = Date()
    @State private var showTimePicker: Bool = false
    @State private var selectedMealType: String = ""
    @State private var editedCalories: String = ""
    @State private var editedProtein: String = ""
    @State private var editedCarbs: String = ""
    @State private var editedFat: String = ""
    @State private var editedMass: String = ""
    @FocusState private var focusedField: String?
    @FocusState private var isFoodNameFocused: Bool

    private let mealTypeOptions = ["Breakfast", "Lunch", "Tea", "Dinner", "Late Night", "Snack"]
    private let accentColor = Color(red: 0.85, green: 0.55, blue: 0.55)

    private var loadedImage: UIImage? {
        FoodLogImageStore.shared.image(for: log.imagePath)
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

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Custom Navigation Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                }
                Spacer()
                Text("Record")
                    .font(.headline)
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // MARK: - Date & Time Row
            HStack(spacing: 16) {
                Text(currentDateString)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .onTapGesture { showDatePicker = true }
                Text(currentTimeString)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .onTapGesture { showTimePicker = true }
            }
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Food Image
                    Group {
                        if let uiImage = loadedImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 240, height: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 240, height: 240)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                )
                        }
                    }

                    // MARK: - Food Name
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(accentColor)
                            .onTapGesture {
                                isEditingFoodName = true
                                isFoodNameFocused = true
                            }
                        if isEditingFoodName {
                            TextField("Food name", text: $editedFoodName)
                                .font(.title3.weight(.bold))
                                .foregroundColor(.black)
                                .focused($isFoodNameFocused)
                                .onSubmit { isEditingFoodName = false }
                        } else {
                            Text(editedFoodName)
                                .font(.title3.weight(.bold))
                                .foregroundColor(.black)
                                .onTapGesture {
                                    isEditingFoodName = true
                                    isFoodNameFocused = true
                                }
                        }
                    }

                    // MARK: - Mass / Volume
                    HStack(spacing: 4) {
                        TextField("0", text: $editedMass)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .focused($focusedField, equals: "mass")
                        Text("gram")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture { focusedField = "mass" }

                    // MARK: - Meal Type Selector
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Meal Type")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.black)
                            Spacer()
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(mealTypeOptions, id: \.self) { type in
                                    Button(action: { selectedMealType = type }) {
                                        Text(type)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(
                                                selectedMealType == type ? .white : accentColor
                                            )
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedMealType == type
                                                    ? accentColor
                                                    : accentColor.opacity(0.1)
                                            )
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }

                    // MARK: - Nutrition Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Nutrition")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.black)
                            Spacer()
                        }
                        nutritionRow(label: "Calories", editValue: $editedCalories, suffix: "kcal", fieldKey: "calories")
                        Divider().background(Color.gray.opacity(0.3))
                        nutritionRow(label: "Protein", editValue: $editedProtein, suffix: "g", fieldKey: "protein")
                        Divider().background(Color.gray.opacity(0.3))
                        nutritionRow(label: "Carbohydrates", editValue: $editedCarbs, suffix: "g", fieldKey: "carbs")
                        Divider().background(Color.gray.opacity(0.3))
                        nutritionRow(label: "Fat", editValue: $editedFat, suffix: "g", fieldKey: "fat")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            // MARK: - Save Button
            Button(action: saveChanges) {
                Text("Save")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accentColor)
                    .cornerRadius(25)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .padding(.top, 8)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .onTapGesture {
            isFoodNameFocused = false
            focusedField = nil
            if isEditingFoodName { isEditingFoodName = false }
        }
        .onAppear {
            editedFoodName = log.foodName
            selectedDate = log.timestamp
            selectedTime = log.timestamp
            selectedMealType = log.mealType
            editedCalories = String(format: "%.0f", log.Calories)
            editedProtein = String(format: "%.1f", log.Protein)
            editedCarbs = String(format: "%.1f", log.Carbohydrate)
            editedFat = String(format: "%.1f", log.Fat)
            editedMass = String(format: "%.0f", log.mass)
        }
        .sheet(isPresented: $showDatePicker) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Done") { showDatePicker = false }
                        .font(.body.weight(.semibold))
                        .foregroundColor(accentColor)
                        .padding()
                }
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(accentColor)
                    .padding()
                Spacer()
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTimePicker) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Done") { showTimePicker = false }
                        .font(.body.weight(.semibold))
                        .foregroundColor(accentColor)
                        .padding()
                }
                DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                Spacer()
            }
            .presentationDetents([.medium])
        }
    }

    private func saveChanges() {
        log.foodName = editedFoodName
        if !selectedMealType.isEmpty {
            log.mealType = selectedMealType
        }
        log.Calories = Double(editedCalories) ?? log.Calories
        log.Protein = Double(editedProtein) ?? log.Protein
        log.Carbohydrate = Double(editedCarbs) ?? log.Carbohydrate
        log.Fat = Double(editedFat) ?? log.Fat
        log.mass = Double(editedMass) ?? log.mass

        let calendar = Calendar.current
        let dateComp = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComp = calendar.dateComponents([.hour, .minute], from: selectedTime)
        var combined = DateComponents()
        combined.year = dateComp.year
        combined.month = dateComp.month
        combined.day = dateComp.day
        combined.hour = timeComp.hour
        combined.minute = timeComp.minute
        log.timestamp = calendar.date(from: combined) ?? selectedDate

        dismiss()
    }

    @ViewBuilder
    private func nutritionRow(label: String, editValue: Binding<String>, suffix: String, fieldKey: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.black)
            Spacer()
            HStack(spacing: 4) {
                TextField("", text: editValue)
                    .font(.body)
                    .foregroundColor(.black)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($focusedField, equals: fieldKey)
                Text(suffix)
                    .font(.body)
                    .foregroundColor(.black)
            }
            .onTapGesture { focusedField = fieldKey }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LogsView()
}
