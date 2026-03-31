import SwiftUI
import Charts
import SwiftData

struct WeightWidgetView: View {
    @Environment(AppStateManager.self) private var appStateManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date, order: .reverse) private var recentWeights: [WeightEntry]
    
    @State private var showTargetAlert = false
    @State private var targetInput = ""
    
    // Derived values
    private var currentWeight: Double? {
        recentWeights.first?.weight ?? appStateManager.currentUser?.weight
    }
    
    private var previousWeight: Double? {
        if recentWeights.count >= 2 {
            return recentWeights[1].weight
        }
        return nil
    }
    
    private var differenceTrend: String {
        guard let current = currentWeight, let previous = previousWeight else {
            return "Stable"
        }
        let diff = current - previous
        if diff > 0 {
            return String(format: "+%.1f", diff)
        } else if diff < 0 {
            return String(format: "%.1f", diff)
        }
        return "Stable"
    }

    var targetWeight: Double {
        appStateManager.currentUser?.targetWeight ?? 65.0
    }
    
    // For the UI progress ring
    var weightProgress: Double {
        guard let current = currentWeight else { return 0 }
        let startingWeight = appStateManager.currentUser?.weight ?? (targetWeight + 10.0)
        let totalToLose = startingWeight - targetWeight
        let lostSoFar = startingWeight - current
        if totalToLose <= 0 { return 1.0 }
        return min(max(lostSoFar / totalToLose, 0), 1.0)
    }

    var body: some View {
        NavigationLink(destination: WeightDetailView()) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    // Spacer for title overlay
                    Spacer()
                        .frame(height: UIScreen.isSmallDevice ? 40 : 50)
                    
                    // Top Section: Weight & Ring
                    HStack(alignment: .top) {
                        // Left: Current Weight & Trend
                        VStack(alignment: .leading, spacing: 4) {
                            if let weight = currentWeight {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(String(format: "%.1f", weight))
                                        .font(.system(size: UIScreen.isSmallDevice ? 34 : 40, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("kg")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                
                                HStack(spacing: 4) {
                                    let diffText = differenceTrend
                                    Text(diffText)
                                    Image(systemName: diffText.contains("+") ? "arrow.up" : (diffText == "Stable" ? "minus" : "arrow.down"))
                                }
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(differenceTrend.contains("+") ? .red : (differenceTrend == "Stable" ? .secondary : .green))
                            } else {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("--")
                                        .font(.system(size: UIScreen.isSmallDevice ? 34 : 40, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("kg")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                                Text("No history")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Right: Target Donut Ring
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                            
                            // Let's use 0.6 progress as a default if no data, otherwise calculate
                            let progress = currentWeight != nil ? weightProgress : 0.0
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: 2) {
                                Text("Target:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Text("\(String(format: "%.0f", targetWeight)) kg")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        }
                        .frame(width: 80, height: 80)
                        .padding(.trailing, 8)
                    }
                    .padding(.horizontal, UIScreen.isSmallDevice ? 16 : 24)
                    
                    Spacer()
                    
                    // Bottom Section: Detailed Line Chart
                    let calendar = Calendar.current
                    let endOfToday = calendar.startOfDay(for: Date()).addingTimeInterval(86400 - 1)
                    let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: Date()))!
                    let lastMonthData = recentWeights.filter { $0.date >= thirtyDaysAgo }
                    
                    if !lastMonthData.isEmpty {
                        let sortedData = lastMonthData.sorted(by: { $0.date < $1.date }) // chronologically
                        let minY = (sortedData.map { $0.weight }.min() ?? targetWeight) - 2.0
                        let maxY = (sortedData.map { $0.weight }.max() ?? targetWeight) + 2.0
                        
                        Chart(sortedData) { entry in
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("Weight", entry.weight)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.green)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            PointMark(
                                x: .value("Date", entry.date),
                                y: .value("Weight", entry.weight)
                            )
                            .foregroundStyle(Color.white)
                            .symbolSize(30)
                            
                            // Draw green outline for points
                            PointMark(
                                x: .value("Date", entry.date),
                                y: .value("Weight", entry.weight)
                            )
                            .foregroundStyle(Color.clear)
                            .symbolSize(30)
                            .annotation(position: .overlay) {
                                Circle().strokeBorder(Color.green, lineWidth: 2).frame(width: 6, height: 6)
                            }
                            
                            AreaMark(
                                x: .value("Date", entry.date),
                                yStart: .value("Min", minY),
                                yEnd: .value("Weight", entry.weight)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [Color.green.opacity(0.2), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                        .chartXScale(domain: thirtyDaysAgo...endOfToday)
                        .chartYScale(domain: minY...maxY)
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: [minY + 2.0, maxY - 2.0]) { value in
                                AxisGridLine()
                                    .foregroundStyle(Color.gray.opacity(0.3))
                                AxisValueLabel {
                                    if let d = value.as(Double.self) {
                                        Text(String(format: "%.1f", d))
                                            .font(.system(size: 12))
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                        }
                        .frame(height: UIScreen.isSmallDevice ? 90 : 110)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    } else {
                        // Empty chart placeholder
                        Spacer().frame(height: 110)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(24)
                .shadow(color: Color(UIColor.label).opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                
                // Title overlay
                Text("Weight")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
