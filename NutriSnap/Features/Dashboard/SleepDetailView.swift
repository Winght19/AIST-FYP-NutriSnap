import SwiftUI

struct SleepDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTimePeriod: TimePeriod = .day
    @State private var selectedReferenceDate = Date()
    @State private var sleepMetrics: SleepBreakdown

    private let sleepGoalMinutes: Double = 8 * 60

    init(initialSleep: SleepBreakdown = SleepBreakdown()) {
        _sleepMetrics = State(initialValue: initialSleep)
    }

    private var totalSleepProgress: Double {
        min(max(sleepMetrics.totalMinutes / sleepGoalMinutes, 0), 1)
    }

    private var sleepEfficiency: Double {
        let timeInBedMinutes = sleepMetrics.effectiveInBedMinutes
        guard timeInBedMinutes > 0 else { return 0 }
        return sleepMetrics.totalMinutes / timeInBedMinutes
    }

    private var sleepStages: [SleepStageDetail] {
        sleepMetrics.sleepStageDetails
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
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

                    Text("Sleep Detail")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 24)

                ScrollView {
                    VStack(spacing: UIScreen.isSmallDevice ? 20 : 24) {
                        SleepQuickStatsCard(
                            totalSleepText: formatDuration(minutes: sleepMetrics.totalMinutes),
                            inBedText: formatDuration(minutes: sleepMetrics.effectiveInBedMinutes),
                            efficiencyText: "\(Int((sleepEfficiency * 100).rounded()))%",
                            goalText: "\(Int((totalSleepProgress * 100).rounded()))%"
                        )
                        .padding(.horizontal)

                        SleepGoalProgressCard(
                            progress: totalSleepProgress,
                            totalSleepText: formatDuration(minutes: sleepMetrics.totalMinutes),
                            stages: sleepStages
                        )
                        .padding(.horizontal)

                        SleepStagesCard(stages: sleepStages)
                            .padding(.horizontal)

                        TimePeriodSelector(selectedPeriod: $selectedTimePeriod)
                            .padding(.horizontal)

                        SleepTrendView(
                            timePeriod: selectedTimePeriod,
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
            await refreshSleepMetrics()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshSleepMetrics()
            }
        }
        .onChange(of: selectedTimePeriod) { oldPeriod, newPeriod in
            selectedReferenceDate = newPeriod.referenceDateWhenSelecting(
                from: oldPeriod,
                previousReferenceDate: selectedReferenceDate
            )
        }
    }

    @MainActor
    private func refreshSleepMetrics() async {
        do {
            let dashboardMetrics = try await HealthKitService.shared.fetchDashboardMetrics()
            sleepMetrics = dashboardMetrics.sleep
        } catch {
            sleepMetrics = SleepBreakdown()
        }
    }

    private func formatDuration(minutes: Double) -> String {
        let roundedMinutes = max(Int(minutes.rounded()), 0)
        let hours = roundedMinutes / 60
        let mins = roundedMinutes % 60
        return "\(hours)h \(mins)min"
    }
}

private struct SleepGoalProgressCard: View {
    let progress: Double
    let totalSleepText: String
    let stages: [SleepStageDetail]

    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = UIScreen.isSmallDevice ? 150 : 170

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                SleepStageProgressRing(
                    progress: progress,
                    stages: stages,
                    lineWidth: 12,
                    trackColor: .indigo.opacity(0.15)
                )
                    .frame(width: circleSize, height: circleSize)

                VStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.title2)
                        .foregroundStyle(.indigo)

                    Text(totalSleepText)
                        .font(.system(size: UIScreen.isSmallDevice ? 28 : 34, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text("Total Sleep")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 4) {
                Text("Based on last night's main Apple Health sleep session")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Goal: 8h")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(20)
    }
}

private struct SleepQuickStatsCard: View {
    let totalSleepText: String
    let inBedText: String
    let efficiencyText: String
    let goalText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                SleepStatTile(title: "Asleep", value: totalSleepText, style: .asleep)
                SleepStatTile(title: "In Bed", value: inBedText, style: .inBed)
                SleepStatTile(title: "Efficiency", value: efficiencyText, style: .efficiency)
                SleepStatTile(title: "Goal Reached", value: goalText, style: .goalReached)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(20)
    }
}

private struct SleepStatTileStyle {
    let foreground: Color
    let background: Color

    static let asleep = SleepStatTileStyle(
        foreground: Color(red: 0.74, green: 0.24, blue: 0.37),
        background: Color(red: 0.98, green: 0.92, blue: 0.94)
    )
    static let inBed = SleepStatTileStyle(
        foreground: Color(red: 0.63, green: 0.42, blue: 0.16),
        background: Color(red: 0.99, green: 0.94, blue: 0.87)
    )
    static let efficiency = SleepStatTileStyle(
        foreground: Color(red: 0.16, green: 0.58, blue: 0.41),
        background: Color(red: 0.90, green: 0.97, blue: 0.93)
    )
    static let goalReached = SleepStatTileStyle(
        foreground: Color(red: 0.70, green: 0.27, blue: 0.54),
        background: Color(red: 0.97, green: 0.91, blue: 0.95)
    )
}

private struct SleepStatTile: View {
    let title: String
    let value: String
    let style: SleepStatTileStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .tracking(0.6)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(style.foreground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(style.background)
        .cornerRadius(16)
    }
}

private struct SleepTrendView: View {
    let timePeriod: TimePeriod
    @Binding var referenceDate: Date

    @State private var chartData: [SleepChartBucket] = []
    @State private var summaryValue: Double = 0

    private var maxValue: Double {
        max(chartData.map(\.trackedMinutes).max() ?? 0, 1)
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
        "\(timePeriod.title)-\(timePeriod.canonicalReferenceDate(for: referenceDate).timeIntervalSince1970)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(periodLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .tracking(1)

                Text(formatDuration(minutes: totalValue))
                    .font(.system(size: UIScreen.isSmallDevice ? 36 : 42, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                PeriodSelectionRow(timePeriod: timePeriod, referenceDate: $referenceDate)
            }

            GeometryReader { geometry in
                let spacing: CGFloat = 4
                let barWidth = (geometry.size.width - CGFloat(max(chartData.count - 1, 0)) * spacing) / CGFloat(max(chartData.count, 1))
                let labelWidth: CGFloat = UIScreen.isSmallDevice ? 22 : 26
                let maxBarHeight: CGFloat = UIScreen.isSmallDevice ? 120 : 150

                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            let barHeight = data.trackedMinutes > 0
                                ? max(CGFloat(data.trackedMinutes / maxValue) * maxBarHeight, 4)
                                : 4

                            SleepStageBar(
                                breakdown: data.breakdown,
                                hasData: data.hasData,
                                width: barWidth,
                                height: barHeight
                            )
                        }
                    }

                    ZStack(alignment: .leading) {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            if !data.label.isEmpty {
                                Text(data.label)
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
            await loadSleepData()
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
    private func loadSleepData() async {
        let calendar = Calendar.current

        do {
            switch timePeriod {
            case .day:
                let config = timePeriod.staticChartConfig(referenceDate: referenceDate)
                let hourlyBreakdowns = try await HealthKitService.shared.fetchHourlySleepBreakdowns(referenceDate: referenceDate)
                let sortedEntries = hourlyBreakdowns.sorted { $0.key < $1.key }
                let valuesByHour = sortedEntries.reduce(into: [Int: SleepBreakdown]()) { partial, entry in
                    let hour = calendar.component(.hour, from: entry.key)
                    partial[hour] = partial[hour]?.adding(entry.value) ?? entry.value
                }

                if sortedEntries.isEmpty {
                    chartData = fallbackDayBuckets(for: referenceDate)
                    summaryValue = 0
                } else {
                    chartData = config.buckets.map { bucket in
                        let hour = calendar.component(.hour, from: bucket.date)
                        let breakdown = valuesByHour[hour] ?? SleepBreakdown()
                        return SleepChartBucket(
                            label: bucket.label,
                            breakdown: breakdown,
                            hasData: breakdown.trackedMinutes > 0
                        )
                    }
                    summaryValue = sortedEntries.reduce(0) { $0 + $1.value.totalMinutes }
                }

            case .week, .month:
                let config = sleepRangeConfig(for: timePeriod, referenceDate: referenceDate)
                let dailyBreakdowns = try await HealthKitService.shared.fetchSleepBreakdownsByDay(
                    from: config.startDate,
                    to: config.displayEndDate
                )

                chartData = config.buckets.map { bucket in
                    let breakdown = dailyBreakdowns[bucket.date] ?? SleepBreakdown()
                    return SleepChartBucket(
                        label: bucket.label,
                        breakdown: breakdown,
                        hasData: breakdown.trackedMinutes > 0
                    )
                }
                summaryValue = average(from: chartData, config: config)

            case .sixMonths, .year:
                let config = sleepRangeConfig(for: timePeriod, referenceDate: referenceDate)
                let dailyBreakdowns = try await HealthKitService.shared.fetchSleepBreakdownsByDay(
                    from: config.startDate,
                    to: config.displayEndDate
                )
                let latestDay = min(calendar.startOfDay(for: Date()), config.displayEndDate)

                chartData = config.buckets.map { bucket in
                    let breakdowns = dailyBreakdowns.compactMap { date, breakdown -> SleepBreakdown? in
                        guard date <= latestDay else { return nil }
                        return calendar.isDate(date, equalTo: bucket.date, toGranularity: .month) ? breakdown : nil
                    }
                    let averagedBreakdown = averageBreakdown(from: breakdowns)
                    return SleepChartBucket(
                        label: bucket.label,
                        breakdown: averagedBreakdown ?? SleepBreakdown(),
                        hasData: (averagedBreakdown?.trackedMinutes ?? 0) > 0
                    )
                }
                summaryValue = dailyAverage(from: dailyBreakdowns, config: config)
            }
        } catch {
            chartData = fallbackBuckets(for: timePeriod)
            summaryValue = 0
        }
    }

    private func average(from points: [SleepChartBucket], config: TimePeriodChartConfig) -> Double {
        let values = points.map(\.totalSleepMinutes)
        guard !values.isEmpty else { return 0 }
        let elapsedBucketCount = min(config.elapsedBucketCount(asOf: Date()), values.count)
        let elapsedValues = Array(values.prefix(elapsedBucketCount))
        guard !elapsedValues.isEmpty else { return 0 }
        return elapsedValues.reduce(0, +) / Double(elapsedValues.count)
    }

    private func dailyAverage(from valuesByDay: [Date: SleepBreakdown], config: TimePeriodChartConfig) -> Double {
        let calendar = Calendar.current
        let latestDay = min(calendar.startOfDay(for: Date()), config.displayEndDate)
        let values = valuesByDay
            .filter { $0.key <= latestDay }
            .map { $0.value.totalMinutes }

        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func averageBreakdown(from breakdowns: [SleepBreakdown]) -> SleepBreakdown? {
        guard !breakdowns.isEmpty else { return nil }
        let total = breakdowns.reduce(SleepBreakdown()) { partial, breakdown in
            partial.adding(breakdown)
        }
        return total.scaled(by: 1 / Double(breakdowns.count))
    }

    private func fallbackBuckets(for period: TimePeriod) -> [SleepChartBucket] {
        switch period {
        case .day:
            return fallbackDayBuckets(for: referenceDate)
        case .week, .month, .sixMonths, .year:
            return sleepRangeConfig(for: period, referenceDate: referenceDate).buckets.map {
                SleepChartBucket(label: $0.label, breakdown: SleepBreakdown(), hasData: false)
            }
        }
    }

    private func fallbackDayBuckets(for referenceDate: Date) -> [SleepChartBucket] {
        TimePeriod.day.staticChartConfig(referenceDate: referenceDate).buckets.map {
            SleepChartBucket(label: $0.label, breakdown: SleepBreakdown(), hasData: false)
        }
    }

    private func sleepRangeConfig(for period: TimePeriod, referenceDate: Date) -> TimePeriodChartConfig {
        period.staticChartConfig(referenceDate: referenceDate)
    }

    private func formatDuration(minutes: Double) -> String {
        let roundedMinutes = max(Int(minutes.rounded()), 0)
        let hours = roundedMinutes / 60
        let mins = roundedMinutes % 60
        return "\(hours)h \(mins)min"
    }
}

private struct SleepChartBucket {
    let label: String
    let breakdown: SleepBreakdown
    let hasData: Bool

    var totalSleepMinutes: Double {
        breakdown.totalMinutes
    }

    var trackedMinutes: Double {
        breakdown.trackedMinutes
    }
}

private struct SleepStageBar: View {
    let breakdown: SleepBreakdown
    let hasData: Bool
    let width: CGFloat
    let height: CGFloat

    private var visibleStages: [SleepStageDetail] {
        breakdown.sleepStageDetails.filter { $0.minutes > 0 }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.1))
                .frame(width: width, height: 4)

            if hasData && breakdown.trackedMinutes > 0 {
                VStack(spacing: 0) {
                    ForEach(visibleStages) { stage in
                        Rectangle()
                            .fill(stage.color)
                            .frame(height: height * CGFloat(stage.minutes / breakdown.trackedMinutes))
                    }
                }
                .frame(width: width, height: height, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .frame(width: width, height: height, alignment: .bottom)
    }
}

private struct SleepStagesCard: View {
    let stages: [SleepStageDetail]

    private var totalTrackedMinutes: Double {
        max(stages.reduce(0) { $0 + $1.minutes }, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Stages")
                .font(.headline)

            ForEach(stages) { stage in
                SleepStageRow(stage: stage, totalTrackedMinutes: totalTrackedMinutes)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(20)
    }
}

private struct SleepStageRow: View {
    let stage: SleepStageDetail
    let totalTrackedMinutes: Double

    private var percentage: Double {
        stage.minutes / totalTrackedMinutes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(stage.color)
                        .frame(width: 10, height: 10)

                    Text(stage.title)
                        .fontWeight(.semibold)
                }

                Spacer()

                Text(stage.formattedDuration)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(stage.color.opacity(0.15))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(stage.color)
                        .frame(width: geometry.size.width * percentage, height: 12)
                }
            }
            .frame(height: 12)
        }
    }
}

enum SleepStageIdentifier: CaseIterable, Hashable {
    case awake
    case rem
    case core
    case deep

    var title: String {
        switch self {
        case .awake:
            return "Awake"
        case .rem:
            return "REM"
        case .core:
            return "Core"
        case .deep:
            return "Deep"
        }
    }

    var color: Color {
        switch self {
        case .awake:
            return .orange
        case .rem:
            return .cyan
        case .core:
            return .blue
        case .deep:
            return .indigo
        }
    }
}

struct SleepStageDetail: Identifiable {
    let id: SleepStageIdentifier
    let minutes: Double

    var title: String {
        id.title
    }

    var color: Color {
        id.color
    }

    var formattedDuration: String {
        let roundedMinutes = max(Int(minutes.rounded()), 0)
        let hours = roundedMinutes / 60
        let mins = roundedMinutes % 60
        return "\(hours)h \(mins)min"
    }
}

struct SleepStageProgressRing: View {
    let progress: Double
    let stages: [SleepStageDetail]
    let lineWidth: CGFloat
    let trackColor: Color

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    private var totalTrackedMinutes: Double {
        max(stages.reduce(0) { $0 + $1.minutes }, 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                if stage.minutes > 0 {
                    Circle()
                        .trim(from: segmentStart(for: index), to: segmentEnd(for: index))
                        .stroke(
                            stage.color,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .animation(.easeInOut(duration: 1.0), value: progress)
        .animation(.easeInOut(duration: 1.0), value: stages.map(\.minutes))
    }

    private func segmentStart(for index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        let consumed = stages[..<index].reduce(0) { $0 + $1.minutes }
        return clampedProgress * CGFloat(consumed / totalTrackedMinutes)
    }

    private func segmentEnd(for index: Int) -> CGFloat {
        let consumed = stages[...index].reduce(0) { $0 + $1.minutes }
        return clampedProgress * CGFloat(consumed / totalTrackedMinutes)
    }
}

extension SleepBreakdown {
    var trackedMinutes: Double {
        awakeMinutes + remMinutes + coreMinutes + deepMinutes
    }

    var sleepStageDetails: [SleepStageDetail] {
        SleepStageIdentifier.allCases.map { stage in
            SleepStageDetail(id: stage, minutes: minutes(for: stage))
        }
    }

    func adding(_ other: SleepBreakdown) -> SleepBreakdown {
        SleepBreakdown(
            inBedMinutes: inBedMinutes + other.inBedMinutes,
            awakeMinutes: awakeMinutes + other.awakeMinutes,
            remMinutes: remMinutes + other.remMinutes,
            coreMinutes: coreMinutes + other.coreMinutes,
            deepMinutes: deepMinutes + other.deepMinutes
        )
    }

    func scaled(by factor: Double) -> SleepBreakdown {
        SleepBreakdown(
            inBedMinutes: inBedMinutes * factor,
            awakeMinutes: awakeMinutes * factor,
            remMinutes: remMinutes * factor,
            coreMinutes: coreMinutes * factor,
            deepMinutes: deepMinutes * factor
        )
    }

    private func minutes(for stage: SleepStageIdentifier) -> Double {
        switch stage {
        case .awake:
            return awakeMinutes
        case .rem:
            return remMinutes
        case .core:
            return coreMinutes
        case .deep:
            return deepMinutes
        }
    }
}

#Preview {
    NavigationStack {
        SleepDetailView(
            initialSleep: SleepBreakdown(
                inBedMinutes: 413,
                awakeMinutes: 42,
                remMinutes: 110,
                coreMinutes: 260,
                deepMinutes: 85
            )
        )
    }
}
