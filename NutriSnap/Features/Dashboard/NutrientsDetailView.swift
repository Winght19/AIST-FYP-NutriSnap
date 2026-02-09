import SwiftUI

struct NutrientsDetailView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    
    let nutrients: [Nutrient] = [
        Nutrient(id: 1008, name: "Calories", unit: "kcal", target: 2000, current: 1850),
        Nutrient(id: 1003, name: "Protein", unit: "g", target: 56, current: 45),
        Nutrient(id: 1005, name: "Carbohydrate", unit: "g", target: 130, current: 110),
        Nutrient(id: 1079, name: "Fiber", unit: "g", target: 38, current: 15),
        Nutrient(id: 1087, name: "Calcium", unit: "mg", target: 1000, current: 650),
        Nutrient(id: 1089, name: "Iron", unit: "mg", target: 8, current: 6),
        Nutrient(id: 1092, name: "Potassium", unit: "mg", target: 3400, current: 2100),
        Nutrient(id: 1093, name: "Sodium", unit: "mg", target: 2300, current: 2450),
        Nutrient(id: 1095, name: "Zinc", unit: "mg", target: 11, current: 8),
        Nutrient(id: 1106, name: "Vitamin A", unit: "μg", target: 900, current: 720),
        Nutrient(id: 1114, name: "Vitamin D", unit: "μg", target: 15, current: 5),
        Nutrient(id: 1162, name: "Vitamin C", unit: "mg", target: 90, current: 45),
        Nutrient(id: 1165, name: "Vitamin B1", unit: "mg", target: 1.2, current: 1.0),
        Nutrient(id: 1166, name: "Vitamin B2", unit: "mg", target: 1.3, current: 1.1),
        Nutrient(id: 1167, name: "Vitamin B3", unit: "mg", target: 16, current: 14),
        Nutrient(id: 1170, name: "Vitamin B5", unit: "mg", target: 5, current: 3.5),
        Nutrient(id: 1175, name: "Vitamin B6", unit: "mg", target: 1.3, current: 1.2),
        Nutrient(id: 1177, name: "Vitamin B9", unit: "μg", target: 400, current: 320),
        Nutrient(id: 1178, name: "Vitamin B12", unit: "μg", target: 2.4, current: 1.8),
        Nutrient(id: 1253, name: "Cholesterol", unit: "mg", target: 300, current: 210),
        Nutrient(id: 1257, name: "Trans Fat", unit: "g", target: 0, current: 0.5),
        Nutrient(id: 1258, name: "Saturated Fat", unit: "g", target: 20, current: 25),
        Nutrient(id: 1292, name: "Monounsaturated Fat", unit: "g", target: 30, current: 18),
        Nutrient(id: 1293, name: "Polyunsaturated Fat", unit: "g", target: 20, current: 12),
        Nutrient(id: 2000, name: "Sugar", unit: "g", target: 36, current: 42)
    ]
    
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
