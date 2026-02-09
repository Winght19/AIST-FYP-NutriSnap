import SwiftUI

struct LogsView: View {
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    
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
                    LogEntryRow(
                        time: "08:30",
                        mealType: "BREAKFAST",
                        foodName: "Oatmeal with Fresh Berries",
                        calories: 320,
                        protein: 12,
                        carbs: 45,
                        fat: 6
                    )
                    
                    LogEntryRow(
                        time: "13:15",
                        mealType: "LUNCH",
                        foodName: "Chicken Salad Sandwich",
                        calories: 450,
                        protein: 28,
                        carbs: 38,
                        fat: 14
                    )
                    
                    LogEntryRow(
                        time: "16:40",
                        mealType: "SNACK",
                        foodName: "Apple with Almond Butter",
                        calories: 180,
                        protein: 4,
                        carbs: 22,
                        fat: 9
                    )
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
    }
    
    private func previousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    private func nextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }
}

struct LogEntryRow: View {
    let time: String
    let mealType: String
    let foodName: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Time and meal type
            HStack {
                Text("\(time) • \(mealType)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
            
            // Main card content
            HStack(alignment: .center, spacing: 16) {
                // Food image
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.gray.opacity(0.5))
                    )
                
                // Food details
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(foodName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "pencil")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Nutrition grid (2x2)
                    VStack(spacing: 8) {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CALORIES")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text("\(calories) kcal")
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PROTEIN")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text("\(protein) g")
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CARBS")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text("\(carbs) g")
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("FAT")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text("\(fat) g")
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
}

#Preview {
    LogsView()
}
