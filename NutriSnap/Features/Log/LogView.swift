import SwiftUI
import SwiftData

struct LogsView: View {
    @Query private var allLogs: [FoodLog]
    @State private var selectedDate = Date()
    @State private var showDatePicker = false

    var logsForSelectedDate: [FoodLog] {
        let calendar = Calendar.current
        return allLogs
            .filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func mealType(from date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return "BREAKFAST"
        case 11..<15: return "LUNCH"
        case 15..<18: return "SNACK"
        case 18..<22: return "DINNER"
        default: return "MEAL"
        }
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
                                time: timeString(from: log.timestamp),
                                mealType: mealType(from: log.timestamp),
                                foodName: log.foodName,
                                calories: Int(log.Calories),
                                protein: Int(log.Protein),
                                carbs: Int(log.Carbohydrate),
                                fat: Int(log.Fat),
                                imagePath: log.imagePath
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
    var imagePath: String? = nil

    private var loadedImage: UIImage? {
        guard let path = imagePath else { return nil }
        return UIImage(contentsOfFile: path)
    }
    
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
