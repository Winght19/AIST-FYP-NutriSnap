import SwiftUI
import HealthKit

struct ActivityDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedActivityType: ActivityType = .exercise
    @State private var selectedTimePeriod: TimePeriod = .day
    @State private var selectedReferenceDate = Date()
    @State private var dashboardMetrics = HealthDashboardMetrics.empty

    init(initialMetrics: HealthDashboardMetrics = .empty) {
        _dashboardMetrics = State(initialValue: initialMetrics)
    }

    private var progressPercentage: Double {
        let goal = selectedActivityType.goal
        guard goal > 0 else { return 0 }

        let value: Double
        switch selectedActivityType {
        case .steps:
            value = dashboardMetrics.steps
        case .exercise:
            value = dashboardMetrics.exerciseMinutes
        case .stand:
            value = dashboardMetrics.standMinutes
        }

        return min(max(value / goal, 0), 1)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
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
                    
                    Text("Activity Detail")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Empty space to balance the layout
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: UIScreen.isSmallDevice ? 20 : 32) {
                        // Progress Circle
                        ProgressCircleView(percentage: progressPercentage, activityType: selectedActivityType)
                            .padding(.top, UIScreen.isSmallDevice ? 8 : 16)
                        
                        // Activity Type Selector
                        ActivityTypeSelector(selectedType: $selectedActivityType)
                        
                        // Time Period Selector
                        TimePeriodSelector(selectedPeriod: $selectedTimePeriod)
                            .padding(.horizontal)
                        
                        // Exercise Trend Chart
                        ExerciseTrendView(
                            timePeriod: selectedTimePeriod,
                            activityType: selectedActivityType,
                            referenceDate: $selectedReferenceDate
                        )
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            do {
                dashboardMetrics = try await HealthKitService.shared.fetchDashboardMetrics()
            } catch {
                dashboardMetrics = .empty
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                do {
                    dashboardMetrics = try await HealthKitService.shared.fetchDashboardMetrics()
                } catch {
                    dashboardMetrics = .empty
                }
            }
        }
        .onChange(of: selectedTimePeriod) { oldPeriod, newPeriod in
            selectedReferenceDate = newPeriod.referenceDateWhenSelecting(
                from: oldPeriod,
                previousReferenceDate: selectedReferenceDate
            )
        }
    }
}

// MARK: - Activity Type Enum
enum ActivityType {
    case steps
    case exercise
    case stand
    
    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .exercise: return "figure.strengthtraining.traditional"
        case .stand: return "figure.stand"
        }
    }
    
    var title: String {
        switch self {
        case .steps: return "STEPS"
        case .exercise: return "EXERCISE"
        case .stand: return "STAND"
        }
    }
    
    var color: Color {
        switch self {
        case .steps: return .orange
        case .exercise: return .red
        case .stand: return .cyan
        }
    }

    var goal: Double {
        switch self {
        case .steps: return 10000
        case .exercise: return 30
        case .stand: return 120
        }
    }

    var hkIdentifier: HKQuantityTypeIdentifier {
        switch self {
        case .steps: return .stepCount
        case .exercise: return .appleExerciseTime
        case .stand: return .appleStandTime
        }
    }

    var hkUnit: HKUnit {
        switch self {
        case .steps: return .count()
        case .exercise, .stand: return .minute()
        }
    }
}

// MARK: - Time Period Enum
enum TimePeriod {
    case day
    case week
    case month
    case sixMonths
    case year
    
    var title: String {
        switch self {
        case .day: return "D"
        case .week: return "W"
        case .month: return "M"
        case .sixMonths: return "6M"
        case .year: return "Y"
        }
    }
}

extension TimePeriod {
    func referenceDateWhenSelecting(
        from previousPeriod: TimePeriod,
        previousReferenceDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        if self == .day, previousPeriod != .day {
            return now
        }

        return navigationReferenceDate(
            for: previousReferenceDate,
            now: now,
            calendar: calendar
        )
    }

    func canonicalReferenceDate(for date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.mondayStartOfWeek(containing: date)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? calendar.startOfDay(for: date)
        case .sixMonths:
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let startMonth = month <= 6 ? 1 : 7
            return calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? calendar.startOfDay(for: date)
        case .year:
            let year = calendar.component(.year, from: date)
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? calendar.startOfDay(for: date)
        }
    }

    func latestSelectableReferenceDate(now: Date = Date(), calendar: Calendar = .current) -> Date {
        canonicalReferenceDate(for: now, calendar: calendar)
    }

    func navigationReferenceDate(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> Date {
        let clampedDate = min(date, now)

        switch self {
        case .day:
            return calendar.isDate(clampedDate, inSameDayAs: now)
                ? now
                : calendar.startOfDay(for: clampedDate)
        case .week, .month, .sixMonths, .year:
            return canonicalReferenceDate(for: clampedDate, calendar: calendar)
        }
    }

    func shiftedReferenceDate(from referenceDate: Date, by value: Int, calendar: Calendar = .current) -> Date {
        let baseDate = canonicalReferenceDate(for: referenceDate, calendar: calendar)

        switch self {
        case .day:
            return calendar.date(byAdding: .day, value: value, to: baseDate) ?? baseDate
        case .week:
            return calendar.date(byAdding: .day, value: value * 7, to: baseDate) ?? baseDate
        case .month:
            return calendar.date(byAdding: .month, value: value, to: baseDate) ?? baseDate
        case .sixMonths:
            return calendar.date(byAdding: .month, value: value * 6, to: baseDate) ?? baseDate
        case .year:
            return calendar.date(byAdding: .year, value: value, to: baseDate) ?? baseDate
        }
    }

    func selectionLabel(referenceDate: Date, calendar: Calendar = .current) -> String {
        let normalizedDate = canonicalReferenceDate(for: referenceDate, calendar: calendar)
        let config = staticChartConfig(referenceDate: normalizedDate, calendar: calendar)

        switch self {
        case .day:
            return normalizedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .week:
            let startLabel = config.startDate.formatted(.dateTime.month(.abbreviated).day())
            let endLabel: String

            if calendar.isDate(config.startDate, equalTo: config.displayEndDate, toGranularity: .month) {
                endLabel = config.displayEndDate.formatted(.dateTime.day())
            } else {
                endLabel = config.displayEndDate.formatted(.dateTime.month(.abbreviated).day())
            }

            return "\(startLabel)-\(endLabel)"
        case .month:
            return normalizedDate.formatted(.dateTime.month(.wide).year())
        case .sixMonths:
            let startMonth = calendar.component(.month, from: config.startDate)
            let year = calendar.component(.year, from: config.startDate)
            return startMonth <= 6 ? "Jan-Jun \(year)" : "Jul-Dec \(year)"
        case .year:
            return "\(calendar.component(.year, from: normalizedDate))"
        }
    }
}

struct TimePeriodChartBucket {
    let date: Date
    let label: String
}

struct TimePeriodChartConfig {
    let startDate: Date
    let queryEndDate: Date
    let displayEndDate: Date
    let interval: DateComponents
    let anchorDate: Date
    let buckets: [TimePeriodChartBucket]

    func elapsedBucketCount(asOf referenceDate: Date) -> Int {
        let effectiveDate = min(referenceDate, displayEndDate)
        let count = buckets.prefix { $0.date <= effectiveDate }.count
        return max(count, 1)
    }

    func elapsedDayCount(asOf referenceDate: Date, calendar: Calendar = .current) -> Int {
        let effectiveDate = min(referenceDate, displayEndDate)
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: effectiveDate)
        let dayCount = (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1
        return max(dayCount, 1)
    }
}

extension Calendar {
    func mondayStartOfWeek(containing date: Date) -> Date {
        let dayStart = startOfDay(for: date)
        let weekday = component(.weekday, from: dayStart)
        let offset = (weekday + 5) % 7
        return self.date(byAdding: .day, value: -offset, to: dayStart) ?? dayStart
    }
}

extension TimePeriod {
    func staticChartConfig(referenceDate: Date = Date(), calendar: Calendar = .current) -> TimePeriodChartConfig {
        switch self {
        case .day:
            let startDay = calendar.startOfDay(for: referenceDate)
            let endDay = calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
            let labeledHours = Set([0, 6, 12, 18, 23])
            let buckets = (0..<24).map { offset in
                let date = calendar.date(byAdding: .hour, value: offset, to: startDay) ?? startDay
                let label = labeledHours.contains(offset) ? String(format: "%02d", offset) : ""
                return TimePeriodChartBucket(date: date, label: label)
            }

            return TimePeriodChartConfig(
                startDate: startDay,
                queryEndDate: endDay,
                displayEndDate: calendar.date(byAdding: .hour, value: 23, to: startDay) ?? startDay,
                interval: DateComponents(hour: 1),
                anchorDate: startDay,
                buckets: buckets
            )

        case .week:
            let startDay = calendar.mondayStartOfWeek(containing: referenceDate)
            let endDay = calendar.date(byAdding: .day, value: 7, to: startDay) ?? startDay
            let buckets = (0..<7).map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: startDay) ?? startDay
                let label = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
                return TimePeriodChartBucket(date: date, label: label)
            }

            return TimePeriodChartConfig(
                startDate: startDay,
                queryEndDate: endDay,
                displayEndDate: calendar.date(byAdding: .day, value: 6, to: startDay) ?? startDay,
                interval: DateComponents(day: 1),
                anchorDate: startDay,
                buckets: buckets
            )

        case .month:
            let monthInterval = calendar.dateInterval(of: .month, for: referenceDate) ?? DateInterval(start: referenceDate, duration: 0)
            let startDay = monthInterval.start
            let dayCount = calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 30
            let labelOffsets = Set([0, 7, 14, 21, max(dayCount - 1, 0)])
            let buckets = (0..<dayCount).map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: startDay) ?? startDay
                let label = labelOffsets.contains(offset) ? "\(calendar.component(.day, from: date))" : ""
                return TimePeriodChartBucket(date: date, label: label)
            }

            return TimePeriodChartConfig(
                startDate: startDay,
                queryEndDate: monthInterval.end,
                displayEndDate: calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? startDay,
                interval: DateComponents(day: 1),
                anchorDate: startDay,
                buckets: buckets
            )

        case .sixMonths:
            let year = calendar.component(.year, from: referenceDate)
            let month = calendar.component(.month, from: referenceDate)
            let startMonth = month <= 6 ? 1 : 7
            let startDate = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)) ?? referenceDate
            let queryEndDate = calendar.date(byAdding: .month, value: 6, to: startDate) ?? startDate
            let buckets = (0..<6).map { offset in
                let date = calendar.date(byAdding: .month, value: offset, to: startDate) ?? startDate
                let label = calendar.shortMonthSymbols[calendar.component(.month, from: date) - 1]
                return TimePeriodChartBucket(date: date, label: label)
            }

            return TimePeriodChartConfig(
                startDate: startDate,
                queryEndDate: queryEndDate,
                displayEndDate: calendar.date(byAdding: .day, value: -1, to: queryEndDate) ?? startDate,
                interval: DateComponents(month: 1),
                anchorDate: startDate,
                buckets: buckets
            )

        case .year:
            let yearInterval = calendar.dateInterval(of: .year, for: referenceDate) ?? DateInterval(start: referenceDate, duration: 0)
            let startDate = yearInterval.start
            let buckets = (0..<12).map { offset in
                let date = calendar.date(byAdding: .month, value: offset, to: startDate) ?? startDate
                let label = calendar.veryShortMonthSymbols[calendar.component(.month, from: date) - 1]
                return TimePeriodChartBucket(date: date, label: label)
            }

            return TimePeriodChartConfig(
                startDate: startDate,
                queryEndDate: yearInterval.end,
                displayEndDate: calendar.date(byAdding: .day, value: -1, to: yearInterval.end) ?? startDate,
                interval: DateComponents(month: 1),
                anchorDate: startDate,
                buckets: buckets
            )
        }
    }

    func staticRangeDescription(referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
        let config = staticChartConfig(referenceDate: referenceDate, calendar: calendar)
        let formatter = DateFormatter()

        switch self {
        case .day:
            formatter.dateFormat = "EEEE"
            return formatter.string(from: referenceDate)
        case .week, .month:
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: config.startDate))–\(formatter.string(from: config.displayEndDate)), \(calendar.component(.year, from: config.displayEndDate))"
        case .sixMonths:
            formatter.dateFormat = "MMM d, yyyy"
            return "\(formatter.string(from: config.startDate))–\(formatter.string(from: config.displayEndDate))"
        case .year:
            formatter.dateFormat = "MMM yyyy"
            return "\(formatter.string(from: config.startDate))–\(formatter.string(from: config.displayEndDate))"
        }
    }
}

// MARK: - Progress Circle View
struct ProgressCircleView: View {
    let percentage: Double
    let activityType: ActivityType
    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = UIScreen.isSmallDevice ? 140 : 160
    @ScaledMetric(relativeTo: .largeTitle) private var percentageFontSize: CGFloat = UIScreen.isSmallDevice ? 26 : 30
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                .frame(width: circleSize, height: circleSize)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: percentage)
                .stroke(
                    activityType.color,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: circleSize, height: circleSize)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: percentage)
            
            // Center text
            VStack(spacing: 4) {
                Text("\(Int(percentage * 100))%")
                    .font(.system(size: percentageFontSize, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Text("DAILY GOAL")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .tracking(1)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Activity Type Selector
struct ActivityTypeSelector: View {
    @Binding var selectedType: ActivityType
    
    var body: some View {
        HStack(spacing: 16) {
            ActivityTypeButton(
                type: .steps,
                isSelected: selectedType == .steps,
                action: { selectedType = .steps }
            )
            
            ActivityTypeButton(
                type: .exercise,
                isSelected: selectedType == .exercise,
                action: { selectedType = .exercise }
            )
            
            ActivityTypeButton(
                type: .stand,
                isSelected: selectedType == .stand,
                action: { selectedType = .stand }
            )
        }
        .padding(.horizontal)
    }
}

struct ActivityTypeButton: View {
    let type: ActivityType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? type.color : .secondary)
                
                Text(type.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? type.color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: UIScreen.isSmallDevice ? 75 : 90)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? type.color : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Time Period Selector
struct TimePeriodSelector: View {
    @Binding var selectedPeriod: TimePeriod
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach([TimePeriod.day, .week, .month, .sixMonths, .year], id: \.self) { period in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.title)
                        .font(.subheadline)
                        .fontWeight(selectedPeriod == period ? .semibold : .regular)
                        .foregroundStyle(selectedPeriod == period ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            ZStack {
                                if selectedPeriod == period {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(uiColor: .systemBackground))
                                        .matchedGeometryEffect(id: "tab", in: animation)
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}

struct PeriodSelectionRow: View {
    let timePeriod: TimePeriod
    @Binding var referenceDate: Date

    @State private var isShowingPicker = false

    private var isTodaySelected: Bool {
        Calendar.current.isDate(referenceDate, inSameDayAs: Date())
    }

    private var latestReferenceDate: Date {
        timePeriod.latestSelectableReferenceDate()
    }

    private var canMoveForward: Bool {
        timePeriod.shiftedReferenceDate(from: referenceDate, by: 1) <= latestReferenceDate
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { shift(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Button(action: { isShowingPicker = true }) {
                Text(timePeriod.selectionLabel(referenceDate: referenceDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            if timePeriod == .day {
                Button(action: jumpToToday) {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                        .opacity(isTodaySelected ? 0.65 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isTodaySelected)
            }

            Button(action: { shift(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .opacity(canMoveForward ? 1 : 0.35)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!canMoveForward)
        }
        .sheet(isPresented: $isShowingPicker) {
            PeriodSelectionSheet(timePeriod: timePeriod, referenceDate: $referenceDate)
        }
    }

    private func shift(by value: Int) {
        let shiftedDate = timePeriod.shiftedReferenceDate(from: referenceDate, by: value)
        referenceDate = timePeriod.navigationReferenceDate(
            for: min(shiftedDate, latestReferenceDate)
        )
    }

    private func jumpToToday() {
        referenceDate = Date()
    }
}

private enum HalfYearSelection: Int, CaseIterable, Identifiable {
    case first
    case second

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .first:
            return "Jan-Jun"
        case .second:
            return "Jul-Dec"
        }
    }

    var startMonth: Int {
        switch self {
        case .first:
            return 1
        case .second:
            return 7
        }
    }
}

struct PeriodSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let timePeriod: TimePeriod
    @Binding var referenceDate: Date

    @State private var tempDate: Date
    @State private var tempMonth: Int
    @State private var tempYear: Int
    @State private var tempHalfYear: HalfYearSelection

    private let calendar = Calendar.current
    private let currentDate = Date()

    init(timePeriod: TimePeriod, referenceDate: Binding<Date>) {
        self.timePeriod = timePeriod
        _referenceDate = referenceDate

        let normalizedDate = timePeriod.canonicalReferenceDate(for: referenceDate.wrappedValue)
        let month = Calendar.current.component(.month, from: normalizedDate)

        _tempDate = State(initialValue: normalizedDate)
        _tempMonth = State(initialValue: month)
        _tempYear = State(initialValue: Calendar.current.component(.year, from: normalizedDate))
        _tempHalfYear = State(initialValue: month <= 6 ? .first : .second)
    }

    private var currentYear: Int {
        calendar.component(.year, from: currentDate)
    }

    private var availableYears: [Int] {
        Array((1900...currentYear).reversed())
    }

    private var availableMonths: [Int] {
        if tempYear == currentYear {
            return Array(1...calendar.component(.month, from: currentDate))
        }
        return Array(1...12)
    }

    private var availableHalfYears: [HalfYearSelection] {
        if tempYear < currentYear {
            return HalfYearSelection.allCases
        }

        return calendar.component(.month, from: currentDate) <= 6 ? [.first] : HalfYearSelection.allCases
    }

    var body: some View {
        NavigationStack {
            VStack {
                switch timePeriod {
                case .day, .week:
                    DatePicker(
                        "",
                        selection: $tempDate,
                        in: ...currentDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding()

                case .month:
                    HStack(spacing: 0) {
                        Picker("Month", selection: $tempMonth) {
                            ForEach(availableMonths, id: \.self) { month in
                                Text(calendar.monthSymbols[month - 1]).tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("Year", selection: $tempYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text(verbatim: String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)

                case .sixMonths:
                    VStack(spacing: 20) {
                        Picker("Half", selection: $tempHalfYear) {
                            ForEach(availableHalfYears) { half in
                                Text(half.title).tag(half)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Year", selection: $tempYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text(verbatim: String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .padding()

                case .year:
                    Picker("Year", selection: $tempYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(verbatim: String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .padding()
                }

                Spacer()
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        referenceDate = selectedDateFromPicker()
                        dismiss()
                    }
                }
            }
            .presentationDetents(timePeriod == .day || timePeriod == .week ? [.medium, .large] : [.medium])
            .onChange(of: tempYear) { _, _ in
                if !availableMonths.contains(tempMonth), let lastMonth = availableMonths.last {
                    tempMonth = lastMonth
                }
                if !availableHalfYears.contains(tempHalfYear), let availableHalfYear = availableHalfYears.last {
                    tempHalfYear = availableHalfYear
                }
            }
        }
    }

    private var navigationTitle: String {
        switch timePeriod {
        case .day:
            return "Select Date"
        case .week:
            return "Select Week"
        case .month:
            return "Select Month"
        case .sixMonths:
            return "Select Half-Year"
        case .year:
            return "Select Year"
        }
    }

    private func selectedDateFromPicker() -> Date {
        let selectedDate: Date

        switch timePeriod {
        case .day, .week:
            selectedDate = tempDate
        case .month:
            selectedDate = calendar.date(from: DateComponents(year: tempYear, month: tempMonth, day: 1)) ?? currentDate
        case .sixMonths:
            selectedDate = calendar.date(from: DateComponents(year: tempYear, month: tempHalfYear.startMonth, day: 1)) ?? currentDate
        case .year:
            selectedDate = calendar.date(from: DateComponents(year: tempYear, month: 1, day: 1)) ?? currentDate
        }

        return timePeriod.navigationReferenceDate(
            for: selectedDate,
            now: currentDate,
            calendar: calendar
        )
    }
}

// MARK: - Exercise Trend View
struct ExerciseTrendView: View {
    let timePeriod: TimePeriod
    let activityType: ActivityType
    @Binding var referenceDate: Date
    @State private var chartData: [(day: String, value: Double?)] = []
    @State private var summaryValue: Double = 0
    
    private var maxValue: Double {
        chartData.compactMap { $0.value }.max() ?? 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(periodLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .tracking(1)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(totalValue))")
                        .font(.system(size: UIScreen.isSmallDevice ? 36 : 42, weight: .bold))
                    
                    Text(activityType == .steps ? "steps" : "mins")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                PeriodSelectionRow(timePeriod: timePeriod, referenceDate: $referenceDate)
            }
            
            // Bar Chart
            GeometryReader { geometry in
                let spacing: CGFloat = 4
                let barWidth = (geometry.size.width - CGFloat(chartData.count - 1) * spacing) / CGFloat(max(chartData.count, 1))
                let labelWidth: CGFloat = UIScreen.isSmallDevice ? 22 : 26

                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            if let value = data.value, value > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(activityType.color)
                                    .frame(
                                        width: barWidth,
                                        height: max(value / maxValue * (UIScreen.isSmallDevice ? 120 : 150), 4)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(
                                        width: barWidth,
                                        height: 4
                                    )
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
            await loadHealthKitData()
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

    private var periodLabel: String {
        switch timePeriod {
        case .day:
            return "Total"
        case .week, .month, .sixMonths, .year:
            return "Average"
        }
    }
    
    private var totalValue: Double {
        summaryValue
    }

    private var chartTaskID: String {
        "\(activityType.title)-\(timePeriod.title)-\(timePeriod.canonicalReferenceDate(for: referenceDate).timeIntervalSince1970)"
    }

    @MainActor
    private func loadHealthKitData() async {
        let config = queryConfig(for: timePeriod, referenceDate: referenceDate)
        let calendar = Calendar.current
        let granularity = bucketGranularity(for: timePeriod)

        do {
            let valuesByDate = try await HealthKitService.shared.fetchActivityValues(
                identifier: activityType.hkIdentifier,
                unit: activityType.hkUnit,
                from: config.startDate,
                to: config.queryEndDate,
                interval: config.interval,
                anchorDate: config.anchorDate
            )

            let points: [(day: String, value: Double?)]

            if timePeriod == .day {
                let valuesByHour = valuesByDate.reduce(into: [Int: Double]()) { partial, entry in
                    let hour = calendar.component(.hour, from: entry.key)
                    partial[hour, default: 0] += entry.value
                }

                points = config.buckets.map { bucket in
                    let hour = calendar.component(.hour, from: bucket.date)
                    return (day: bucket.label, value: valuesByHour[hour] ?? 0)
                }
            } else {
                points = config.buckets.map { bucket in
                    let value = valuesByDate.first {
                        calendar.isDate($0.key, equalTo: bucket.date, toGranularity: granularity)
                    }?.value ?? 0
                    return (day: bucket.label, value: value)
                }
            }

            chartData = points
            summaryValue = summaryValueFromChart(points, config: config)
        } catch {
            chartData = fallbackBuckets(for: timePeriod)
            summaryValue = 0
        }
    }

    private func bucketGranularity(for period: TimePeriod) -> Calendar.Component {
        switch period {
        case .day:
            return .hour
        case .week, .month:
            return .day
        case .sixMonths, .year:
            return .month
        }
    }

    private func summaryValueFromChart(_ points: [(day: String, value: Double?)], config: TimePeriodChartConfig) -> Double {
        let values = points.compactMap(\.value)
        guard !values.isEmpty else { return 0 }
        let elapsedBucketCount = min(config.elapsedBucketCount(asOf: Date()), values.count)
        let elapsedValues = Array(values.prefix(elapsedBucketCount))
        guard !elapsedValues.isEmpty else { return 0 }

        switch timePeriod {
        case .day:
            return values.reduce(0, +)
        case .week, .month:
            return elapsedValues.reduce(0, +) / Double(elapsedValues.count)
        case .sixMonths, .year:
            let dayCount = config.elapsedDayCount(asOf: Date())
            return elapsedValues.reduce(0, +) / Double(dayCount)
        }
    }

    private func fallbackBuckets(for period: TimePeriod) -> [(day: String, value: Double?)] {
        queryConfig(for: period, referenceDate: referenceDate).buckets.map { ($0.label, nil) }
    }

    private func queryConfig(for period: TimePeriod, referenceDate: Date) -> TimePeriodChartConfig {
        period.staticChartConfig(referenceDate: referenceDate)
    }
}

// MARK: - Preview
#Preview {
    ActivityDetailView()
}
