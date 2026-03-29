import Foundation
import HealthKit

struct SleepBreakdown {
    var inBedMinutes: Double = 0
    var awakeMinutes: Double = 0
    var remMinutes: Double = 0
    var coreMinutes: Double = 0
    var deepMinutes: Double = 0

    var totalMinutes: Double {
        remMinutes + coreMinutes + deepMinutes
    }

    var effectiveInBedMinutes: Double {
        if inBedMinutes > 0 {
            return inBedMinutes
        }
        return totalMinutes + awakeMinutes
    }
}

struct HealthDashboardMetrics {
    var steps: Double = 0
    var exerciseMinutes: Double = 0
    var standMinutes: Double = 0
    var activeEnergyBurned: Double = 0
    var sleep: SleepBreakdown = SleepBreakdown()

    static let empty = HealthDashboardMetrics()
}

enum HealthKitServiceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Health data is not available on this device."
        }
    }
}

final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    private init() {}

    private func safeSumQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        from startDate: Date,
        to endDate: Date,
        unit: HKUnit
    ) async -> Double {
        do {
            let values = try await fetchActivityValues(
                identifier: identifier,
                unit: unit,
                from: startDate,
                to: endDate,
                interval: DateComponents(day: 1),
                anchorDate: startDate
            )
            return values.values.reduce(0, +)
        } catch {
            print("Failed to fetch \(identifier.rawValue): \(error)")
            return 0
        }
    }

    func fetchDashboardMetrics() async throws -> HealthDashboardMetrics {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.unavailable
        }

        try await requestAuthorization()

        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        async let steps = safeSumQuantity(
            .stepCount,
            from: startOfDay,
            to: now,
            unit: .count()
        )

        async let exerciseMinutes = safeSumQuantity(
            .appleExerciseTime,
            from: startOfDay,
            to: now,
            unit: .minute()
        )

        async let standMinutes = safeSumQuantity(
            .appleStandTime,
            from: startOfDay,
            to: now,
            unit: .minute()
        )

        async let activeEnergyBurned = safeSumQuantity(
            .activeEnergyBurned,
            from: startOfDay,
            to: now,
            unit: .kilocalorie()
        )

        async let sleep = fetchSleepBreakdown(referenceDate: now)

        return HealthDashboardMetrics(
            steps: try await steps,
            exerciseMinutes: try await exerciseMinutes,
            standMinutes: try await standMinutes,
            activeEnergyBurned: try await activeEnergyBurned,
            sleep: try await sleep
        )
    }

    func fetchActivityValues(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date,
        interval: DateComponents,
        anchorDate: Date
    ) async throws -> [Date: Double] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.unavailable
        }

        try await requestAuthorization()

        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return [:]
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var valuesByDate: [Date: Double] = [:]
                collection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    valuesByDate[statistics.startDate] = value
                }

                continuation.resume(returning: valuesByDate)
            }

            healthStore.execute(query)
        }
    }

    func fetchSleepTotalsByDay(from startDate: Date, to endDate: Date) async throws -> [Date: Double] {
        guard startDate <= endDate else { return [:] }
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.unavailable
        }

        try await requestAuthorization()

        let calendar = self.calendar
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        let queryStart = calendar.date(byAdding: .hour, value: -18, to: startDay) ?? startDay
        let queryEnd = min(Date(), calendar.date(byAdding: .hour, value: 12, to: endDay) ?? endDay)
        let samples = try await fetchSleepSamples(from: queryStart, to: queryEnd)

        var valuesByDay: [Date: Double] = [:]
        var currentDay = startDay

        while currentDay <= endDay {
            let dayQueryEnd = min(Date(), calendar.date(byAdding: .hour, value: 12, to: currentDay) ?? currentDay)
            let breakdown = sleepBreakdown(
                from: samples,
                referenceDate: currentDay,
                queryEnd: dayQueryEnd
            )
            valuesByDay[currentDay] = breakdown?.totalMinutes ?? 0
            currentDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
        }

        return valuesByDay
    }

    func fetchHourlySleepValues(referenceDate: Date) async throws -> [Date: Double] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.unavailable
        }

        try await requestAuthorization()

        let window = sleepQueryWindow(for: referenceDate, queryEnd: referenceDate)
        let samples = try await fetchSleepSamples(from: window.queryStart, to: window.queryEnd)
        guard let session = mainSleepSession(
            from: samples,
            queryStart: window.queryStart,
            queryEnd: window.queryEnd,
            overnightStart: window.overnightStart,
            overnightEnd: window.overnightEnd,
            startOfDay: window.startOfDay
        ) else {
            return [:]
        }

        let asleepIntervals = mergedIntervals(
            for: samples.compactMap { sample in
                let overlap = overlapInterval(
                    for: sample,
                    within: session,
                    queryStart: window.queryStart,
                    queryEnd: window.queryEnd
                )
                guard let overlap else { return nil }

                switch sample.value {
                case HKCategoryValueSleepAnalysis.awake.rawValue,
                     HKCategoryValueSleepAnalysis.inBed.rawValue:
                    return nil
                default:
                    return overlap
                }
            }
        )

        let sessionStartHour = calendar.dateInterval(of: .hour, for: session.start)?.start ?? session.start
        var bucketStart = sessionStartHour
        var valuesByHour: [Date: Double] = [:]

        while bucketStart < session.end {
            let bucketEnd = min(
                calendar.date(byAdding: .hour, value: 1, to: bucketStart) ?? session.end,
                session.end
            )

            let bucketInterval = DateInterval(start: bucketStart, end: bucketEnd)
            let minutes = asleepIntervals.reduce(0.0) { partial, interval in
                let overlapStart = max(interval.start, bucketInterval.start)
                let overlapEnd = min(interval.end, bucketInterval.end)
                guard overlapEnd > overlapStart else { return partial }
                return partial + overlapEnd.timeIntervalSince(overlapStart) / 60.0
            }

            valuesByHour[bucketStart] = minutes
            bucketStart = calendar.date(byAdding: .hour, value: 1, to: bucketStart) ?? bucketEnd
        }

        return valuesByHour
    }

    private func requestAuthorization() async throws {
        var readTypes = Set<HKObjectType>()

        if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(stepType)
        }
        if let exerciseType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            readTypes.insert(exerciseType)
        }
        if let standType = HKObjectType.quantityType(forIdentifier: .appleStandTime) {
            readTypes.insert(standType)
        }
        if let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(activeEnergyType)
        }
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleepType)
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    // Removed sumQuantity since safeSumQuantity now uses fetchActivityValues

    private func fetchSleepBreakdown(referenceDate: Date) async throws -> SleepBreakdown {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.unavailable
        }

        try await requestAuthorization()

        let window = sleepQueryWindow(for: referenceDate, queryEnd: referenceDate)
        let samples = try await fetchSleepSamples(from: window.queryStart, to: window.queryEnd)

        return sleepBreakdown(
            from: samples,
            referenceDate: referenceDate,
            queryEnd: referenceDate
        ) ?? SleepBreakdown()
    }

    private func fetchSleepSamples(from startDate: Date, to endDate: Date) async throws -> [HKCategorySample] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: []
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }

            self.healthStore.execute(query)
        }
    }

    private func sleepQueryWindow(
        for referenceDate: Date,
        queryEnd: Date? = nil
    ) -> (startOfDay: Date, overnightStart: Date, overnightEnd: Date, queryStart: Date, queryEnd: Date) {
        let startOfDay = calendar.startOfDay(for: referenceDate)
        let overnightStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay) ?? referenceDate
        let overnightEnd = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? referenceDate
        let queryStart = calendar.date(byAdding: .hour, value: -12, to: overnightStart) ?? overnightStart
        let effectiveQueryEnd = min(queryEnd ?? overnightEnd, overnightEnd)

        return (startOfDay, overnightStart, overnightEnd, queryStart, effectiveQueryEnd)
    }

    private func sleepBreakdown(
        from samples: [HKCategorySample],
        referenceDate: Date,
        queryEnd: Date? = nil
    ) -> SleepBreakdown? {
        guard !samples.isEmpty else { return nil }

        let window = sleepQueryWindow(for: referenceDate, queryEnd: queryEnd)
        let mainSession = mainSleepSession(
            from: samples,
            queryStart: window.queryStart,
            queryEnd: window.queryEnd,
            overnightStart: window.overnightStart,
            overnightEnd: window.overnightEnd,
            startOfDay: window.startOfDay
        )

        guard let mainSession else { return nil }

        var inBedIntervals: [DateInterval] = []
        var awakeIntervals: [DateInterval] = []
        var remIntervals: [DateInterval] = []
        var coreIntervals: [DateInterval] = []
        var deepIntervals: [DateInterval] = []

        for sample in samples {
            let overlap = overlapInterval(
                for: sample,
                within: mainSession,
                queryStart: window.queryStart,
                queryEnd: window.queryEnd
            )
            guard let overlap else { continue }

            switch sample.value {
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awakeIntervals.append(overlap)
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remIntervals.append(overlap)
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                coreIntervals.append(overlap)
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deepIntervals.append(overlap)
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                inBedIntervals.append(overlap)
            default:
                coreIntervals.append(overlap)
            }
        }

        return SleepBreakdown(
            inBedMinutes: mergedDurationMinutes(for: inBedIntervals),
            awakeMinutes: mergedDurationMinutes(for: awakeIntervals),
            remMinutes: mergedDurationMinutes(for: remIntervals),
            coreMinutes: mergedDurationMinutes(for: coreIntervals),
            deepMinutes: mergedDurationMinutes(for: deepIntervals)
        )
    }

    private func mainSleepSession(
        from samples: [HKCategorySample],
        queryStart: Date,
        queryEnd: Date,
        overnightStart: Date,
        overnightEnd: Date,
        startOfDay: Date
    ) -> DateInterval? {
        let sessionSeedIntervals = samples.compactMap { sample in
            overlapInterval(for: sample, within: nil, queryStart: queryStart, queryEnd: queryEnd)
        }

        let sessions = mergedIntervals(for: sessionSeedIntervals, gapTolerance: 60 * 60)
        guard !sessions.isEmpty else { return nil }

        let overnightCandidates = sessions.filter { session in
            session.end > overnightStart && session.start < overnightEnd
        }

        let preferredCandidates = overnightCandidates.filter { session in
            session.end > startOfDay
        }

        return longestInterval(in: preferredCandidates)
            ?? longestInterval(in: overnightCandidates)
            ?? longestInterval(in: sessions)
    }

    private func longestInterval(in intervals: [DateInterval]) -> DateInterval? {
        intervals.max { lhs, rhs in
            if lhs.duration == rhs.duration {
                return lhs.end < rhs.end
            }
            return lhs.duration < rhs.duration
        }
    }

    private func overlapInterval(
        for sample: HKCategorySample,
        within session: DateInterval?,
        queryStart: Date,
        queryEnd: Date
    ) -> DateInterval? {
        let boundedStart = max(sample.startDate, queryStart)
        let boundedEnd = min(sample.endDate, queryEnd)
        guard boundedEnd > boundedStart else { return nil }

        if let session {
            let sessionStart = max(boundedStart, session.start)
            let sessionEnd = min(boundedEnd, session.end)
            guard sessionEnd > sessionStart else { return nil }
            return DateInterval(start: sessionStart, end: sessionEnd)
        }

        return DateInterval(start: boundedStart, end: boundedEnd)
    }

    private func mergedDurationMinutes(for intervals: [DateInterval]) -> Double {
        let merged = mergedIntervals(for: intervals)
        let seconds = merged.reduce(0.0) { $0 + $1.duration }
        return seconds / 60.0
    }

    private func mergedIntervals(
        for intervals: [DateInterval],
        gapTolerance: TimeInterval = 0
    ) -> [DateInterval] {
        guard !intervals.isEmpty else { return [] }

        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [DateInterval] = [sorted[0]]

        for current in sorted.dropFirst() {
            guard let last = merged.last else {
                merged.append(current)
                continue
            }

            if current.start <= last.end.addingTimeInterval(gapTolerance) {
                let combined = DateInterval(start: last.start, end: max(last.end, current.end))
                merged[merged.count - 1] = combined
            } else {
                merged.append(current)
            }
        }

        return merged
    }
}
