import SwiftUI
import SwiftData
import Charts

struct WeightDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppStateManager.self) private var appStateManager
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    
    @State private var showingAddWeight = false
    @State private var inputWeightText = ""
    @State private var inputDate = Date()
    @State private var editingEntry: WeightEntry? = nil
    
    @State private var selectedTimePeriod: TimePeriod = .month
    @State private var showingTargetAlert = false
    @State private var targetInput = ""
    
    private let syncService = SyncService()
    
    private var chartDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let end = today.addingTimeInterval(86400 - 1)
        
        let start: Date
        switch selectedTimePeriod {
        case .day: start = today
        case .week: start = calendar.date(byAdding: .day, value: -6, to: today)!
        case .month: start = calendar.date(byAdding: .day, value: -29, to: today)!
        case .sixMonths: start = calendar.date(byAdding: .month, value: -5, to: today)!
        case .year: start = calendar.date(byAdding: .month, value: -11, to: today)!
        }
        return start...end
    }
    
    private var filteredEntries: [WeightEntry] {
        let range = chartDateRange
        return weightEntries.filter { range.contains($0.date) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Chart Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Weight History")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            targetInput = String(format: "%.1f", appStateManager.currentUser?.targetWeight ?? 65.0)
                            showingTargetAlert = true
                        }) {
                            Text("Target: \(String(format: "%.0f", appStateManager.currentUser?.targetWeight ?? 65.0)) kg")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                        }
                    }
                    
                    WeightTimePeriodSelector(selectedPeriod: $selectedTimePeriod)
                        .padding(.vertical, 8)
                    
                    if filteredEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No weight data found in this period.")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 200)
                    } else {
                        let targetW = appStateManager.currentUser?.targetWeight ?? 65.0
                        let maxW = filteredEntries.map { $0.weight }.max() ?? targetW
                        
                        Chart {
                            // Target Line
                            RuleMark(y: .value("Target", targetW))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                                .foregroundStyle(Color.gray.opacity(0.5))
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("Target").font(.caption2).foregroundColor(.gray)
                                        .padding(.trailing, 4)
                                }
                            
                            // Current Weight Data
                            ForEach(filteredEntries.sorted(by: { $0.date < $1.date })) { entry in
                                LineMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Weight", entry.weight)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(.green)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                
                                PointMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Weight", entry.weight)
                                )
                                .foregroundStyle(Color.white)
                                .symbolSize(40)
                                
                                PointMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Weight", entry.weight)
                                )
                                .foregroundStyle(Color.clear)
                                .symbolSize(40)
                                .annotation(position: .overlay) {
                                    Circle()
                                        .strokeBorder(Color.green, lineWidth: 2)
                                        .frame(width: 8, height: 8)
                                        .background(Circle().fill(Color(UIColor.systemGroupedBackground)))
                                }
                                
                                AreaMark(
                                    x: .value("Date", entry.date),
                                    yStart: .value("Min", 0),
                                    yEnd: .value("Weight", entry.weight)
                                )
                                .interpolationMethod(.monotone)
                                .foregroundStyle(.linearGradient(colors: [Color.green.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                            }
                        }
                        .chartXScale(domain: chartDateRange)
                        .chartYScale(domain: 0...(maxW + 20))
                        .chartXAxis {
                            switch selectedTimePeriod {
                            case .week, .month:
                                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                        .foregroundStyle(Color.gray)
                                }
                            case .sixMonths, .year:
                                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                                        .foregroundStyle(Color.gray)
                                }
                            default:
                                AxisMarks()
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                                AxisGridLine()
                                    .foregroundStyle(Color.gray.opacity(0.2))
                                AxisValueLabel {
                                    if let d = value.as(Double.self) {
                                        Text("\(Int(d))").foregroundStyle(Color.gray)
                                    }
                                }
                            }
                        }
                        .frame(height: 250)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                
                // Log Button
                Button(action: {
                    inputWeightText = String(format: "%.1f", weightEntries.first?.weight ?? appStateManager.currentUser?.weight ?? 70.0)
                    inputDate = Date()
                    editingEntry = nil
                    showingAddWeight = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Log Weight")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.blue)
                    .cornerRadius(26)
                }
                .padding(.horizontal)
                
                // History List
                VStack(alignment: .leading, spacing: 0) {
                    Text("Recent Entries")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    if weightEntries.isEmpty {
                        Text("Start logging your weight to see your history here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(weightEntries) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(format: "%.1f kg", entry.weight))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text(entry.date, style: .date)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                Button(action: {
                                    // Set data for editing
                                    editingEntry = entry
                                    inputWeightText = String(format: "%.1f", entry.weight)
                                    inputDate = entry.date
                                    showingAddWeight = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                        .padding(8)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                
                                Button(action: {
                                    deleteEntry(entry)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .padding(8)
                                        .background(Color.red.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.top)
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Weight Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Target Weight (kg)", isPresented: $showingTargetAlert) {
            TextField("e.g., 65.0", text: $targetInput)
                .keyboardType(.decimalPad)
            Button("Save") {
                if let newWeight = Double(targetInput), let user = appStateManager.currentUser {
                    user.targetWeight = newWeight
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingAddWeight) {
            NavigationView {
                Form {
                    Section {
                        TextField("Weight (kg)", text: $inputWeightText)
                            .keyboardType(.decimalPad)
                        
                        DatePicker("Date", selection: $inputDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                .navigationTitle(editingEntry == nil ? "Log Weight" : "Edit Weight")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingAddWeight = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveWeight() }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    // MARK: - Actions
    
    private func saveWeight() {
        guard let weightVal = Double(inputWeightText) else { return }
        
        if let entry = editingEntry {
            // Update existing entry
            entry.weight = weightVal
            entry.date = inputDate
            entry.lastModifiedAt = Date()
            entry.needsSync = true
            
            // If this is the newest entry or only entry, update the user weight too
            if let newestEntry = weightEntries.first, newestEntry.id == entry.id {
                appStateManager.currentUser?.weight = weightVal
            }
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to save weight: \(error)")
            }
            
            syncService.writeThrough(weightEntry: entry, modelContext: modelContext)
        } else {
            // Create new entry
            let newEntry = WeightEntry(date: inputDate, weight: weightVal)
            newEntry.user = appStateManager.currentUser
            modelContext.insert(newEntry)
            
            // Apply to User if newer than the first
            if weightEntries.isEmpty || inputDate >= weightEntries.first!.date {
                appStateManager.currentUser?.weight = weightVal
            }
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to save new weight: \(error)")
            }
            
            syncService.writeThrough(weightEntry: newEntry, modelContext: modelContext)
        }
        
        showingAddWeight = false
    }
    
    private func deleteEntry(_ entry: WeightEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        // Note: Supabase deletion would require a DELETE endpoint.
        // For now, the record is removed locally. On next pull, if it
        // still exists remotely, it will be re-created.
    }
}

// Custom Selector to match User's Image requirements
struct WeightTimePeriodSelector: View {
    @Binding var selectedPeriod: TimePeriod
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach([TimePeriod.week, .month, .sixMonths, .year], id: \.self) { period in
                Button(action: {
                    withAnimation {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.title)
                        .font(.system(size: 16))
                        .fontWeight(selectedPeriod == period ? .bold : .medium)
                        .foregroundStyle(selectedPeriod == period ? Color.red : Color.red.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

