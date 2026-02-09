import SwiftUI

struct ActivityDetailView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedActivityType: ActivityType = .exercise
    @State private var selectedTimePeriod: TimePeriod = .week
    
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
                        ProgressCircleView(percentage: 0.66, activityType: selectedActivityType)
                            .padding(.top, UIScreen.isSmallDevice ? 8 : 16)
                        
                        // Activity Type Selector
                        ActivityTypeSelector(selectedType: $selectedActivityType)
                        
                        // Time Period Selector
                        TimePeriodSelector(selectedPeriod: $selectedTimePeriod)
                            .padding(.horizontal)
                        
                        // Exercise Trend Chart
                        ExerciseTrendView(timePeriod: selectedTimePeriod, activityType: selectedActivityType)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
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

// MARK: - Exercise Trend View
struct ExerciseTrendView: View {
    let timePeriod: TimePeriod
    let activityType: ActivityType
    
    // Get current day of week (1 = Sunday, 2 = Monday, etc.)
    private var currentWeekday: Int {
        Calendar.current.component(.weekday, from: Date())
    }
    
    // Get current hour
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    // Get current week of month
    private var currentWeekOfMonth: Int {
        let calendar = Calendar.current
        let weekOfMonth = calendar.component(.weekOfMonth, from: Date())
        return weekOfMonth
    }
    
    // Get current month
    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }
    
    // Sample data for the chart
    private var chartData: [(day: String, value: Double?)] {
        switch timePeriod {
        case .day:
            // ROLLING 24-HOUR WINDOW: Current hour is rightmost, 24 hours ago is leftmost
            // Example: If now is 14:00, show [Yesterday 15:00, 16:00, ..., Today 13:00, 14:00]
            var result: [(String, Double?)] = []
            let sampleData: [Int: Double]
            
            switch activityType {
            case .steps:
                sampleData = [
                    0: 150, 3: 50, 6: 300, 9: 800, 12: 1200, 15: 900, 18: 850, 21: 400
                ]
            case .exercise:
                sampleData = [
                    0: 0, 3: 0, 6: 5, 9: 15, 12: 20, 15: 10, 18: 25, 21: 8
                ]
            case .stand:
                sampleData = [
                    0: 0, 3: 0, 6: 30, 9: 60, 12: 45, 15: 50, 18: 55, 21: 30
                ]
            }
            
            // Generate 24 hours ending at current hour (offset 0 = now)
            for offset in stride(from: -23, through: 0, by: 1) {
                let hour = (currentHour + offset + 24) % 24
                let value = sampleData[hour]
                
                // Only show labels at regular intervals (every 6 hours)
                let label: String
                if offset == -23 || offset == -12 || offset == -6 || offset == 0 {
                    label = String(format: "%02d", hour)
                } else {
                    label = ""
                }
                
                result.append((label, value))
            }
            return result
            
        case .week:
            // ROLLING 7-DAY WINDOW: Today is rightmost, 6 days ago is leftmost
            // Example: If today is Wed, show [Last Thu, Fri, Sat, Sun, Mon, Tue, Wed]
            var result: [(String, Double?)] = []
            let calendar = Calendar.current
            let today = Date()
            let sampleData: [Int: Double]
            
            switch activityType {
            case .steps:
                sampleData = [
                    0: 3800, -1: 7000, -2: 10200, -3: 7200, -4: 6800, -5: 8500, -6: 9200
                ]
            case .exercise:
                sampleData = [
                    0: 15, -1: 30, -2: 45, -3: 25, -4: 20, -5: 38, -6: 42
                ]
            case .stand:
                sampleData = [
                    0: 180, -1: 240, -2: 300, -3: 210, -4: 195, -5: 270, -6: 285
                ]
            }
            
            // Generate 7 days ending today (offset 0 = today)
            for daysAgo in stride(from: -6, through: 0, by: 1) {
                let date = calendar.date(byAdding: .day, value: daysAgo, to: today)!
                let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
                let value = sampleData[daysAgo]
                result.append((dayName, value))
            }
            return result
            
        case .month:
            // ROLLING 30-DAY WINDOW: Today is rightmost, 29 days ago is leftmost
            // NOT calendar month - shows last 30 days regardless of month boundaries
            var result: [(String, Double?)] = []
            let calendar = Calendar.current
            let today = Date()
            let randomValues: [Double]
            
            switch activityType {
            case .steps:
                randomValues = [
                    5200, 6300, 7100, 5800, 6500, 7200, 8100, 5900, 6700, 7500,
                    6200, 5400, 7800, 6900, 7300, 5600, 6100, 7600, 8200, 6400,
                    5700, 6800, 7400, 5500, 6600, 7000, 5300, 6200, 7100, 6500
                ]
            case .exercise:
                randomValues = [
                    25, 30, 35, 22, 28, 32, 40, 26, 31, 36,
                    28, 20, 38, 33, 35, 24, 27, 37, 42, 29,
                    26, 32, 36, 23, 30, 34, 25, 28, 35, 30
                ]
            case .stand:
                randomValues = [
                    180, 210, 240, 165, 195, 225, 270, 185, 220, 255,
                    195, 150, 260, 230, 240, 170, 200, 250, 280, 205,
                    185, 225, 245, 160, 210, 235, 175, 195, 240, 210
                ]
            }
            
            // Generate 30 days ending today (offset 0 = today)
            for daysAgo in stride(from: -29, through: 0, by: 1) {
                let date = calendar.date(byAdding: .day, value: daysAgo, to: today)!
                let day = calendar.component(.day, from: date)
                
                // Show labels at specific intervals for better visibility
                let label: String
                let position = daysAgo + 29  // Convert to 0-based index
                if position == 0 || position == 7 || position == 14 || position == 21 || position == 29 {
                    label = "\(day)"
                } else {
                    label = ""
                }
                
                let value = randomValues[position]
                result.append((label, value))
            }
            return result
            
        case .sixMonths:
            // ROLLING 6-MONTH WINDOW: Current month is rightmost, 5 months ago is leftmost
            // NOT fixed calendar period - shows last 6 months from today
            var result: [(String, Double?)] = []
            let calendar = Calendar.current
            let today = Date()
            let monthlyValues: [Double]
            
            switch activityType {
            case .steps:
                monthlyValues = [6800, 5500, 4800, 7800, 10500, 4200]
            case .exercise:
                monthlyValues = [28, 22, 20, 32, 42, 18]
            case .stand:
                monthlyValues = [220, 185, 170, 250, 300, 160]
            }
            
            // Generate 6 months ending at current month (offset 0 = this month)
            for monthsAgo in stride(from: -5, through: 0, by: 1) {
                let date = calendar.date(byAdding: .month, value: monthsAgo, to: today)!
                let monthName = calendar.shortMonthSymbols[calendar.component(.month, from: date) - 1]
                let value = monthlyValues[monthsAgo + 5]
                result.append((monthName, value))
            }
            return result
            
        case .year:
            // ROLLING 12-MONTH WINDOW: Current month is rightmost, 11 months ago is leftmost
            // NOT fixed calendar year - shows last 12 months from today
            var result: [(String, Double?)] = []
            let calendar = Calendar.current
            let today = Date()
            let yearlyValues: [Double]
            
            switch activityType {
            case .steps:
                yearlyValues = [
                    6500, 4200, 5800, 4500, 4800, 10200, 6200, 5500, 4500, 3800, 8800, 3500
                ]
            case .exercise:
                yearlyValues = [
                    28, 18, 25, 20, 22, 42, 27, 24, 20, 16, 38, 15
                ]
            case .stand:
                yearlyValues = [
                    215, 160, 200, 175, 180, 295, 220, 195, 175, 150, 270, 140
                ]
            }
            
            // Generate 12 months ending at current month (offset 0 = this month)
            for monthsAgo in stride(from: -11, through: 0, by: 1) {
                let date = calendar.date(byAdding: .month, value: monthsAgo, to: today)!
                let monthSymbol = calendar.veryShortMonthSymbols[calendar.component(.month, from: date) - 1]
                let value = yearlyValues[monthsAgo + 11]
                result.append((monthSymbol, value))
            }
            return result
        }
    }
    
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
                
                Text(dateRangeDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Bar Chart
            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                        VStack(spacing: 4) {
                            if let value = data.value, value > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(activityType.color)
                                    .frame(
                                        width: (geometry.size.width - CGFloat(chartData.count - 1) * 4) / CGFloat(chartData.count),
                                        height: max(value / maxValue * (UIScreen.isSmallDevice ? 120 : 150), 4)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(
                                        width: (geometry.size.width - CGFloat(chartData.count - 1) * 4) / CGFloat(chartData.count),
                                        height: 4
                                    )
                            }
                            
                            Text(data.day)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(height: 16)
                                .opacity(data.day.isEmpty ? 0 : 1)
                        }
                        .id(index)
                    }
                }
            }
            .frame(height: UIScreen.isSmallDevice ? 150 : 180)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
    }
    
    private var periodLabel: String {
        switch timePeriod {
        case .day: return "TOTAL"
        case .week: return "AVERAGE"
        case .month: return "AVERAGE"
        case .sixMonths: return "DAILY AVERAGE"
        case .year: return "DAILY AVERAGE"
        }
    }
    
    private var totalValue: Double {
        switch timePeriod {
        case .day: return 3977
        case .week: return 6257
        case .month: return 6725
        case .sixMonths: return 6567
        case .year: return 6007
        }
    }
    
    private var dateRangeDescription: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let today = Date()
        
        switch timePeriod {
        case .day:
            formatter.dateFormat = "EEEE"
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            return formatter.string(from: yesterday)
            
        case .week:
            formatter.dateFormat = "MMM d"
            let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
            return "\(formatter.string(from: weekStart))–\(formatter.string(from: today)), \(calendar.component(.year, from: today))"
            
        case .month:
            formatter.dateFormat = "MMM d"
            let monthStart = calendar.date(byAdding: .day, value: -30, to: today)!
            return "\(formatter.string(from: monthStart))–\(formatter.string(from: today)), \(calendar.component(.year, from: today))"
            
        case .sixMonths:
            formatter.dateFormat = "MMM d, yyyy"
            let sixMonthsStart = calendar.date(byAdding: .month, value: -6, to: today)!
            return "\(formatter.string(from: sixMonthsStart))–\(formatter.string(from: today))"
            
        case .year:
            formatter.dateFormat = "MMM yyyy"
            let yearStart = calendar.date(byAdding: .year, value: -1, to: today)!
            return "\(formatter.string(from: yearStart))–\(formatter.string(from: today))"
        }
    }
}

// MARK: - Preview
#Preview {
    ActivityDetailView()
}
