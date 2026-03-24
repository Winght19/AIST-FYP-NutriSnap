import SwiftUI
import SwiftData

struct NutrientsDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AppStateManager.self) private var appStateManager
    @Query private var logs: [FoodLog]
    
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    
    private var filteredLogs: [FoodLog] {
        logs.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: selectedDate) }
    }
    
    // Dynamically computed array of all nutrients for the selected day
    var nutrients: [Nutrient] {
        let currentCalories = filteredLogs.reduce(0) { $0 + $1.Calories }
        let currentProtein = filteredLogs.reduce(0) { $0 + $1.Protein }
        let currentCarbs = filteredLogs.reduce(0) { $0 + $1.Carbohydrate }
        let currentFat = filteredLogs.reduce(0) { $0 + $1.Fat }
        let currentFiber = filteredLogs.reduce(0) { $0 + $1.Fiber }
        let currentCalcium = filteredLogs.reduce(0) { $0 + $1.Calcium }
        let currentIron = filteredLogs.reduce(0) { $0 + $1.Iron }
        let currentPotassium = filteredLogs.reduce(0) { $0 + $1.Potassium }
        let currentSodium = filteredLogs.reduce(0) { $0 + $1.Sodium }
        let currentZinc = filteredLogs.reduce(0) { $0 + $1.Zinc }
        let currentVitaminA = filteredLogs.reduce(0) { $0 + $1.VitaminA }
        let currentVitaminC = filteredLogs.reduce(0) { $0 + $1.VitaminC }
        let currentVitaminD = filteredLogs.reduce(0) { $0 + $1.VitaminD }
        let currentVitaminB1 = filteredLogs.reduce(0) { $0 + $1.VitaminB1 }
        let currentVitaminB2 = filteredLogs.reduce(0) { $0 + $1.VitaminB2 }
        let currentVitaminB3 = filteredLogs.reduce(0) { $0 + $1.VitaminB3 }
        let currentVitaminB5 = filteredLogs.reduce(0) { $0 + $1.VitaminB5 }
        let currentVitaminB6 = filteredLogs.reduce(0) { $0 + $1.VitaminB6 }
        let currentVitaminB9 = filteredLogs.reduce(0) { $0 + $1.VitaminB9 }
        let currentVitaminB12 = filteredLogs.reduce(0) { $0 + $1.VitaminB12 }
        let currentCholesterol = filteredLogs.reduce(0) { $0 + $1.Cholesterol }
        let currentTransFat = filteredLogs.reduce(0) { $0 + $1.TransFat }
        let currentSaturatedFat = filteredLogs.reduce(0) { $0 + $1.SaturatedFat }
        let currentMonoFat = filteredLogs.reduce(0) { $0 + $1.MonoUnsaturatedFat }
        let currentPolyFat = filteredLogs.reduce(0) { $0 + $1.PolyUnsaturatedFat }
        let currentSugar = filteredLogs.reduce(0) { $0 + $1.Sugar }
        
        let targetCalories = Double(appStateManager.currentUser?.dailyCalorieGoal ?? 2000)
        let targetProtein = Double(appStateManager.currentUser?.proteinGoal ?? 60)
        let targetCarbs = Double(appStateManager.currentUser?.carbsGoal ?? 250)
        let targetFat = Double(appStateManager.currentUser?.fatGoal ?? 70)
        
        return [
            Nutrient(id: 1008, name: "Calories", unit: "kcal", target: targetCalories, current: currentCalories),
            Nutrient(id: 1003, name: "Protein", unit: "g", target: targetProtein, current: currentProtein),
            Nutrient(id: 1005, name: "Carbohydrate", unit: "g", target: targetCarbs, current: currentCarbs),
            Nutrient(id: 1004, name: "Fat", unit: "g", target: targetFat, current: currentFat),
            Nutrient(id: 1079, name: "Fiber", unit: "g", target: 38, current: currentFiber),
            Nutrient(id: 1087, name: "Calcium", unit: "mg", target: 1000, current: currentCalcium),
            Nutrient(id: 1089, name: "Iron", unit: "mg", target: 8, current: currentIron),
            Nutrient(id: 1092, name: "Potassium", unit: "mg", target: 3400, current: currentPotassium),
            Nutrient(id: 1093, name: "Sodium", unit: "mg", target: 2300, current: currentSodium),
            Nutrient(id: 1095, name: "Zinc", unit: "mg", target: 11, current: currentZinc),
            Nutrient(id: 1106, name: "Vitamin A", unit: "μg", target: 900, current: currentVitaminA),
            Nutrient(id: 1114, name: "Vitamin D", unit: "μg", target: 15, current: currentVitaminD),
            Nutrient(id: 1162, name: "Vitamin C", unit: "mg", target: 90, current: currentVitaminC),
            Nutrient(id: 1165, name: "Vitamin B1", unit: "mg", target: 1.2, current: currentVitaminB1),
            Nutrient(id: 1166, name: "Vitamin B2", unit: "mg", target: 1.3, current: currentVitaminB2),
            Nutrient(id: 1167, name: "Vitamin B3", unit: "mg", target: 16, current: currentVitaminB3),
            Nutrient(id: 1170, name: "Vitamin B5", unit: "mg", target: 5, current: currentVitaminB5),
            Nutrient(id: 1175, name: "Vitamin B6", unit: "mg", target: 1.3, current: currentVitaminB6),
            Nutrient(id: 1177, name: "Vitamin B9", unit: "μg", target: 400, current: currentVitaminB9),
            Nutrient(id: 1178, name: "Vitamin B12", unit: "μg", target: 2.4, current: currentVitaminB12),
            Nutrient(id: 1253, name: "Cholesterol", unit: "mg", target: 300, current: currentCholesterol),
            Nutrient(id: 1257, name: "Trans Fat", unit: "g", target: 0, current: currentTransFat),
            Nutrient(id: 1258, name: "Saturated Fat", unit: "g", target: 20, current: currentSaturatedFat),
            Nutrient(id: 1292, name: "Monounsaturated Fat", unit: "g", target: 30, current: currentMonoFat),
            Nutrient(id: 1293, name: "Polyunsaturated Fat", unit: "g", target: 20, current: currentPolyFat),
            Nutrient(id: 2000, name: "Sugar", unit: "g", target: 36, current: currentSugar)
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Date picker section
            ZStack {
                // Date navigation arrows (behind)
                HStack {
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal)
                
                // Date centered with dropdown (in front)
                Button(action: {
                    showDatePicker.toggle()
                }) {
                    HStack(spacing: 4) {
                        Text(selectedDate, format: .dateTime.month(.wide).day().year())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemBackground))
            
            Divider()
            
            // Nutrients list
            List {
                ForEach(nutrients) { nutrient in
                    NutrientRow(nutrient: nutrient)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Nutrients")
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
    }
}

struct NutrientRow: View {
    let nutrient: Nutrient
    
    var progress: Double {
        return min(nutrient.current / nutrient.target, 1.0)
    }
    
    var isOverTarget: Bool {
        return nutrient.current > nutrient.target
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(nutrient.name)
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Text(nutrient.current.formatted())
                            .fontWeight(.semibold)
                        Text("/")
                            .foregroundStyle(.secondary)
                        Text(nutrient.target.formatted())
                            .foregroundStyle(.secondary)
                        Text(nutrient.unit)
                            .foregroundStyle(.secondary)
                    }
                    .font(.body)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isOverTarget ? Color.orange : Color.green)
                            .frame(width: geometry.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct Nutrient: Identifiable {
    let id: Int
    let name: String
    let unit: String
    let target: Double
    let current: Double
    
    func formatted() -> String {
        if current.truncatingRemainder(dividingBy: 1) == 0 && target.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(current))"
        } else {
            return String(format: "%.1f", current)
        }
    }
}

extension Double {
    func formatted() -> String {
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(self))"
        } else {
            return String(format: "%.1f", self)
        }
    }
}

#Preview {
    NavigationStack {
        NutrientsDetailView()
    }
}
