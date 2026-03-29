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
        [
            SleepStageDetail(title: "Awake", color: .orange, minutes: sleepMetrics.awakeMinutes),
            SleepStageDetail(title: "REM", color: .cyan, minutes: sleepMetrics.remMinutes),
            SleepStageDetail(title: "Core", color: .blue, minutes: sleepMetrics.coreMinutes),
            SleepStageDetail(title: "Deep", color: .indigo, minutes: sleepMetrics.deepMinutes)
        ]
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
                        SleepGoalProgressCard(
                            progress: totalSleepProgress,
                            totalSleepText: formatDuration(minutes: sleepMetrics.totalMinutes)
                        )
                        .padding(.horizontal)

                        SleepQuickStatsCard(
                            totalSleepText: formatDuration(minutes: sleepMetrics.totalMinutes),
                            inBedText: formatDuration(minutes: sleepMetrics.effectiveInBedMinutes),
                            efficiencyText: "\(Int((sleepEfficiency * 100).rounded()))%",
                            goalText: "\(Int((totalSleepProgress * 100).rounded()))%"
                        )
                        .padding(.horizontal)

                        TimePeriodSelector(selectedPeriod: $selectedTimePeriod)
                            .padding(.horizontal)

                        SleepTrendView(
                            timePeriod: selectedTimePeriod,
                            referenceDate: $selectedReferenceDate
                        )
                        .padding(.horizontal)

                        SleepStagesCard(stages: sleepStages)
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
        .onChange(of: selectedTimePeriod) { _, newPeriod in
            selectedReferenceDate = newPeriod.canonicalReferenceDate(for: min(selectedReferenceDate, Date()))
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

    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = UIScreen.isSmallDevice ? 150 : 170

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.indigo.opacity(0.15), lineWidth: 12)
                    .frame(width: circleSize, height: circleSize)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.cyan, .blue, .indigo],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: progress)

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
                SleepStatTile(title: "Asleep", value: totalSleepText, tint: .indigo)
                SleepStatTile(title: "In Bed", value: inBedText, tint: .orange)
                SleepStatTile(title: "Efficiency", value: efficiencyText, tint: .green)
                SleepStatTile(title: "Goal Reached", value: goalText, tint: .blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(20)
    }
}

private struct SleepStatTile: View {
    let title: String
    let value: String
    let tint: Color

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
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(tint.opacity(0.12))
        .cornerRadius(16)
    }
}

private struct SleepTrendView: View {
    let timePeriod: TimePeriod
    @Binding var referenceDate: Date

    @State private var chartData: [(day: String, value: Double?)] = []
    @State private var summaryValue: Double = 0

    private var maxValue: Double {
        max(chartData.compactMap(\.value).max() ?? 0, timePeriod == .day ? 60 : 1)
    }

    private var periodLabel: String {
        switch timePeriod {
        case .day: return "TOTAL SLEEP"
        case .week, .month: return "AVERAGE SLEEP"
        case .sixMonths, .year: return "DAILY AVERAGE"
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

                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            if let value = data.value, value > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.indigo)
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
                let hourlyValues = try await HealthKitService.shared.fetchHourlySleepValues(referenceDate: referenceDate)
                let sortedEntries = hourlyValues.sorted { $0.key < $1.key }
                let valuesByHour = sortedEntries.reduce(into: [Int: Double]()) { partial, entry in
                    let hour = calendar.component(.hour, from: entry.key)
                    partial[hour, default: 0] += entry.value
                }

                if sortedEntries.isEmpty {
                    chartData = fallbackDayBuckets(for: referenceDate)
                    summaryValue = 0
                } else {
                    chartData = config.buckets.map { bucket in
                        let hour = calendar.component(.hour, from: bucket.date)
                        return (day: bucket.label, value: valuesByHour[hour] ?? 0)
                    }
                    summaryValue = sortedEntries.reduce(0) { $0 + $1.value }
                }

            case .week, .month:
                let config = sleepRangeConfig(for: timePeriod, referenceDate: referenceDate)
                let dailyValues = try await HealthKitService.shared.fetchSleepTotalsByDay(
                    from: config.startDate,
                    to: config.displayEndDate
                )

                chartData = config.buckets.map { bucket in
                    (day: bucket.label, value: dailyValues[bucket.date] ?? 0)
                }
                summaryValue = average(from: chartData, config: config)

            case .sixMonths, .year:
                let config = sleepRangeConfig(for: timePeriod, referenceDate: referenceDate)
                let dailyValues = try await HealthKitService.shared.fetchSleepTotalsByDay(
                    from: config.startDate,
                    to: config.displayEndDate
                )
                let latestDay = min(calendar.startOfDay(for: Date()), config.displayEndDate)

                chartData = config.buckets.map { bucket in
                    let values = dailyValues.compactMap { date, value -> Double? in
                        guard date <= latestDay else { return nil }
                        return calendar.isDate(date, equalTo: bucket.date, toGranularity: .month) ? value : nil
                    }
                    let averageValue = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
                    return (day: bucket.label, value: averageValue)
                }
                summaryValue = dailyAverage(from: dailyValues, config: config)
            }
        } catch {
            chartData = fallbackBuckets(for: timePeriod)
            summaryValue = 0
        }
    }

    private func average(from points: [(day: String, value: Double?)], config: TimePeriodChartConfig) -> Double {
        let values = points.compactMap(\.value)
        guard !values.isEmpty else { return 0 }
        let elapsedBucketCount = min(config.elapsedBucketCount(asOf: Date()), values.count)
        let elapsedValues = Array(values.prefix(elapsedBucketCount))
        guard !elapsedValues.isEmpty else { return 0 }
        return elapsedValues.reduce(0, +) / Double(elapsedValues.count)
    }

    private func dailyAverage(from valuesByDay: [Date: Double], config: TimePeriodChartConfig) -> Double {
        let calendar = Calendar.current
        let latestDay = min(calendar.startOfDay(for: Date()), config.displayEndDate)
        let values = valuesByDay
            .filter { $0.key <= latestDay }
            .map(\.value)

        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func fallbackBuckets(for period: TimePeriod) -> [(day: String, value: Double?)] {
        switch period {
        case .day:
            return fallbackDayBuckets(for: referenceDate)
        case .week, .month, .sixMonths, .year:
            return sleepRangeConfig(for: period, referenceDate: referenceDate).buckets.map { ($0.label, nil) }
        }
    }

    private func fallbackDayBuckets(for referenceDate: Date) -> [(day: String, value: Double?)] {
        TimePeriod.day.staticChartConfig(referenceDate: referenceDate).buckets.map { ($0.label, nil) }
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

private struct SleepStageDetail: Identifiable {
    let id = UUID()
    let title: String
    let color: Color
    let minutes: Double

    var formattedDuration: String {
        let roundedMinutes = max(Int(minutes.rounded()), 0)
        let hours = roundedMinutes / 60
        let mins = roundedMinutes % 60
        return "\(hours)h \(mins)min"
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
