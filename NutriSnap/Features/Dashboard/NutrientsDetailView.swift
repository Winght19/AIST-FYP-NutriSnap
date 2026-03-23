import SwiftUI
import SwiftData

struct NutrientsDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Query private var logs: [FoodLog]
    @State private var selectedDate = Date()
    @State private var showDatePicker = false

    private var calendar: Calendar {
        Calendar.current
    }

    private var logsForSelectedDate: [FoodLog] {
        logs.filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
    }

    private func sum(_ keyPath: KeyPath<FoodLog, Double>) -> Double {
        logsForSelectedDate.reduce(0) { $0 + $1[keyPath: keyPath] }
    }

    private var nutrients: [Nutrient] {
        [
            Nutrient(id: 1008, name: "Calories", unit: "kcal", target: 2000, current: sum(\.Calories)),
            Nutrient(id: 1003, name: "Protein", unit: "g", target: 56, current: sum(\.Protein)),
            Nutrient(id: 1005, name: "Carbohydrate", unit: "g", target: 130, current: sum(\.Carbohydrate)),
            Nutrient(id: 1004, name: "Fat", unit: "g", target: 80, current: sum(\.Fat))
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
