import SwiftUI
import SwiftData

struct NutrientsDetailView: View {
    @Environment(AppStateManager.self) private var appStateManager
    @Environment(\.dismiss) var dismiss
    @Query private var logs: [FoodLog]
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    @State private var selectedTimePeriod: TimePeriod = .day
    @State private var selectedNutrientType: NutrientType?

    private var calendar: Calendar {
        Calendar.current
    }

    private var logsForSelectedDate: [FoodLog] {
        logs.filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
    }

    private func sum(_ keyPath: KeyPath<FoodLog, Double>) -> Double {
        logsForSelectedDate.reduce(0) { $0 + $1[keyPath: keyPath] }
    }

    private var nutritionGoals: NutritionGoals {
        NutritionGoals(user: appStateManager.currentUser)
    }

    private var nutrients: [Nutrient] {
        [
            Nutrient(id: 1008, type: .calories, name: "Calories", unit: "kcal", target: nutritionGoals.calories, current: sum(\.Calories)),
            Nutrient(id: 1003, type: .protein, name: "Protein", unit: "g", target: nutritionGoals.protein, current: sum(\.Protein)),
            Nutrient(id: 1005, type: .carbohydrate, name: "Carbohydrate", unit: "g", target: nutritionGoals.carbs, current: sum(\.Carbohydrate)),
            Nutrient(id: 1004, type: .fat, name: "Fat", unit: "g", target: nutritionGoals.fat, current: sum(\.Fat))
        ]
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar (matches Activity/Sleep)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("Nutrients")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)

                ScrollViewReader { proxy in
                    ScrollView {
                    VStack(spacing: UIScreen.isSmallDevice ? 16 : 20) {
                        // Date picker card (daily intake focuses on a specific day)
                        NutrientsDatePickerCard(
                            selectedDate: $selectedDate,
                            showDatePicker: $showDatePicker
                        )
                        .padding(.horizontal)

                        // Daily nutrient progress (main focus, shown first)
                        NutrientsProgressCard(
                            nutrients: nutrients,
                            selectedNutrientType: selectedNutrientType
                        ) { nutrientType in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedNutrientType = nutrientType
                            }
                        }
                            .padding(.horizontal)

                        if let selectedNutrientType {
                            TimePeriodSelector(selectedPeriod: $selectedTimePeriod)
                                .padding(.horizontal)

                            NutritionTrendCard(
                                timePeriod: selectedTimePeriod,
                                referenceDate: selectedDate,
                                logs: logs,
                                nutrientType: selectedNutrientType,
                                nutrientGoal: nutrients.first(where: { $0.type == selectedNutrientType })?.target ?? 1
                            )
                            .padding(.horizontal)
                            .id("selected-nutrition-chart")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.bottom, 100)
                    }
                    .onChange(of: selectedNutrientType) { _, newValue in
                        guard newValue != nil else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("selected-nutrition-chart", anchor: .top)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
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

private struct NutrientsDatePickerCard: View {
    @Binding var selectedDate: Date
    @Binding var showDatePicker: Bool

    private var canMoveForward: Bool {
        Calendar.current.isDateInToday(selectedDate) == false && selectedDate < Date()
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            }) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { showDatePicker.toggle() }) {
                HStack(spacing: 6) {
                    Text(selectedDate, format: .dateTime.month(.wide).day().year())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: {
                guard canMoveForward else { return }
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            }) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .opacity(canMoveForward ? 1 : 0.35)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!canMoveForward)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
    }
}

private struct NutrientsProgressCard: View {
    let nutrients: [Nutrient]
    let selectedNutrientType: NutrientType?
    let onSelect: (NutrientType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Daily Intake")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(Array(nutrients.enumerated()), id: \.element.id) { index, nutrient in
                Button(action: {
                    onSelect(nutrient.type)
                }) {
                    NutrientRow(
                        nutrient: nutrient,
                        isSelected: selectedNutrientType == nutrient.type
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                if index < nutrients.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
    }
}

private struct NutritionTrendCard: View {
    let timePeriod: TimePeriod
    let referenceDate: Date
    let logs: [FoodLog]
    let nutrientType: NutrientType
    let nutrientGoal: Double

    @State private var chartData: [(day: String, value: Double?)] = []
    @State private var summaryValue: Double = 0

    private var maxValue: Double {
        max(chartData.compactMap(\.value).max() ?? 0, timePeriod == .day ? nutrientGoal : 1)
    }

    private var periodLabel: String {
        switch timePeriod {
        case .day:
            return "Total"
        case .week, .month, .sixMonths, .year:
            return "Average"
        }
    }

    private var chartTaskID: String {
        let normalized = timePeriod.canonicalReferenceDate(for: referenceDate)
        let lastModified = logs.map(\.lastModifiedAt).max() ?? .distantPast
        return "\(nutrientType.name)-\(timePeriod.title)-\(normalized.timeIntervalSince1970)-\(lastModified.timeIntervalSince1970)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(periodLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .tracking(1)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(nutrientType.formattedValue(summaryValue))
                        .font(.system(size: UIScreen.isSmallDevice ? 36 : 42, weight: .bold))

                    Text(nutrientType.unit)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(nutrientType.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(timePeriod.staticRangeDescription(referenceDate: referenceDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            GeometryReader { geometry in
                let spacing: CGFloat = 4
                let barWidth = (geometry.size.width - CGFloat(max(chartData.count - 1, 0)) * spacing) / CGFloat(max(chartData.count, 1))
                let labelWidth: CGFloat = UIScreen.isSmallDevice ? 22 : 26

                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { _, data in
                            if let value = data.value, value > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(nutrientType.color)
                                    .frame(
                                        width: barWidth,
                                        height: max(value / maxValue * (UIScreen.isSmallDevice ? 120 : 150), 4)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: barWidth, height: 4)
                            }
                        }
                    }

                    ZStack(alignment: .leading) {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            if !data.day.isEmpty {
                                Text(data.day)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: labelWidth, height: 16)
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                                    .offset(
                                        x: labelOffset(
                                            for: index,
                                            barWidth: barWidth,
                                            spacing: spacing,
                                            totalWidth: geometry.size.width,
                                            labelWidth: labelWidth
                                        )
                                    )
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: 16, alignment: .leading)
                }
            }
            .frame(height: UIScreen.isSmallDevice ? 150 : 180)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .task(id: chartTaskID) {
            await loadChartData()
        }
    }

    private func labelOffset(
        for index: Int,
        barWidth: CGFloat,
        spacing: CGFloat,
        totalWidth: CGFloat,
        labelWidth: CGFloat
    ) -> CGFloat {
        let centeredX = CGFloat(index) * (barWidth + spacing) + (barWidth / 2) - (labelWidth / 2)
        return min(max(centeredX, 0), max(totalWidth - labelWidth, 0))
    }

    @MainActor
    private func loadChartData() async {
        let calendar = Calendar.current
        let normalized = timePeriod.canonicalReferenceDate(for: referenceDate, calendar: calendar)
        let config = timePeriod.staticChartConfig(referenceDate: normalized, calendar: calendar)
        let relevantLogs = logs.filter { $0.timestamp >= config.startDate && $0.timestamp < config.queryEndDate }

        switch timePeriod {
        case .day:
            let valuesByHour = relevantLogs.reduce(into: [Int: Double]()) { partial, log in
                let hour = calendar.component(.hour, from: log.timestamp)
                partial[hour, default: 0] += nutrientType.value(from: log)
            }

            let points = config.buckets.map { bucket in
                let hour = calendar.component(.hour, from: bucket.date)
                return (day: bucket.label, value: valuesByHour[hour] ?? 0)
            }

            chartData = points
            summaryValue = points.compactMap(\.value).reduce(0, +)

        case .week, .month:
            let valuesByDay = relevantLogs.reduce(into: [Date: Double]()) { partial, log in
                let day = calendar.startOfDay(for: log.timestamp)
                partial[day, default: 0] += nutrientType.value(from: log)
            }

            let points = config.buckets.map { bucket in
                let day = calendar.startOfDay(for: bucket.date)
                return (day: bucket.label, value: valuesByDay[day] ?? 0)
            }

            chartData = points
            summaryValue = averageSummary(points: points, config: config)

        case .sixMonths, .year:
            let valuesByMonth = relevantLogs.reduce(into: [Date: Double]()) { partial, log in
                let components = calendar.dateComponents([.year, .month], from: log.timestamp)
                let monthStart = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)) ?? calendar.startOfDay(for: log.timestamp)
                partial[monthStart, default: 0] += nutrientType.value(from: log)
            }

            let points = config.buckets.map { bucket in
                let components = calendar.dateComponents([.year, .month], from: bucket.date)
                let monthStart = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)) ?? bucket.date
                return (day: bucket.label, value: valuesByMonth[monthStart] ?? 0)
            }

            chartData = points
            summaryValue = averageSummary(points: points, config: config)
        }
    }

    private func averageSummary(points: [(day: String, value: Double?)], config: TimePeriodChartConfig) -> Double {
        let values = points.compactMap(\.value)
        guard !values.isEmpty else { return 0 }
        let elapsedBucketCount = min(config.elapsedBucketCount(asOf: Date()), values.count)
        let elapsedValues = Array(values.prefix(elapsedBucketCount))
        guard !elapsedValues.isEmpty else { return 0 }

        switch timePeriod {
        case .day:
            return elapsedValues.reduce(0, +)
        case .week, .month:
            return elapsedValues.reduce(0, +) / Double(elapsedValues.count)
        case .sixMonths, .year:
            let dayCount = config.elapsedDayCount(asOf: Date())
            return elapsedValues.reduce(0, +) / Double(dayCount)
        }
    }
}

enum NutrientType: String, CaseIterable, Identifiable {
    case calories
    case protein
    case carbohydrate
    case fat

    var id: String { rawValue }

    var name: String {
        switch self {
        case .calories:
            return "Calories"
        case .protein:
            return "Protein"
        case .carbohydrate:
            return "Carbohydrate"
        case .fat:
            return "Fat"
        }
    }

    var unit: String {
        switch self {
        case .calories:
            return "kcal"
        case .protein, .carbohydrate, .fat:
            return "g"
        }
    }

    var color: Color {
        switch self {
        case .calories:
            return .red
        case .protein:
            return .blue
        case .carbohydrate:
            return .orange
        case .fat:
            return .yellow
        }
    }

    func value(from log: FoodLog) -> Double {
        switch self {
        case .calories:
            return log.Calories
        case .protein:
            return log.Protein
        case .carbohydrate:
            return log.Carbohydrate
        case .fat:
            return log.Fat
        }
    }

    func formattedValue(_ value: Double) -> String {
        switch self {
        case .calories:
            return "\(Int(value.rounded()))"
        case .protein, .carbohydrate, .fat:
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(value))"
            } else {
                return String(format: "%.1f", value)
            }
        }
    }
}

struct NutrientRow: View {
    let nutrient: Nutrient
    let isSelected: Bool
    
    var progress: Double {
        return min(nutrient.current / nutrient.target, 1.0)
    }
    
    var isOverTarget: Bool {
        return nutrient.current > nutrient.target
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(nutrient.name)
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Text(nutrient.formatted())
                            .fontWeight(.semibold)
                        Text("/")
                            .foregroundStyle(.secondary)
                        Text(nutrient.formattedTarget())
                            .foregroundStyle(.secondary)
                        Text(nutrient.unit)
                            .foregroundStyle(.secondary)
                    }
                    .font(.body)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.gray.opacity(0.18))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isOverTarget ? Color.orange : nutrient.type.color)
                            .frame(width: geometry.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(isSelected ? nutrient.type.color : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(nutrient.type.color.opacity(isSelected ? 0.10 : 0.001))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? nutrient.type.color.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct Nutrient: Identifiable {
    let id: Int
    let type: NutrientType
    let name: String
    let unit: String
    let target: Double
    let current: Double

    func formatted() -> String {
        type.formattedValue(current)
    }

    func formattedTarget() -> String {
        type.formattedValue(target)
    }
}

struct NutritionGoals {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    init(user: User?) {
        calories = user?.dailyCalorieGoal ?? 2000
        protein = user?.proteinGoal ?? 150
        carbs = user?.carbsGoal ?? 250
        fat = user?.fatGoal ?? 70
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
