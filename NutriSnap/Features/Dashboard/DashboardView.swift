import SwiftUI
import SwiftData

// MARK: - Screen Size Helper
extension UIScreen {
    static var isSmallDevice: Bool {
        let height = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? 852
        return height <= 844 // iPhone 14, 13, 12, 11 Pro and smaller
    }
}

// 1. THE MAIN CONTAINER (Tab Bar)
struct DashboardView: View {
    @Environment(AppStateManager.self) private var appStateManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var showCameraSheet = false
    

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Use UIFontMetrics for Dynamic Type support
        let baseFont = UIFont.systemFont(ofSize: 12, weight: .medium)
        let scaledFont = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: baseFont)
        
        let baseFontBold = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let scaledFontBold = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: baseFontBold)
        
        // Customize font for tab bar items with Dynamic Type
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes = [.font: scaledFont]
        itemAppearance.selected.titleTextAttributes = [.font: scaledFontBold]
        
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar.fill")
            }
            .tag(0)
            
            NavigationStack {
                LogsView()
            }
            .tabItem {
                Label("Logs", systemImage: "fork.knife")
            }
            .tag(1)
            
            Color.clear
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(2)

            RecipesView()
                .tabItem {
                    Label("Recipes", systemImage: "book.closed.fill")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(4)
        }
        .tint(Color.red) // Matches your "Add" button color
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 2 {
                showCameraSheet = true
                selectedTab = oldValue
            }
        }
        .fullScreenCover(isPresented: $showCameraSheet) {
            CameraView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await appStateManager.handleForegroundActivation(modelContext: modelContext)
            }
        }
    }
}

// 2. THE HOME SCREEN (Header + Rings + Meals)
struct HomeView: View {
    @Environment(AppStateManager.self) private var appStateManager
    @Environment(\.scenePhase) private var scenePhase
    @Query private var logs: [FoodLog]
    @State private var currentPage = 0 // For tracking the current slide in the carousel
    @State private var healthMetrics = HealthDashboardMetrics.empty
    @Binding var selectedTab: Int

    private var calendar: Calendar {
        Calendar.current
    }

    private var nutritionGoals: NutritionGoals {
        NutritionGoals(user: appStateManager.currentUser)
    }

    private var todayLogs: [FoodLog] {
        logs.filter { calendar.isDateInToday($0.timestamp) }
    }

    private var todayCalories: Double {
        todayLogs.reduce(0) { $0 + $1.Calories }
    }

    private var todayCarbs: Double {
        todayLogs.reduce(0) { $0 + $1.Carbohydrate }
    }

    private var todayProtein: Double {
        todayLogs.reduce(0) { $0 + $1.Protein }
    }

    private var todayFat: Double {
        todayLogs.reduce(0) { $0 + $1.Fat }
    }

    private var burnedCalories: Double {
        healthMetrics.activeEnergyBurned
    }

    private var mealCaloriesToday: [MealCalories] {
        let grouped = Dictionary(grouping: todayLogs) { log in
            let mealType = log.mealType.trimmingCharacters(in: .whitespacesAndNewlines)
            return mealType.isEmpty ? "Meal" : mealType
        }

        let orderedMealTypes = ["Breakfast", "Lunch", "Tea", "Dinner", "Late Night", "Snack"]

        return grouped
            .map { mealType, entries in
                MealCalories(
                    mealType: mealType,
                    calories: entries.reduce(0) { $0 + $1.Calories },
                    itemCount: entries.count
                )
            }
            .sorted { lhs, rhs in
                let lhsIndex = orderedMealTypes.firstIndex(of: lhs.mealType) ?? Int.max
                let rhsIndex = orderedMealTypes.firstIndex(of: rhs.mealType) ?? Int.max
                if lhsIndex != rhsIndex {
                    return lhsIndex < rhsIndex
                }
                return lhs.mealType < rhs.mealType
            }
    }

    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    
                    // SECTION A: HEADER
                    
                    
                    // SECTION B: THE CAROUSEL (Nutrition / Activities / Sleep)
                    // We use a TabView with .page style to create the slider
                    VStack(spacing: 0) {
                        TabView(selection: $currentPage) {
                            NavigationLink(destination: NutrientsDetailView()) {
                                NutritionSlide(
                                    currentCal: todayCalories,
                                    targetCal: nutritionGoals.calories,
                                    burnedCal: burnedCalories,
                                    currentCarbs: todayCarbs,
                                    targetCarbs: nutritionGoals.carbs,
                                    currentProtein: todayProtein,
                                    targetProtein: nutritionGoals.protein,
                                    currentFat: todayFat,
                                    targetFat: nutritionGoals.fat
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .tag(0)
                            
                            WeightWidgetView()
                                .tag(1)

                            ActivitiesCard(metrics: healthMetrics)
                                .tag(2)
                            NavigationLink(destination: SleepDetailView(initialSleep: healthMetrics.sleep)) {
                                SleepCard(metrics: healthMetrics.sleep)
                            }
                            .buttonStyle(PlainButtonStyle())
                                .tag(3)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never)) 
                        .frame(height: geometry.size.height * 0.35)
                        
                        // Custom page indicator below the cards
                        HStack(spacing: 8) {
                            ForEach(0..<4) { index in
                                Circle()
                                    .fill(index == currentPage ? Color.gray : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, 10)
                    }

                // SECTION C: ACTIVE CALORIES
                Button {
                    Task {
                        await requestHealthAccessFromActiveCaloriesTap()
                    }
                } label: {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.title2)
                            .foregroundStyle(.pink)
                            .padding(10)
                            .background(Color.pink.opacity(0.1))
                            .clipShape(Circle())

                        VStack(alignment: .leading) {
                            Text("Active Calories")
                                .fontWeight(.semibold)
                            Text("From Apple Health")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(Int(burnedCalories.rounded()))")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("cal burned")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: Color(uiColor: .label).opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)
                
                // SECTION D: TODAY'S MEALS
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Today's Meals")
                            .font(.headline)
                        Spacer()
                        NavigationLink {
                            LogsView()
                        } label: {
                            Text("View all")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                            
                    }
                    .padding(.horizontal)

                    if mealCaloriesToday.isEmpty {
                        MealRow(mealName: "No meals logged", items: "Add a meal from the Add tab", calories: 0)
                    } else {
                        ForEach(mealCaloriesToday) { meal in
                            MealRow(
                                mealName: meal.mealType,
                                items: "\(meal.itemCount) item\(meal.itemCount == 1 ? "" : "s")",
                                calories: Int(meal.calories.rounded())
                            )
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .padding(.top)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .task {
            await refreshHealthMetrics()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshHealthMetrics()
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Good Morning, \(appStateManager.currentUser?.name.components(separatedBy: " ").first ?? "there")")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Today, \(Date().formatted(.dateTime.month().day()))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: {
                    selectedTab = 4 // Switch to Profile tab
                }) {
                Image("profile_otter")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                }                     
            }
            .padding()
            .background(.ultraThinMaterial) 
            // .background(.white.opacity(0.8)) // Option B: If you prefer simple fade
        }
        }
    }

    @MainActor
    private func refreshHealthMetrics() async {
        do {
            healthMetrics = try await HealthKitService.shared.fetchDashboardMetrics()
            print("✅ HealthKit metrics loaded: steps=\(healthMetrics.steps), exercise=\(healthMetrics.exerciseMinutes), active=\(healthMetrics.activeEnergyBurned)")
        } catch {
            print("❌ HealthKit fetch failed: \(error.localizedDescription)")
            healthMetrics = .empty
        }
    }

    @MainActor
    private func requestHealthAccessFromActiveCaloriesTap() async {
        do {
            try await HealthKitService.shared.requestReadAuthorization()
            await refreshHealthMetrics()
        } catch {
            healthMetrics = .empty
        }
    }
}


struct MealRow: View {
    let mealName: String
    let items: String
    let calories: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mealName)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Spacer()
                Text("\(calories) cal")
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            
            Text(items)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color(uiColor: .label).opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct MealCalories: Identifiable {
    let id = UUID()
    let mealType: String
    let calories: Double
    let itemCount: Int
}

// --- SLIDE 1: NUTRITION (Your Original Grid) ---
struct NutritionSlide: View {
    let currentCal: Double
    let targetCal: Double
    let burnedCal: Double
    let currentCarbs: Double
    let targetCarbs: Double
    let currentProtein: Double
    let targetProtein: Double
    let currentFat: Double
    let targetFat: Double
    @ScaledMetric(relativeTo: .body) private var scaledCircleSize: CGFloat = UIScreen.isSmallDevice ? 85 : 100
    @ScaledMetric(relativeTo: .body) private var circleLineWidth: CGFloat = UIScreen.isSmallDevice ? 7 : 8
    
    private var circleSize: CGFloat {
        UIScreen.isSmallDevice ? max(scaledCircleSize, 100) : max(scaledCircleSize, 120)
    }
    
    var remaining: Double {
        return max(targetCal - currentCal + burnedCal, 0) // target - eaten + burned
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                // Spacer for title
                Spacer()
                    .frame(height: UIScreen.isSmallDevice ? 30 : 40)
                
                // Main content: Left side stats + Right side circle
                HStack(alignment: .center, spacing: UIScreen.isSmallDevice ? 12 : 20) {
                // Left side: Eaten and Burned
                VStack(alignment: .leading, spacing: UIScreen.isSmallDevice ? 10 : 15) {
                    // Eaten
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EATEN")
                            .font(UIScreen.isSmallDevice ? .caption2 : .caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife")
                                .font(UIScreen.isSmallDevice ? .callout : .body)
                                .foregroundStyle(.green)
                            
                                Text("\(Int(currentCal))")
                                    .font(UIScreen.isSmallDevice ? .title3 : .title2)
                                    .fontWeight(.bold)
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(1)
                                
                            
                        }
                    }
                    
                    // Burned
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BURNED")
                            .font(UIScreen.isSmallDevice ? .caption2 : .caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(UIScreen.isSmallDevice ? .callout : .body)
                                .foregroundStyle(.orange)
                            
                                Text("\(Int(burnedCal.rounded()))")
                                    .font(UIScreen.isSmallDevice ? .title3 : .title2)
                                    .fontWeight(.bold)
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(1)
                                
                            
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                
                
                
                // Right side: Remaining calories circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: circleLineWidth)
                    Circle()
                        .trim(from: 0, to: min(remaining / targetCal, 1.0))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: circleLineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 1) {
                        Text("REMAINING")
                            .font(UIScreen.isSmallDevice ? .caption2 : .caption2)
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                        Text("\(Int(remaining))")
                            .font(UIScreen.isSmallDevice ? .body : .title3)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                        Text("CALORIES")
                            .font(UIScreen.isSmallDevice ? .caption2 : .caption2)
                            .foregroundStyle(.green)
                            .fontWeight(.semibold)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                }
                .frame(width: circleSize, height: circleSize)
                .layoutPriority(-1)
            }
            .padding(.horizontal, UIScreen.isSmallDevice ? 25 : 40)
            .padding(.bottom, UIScreen.isSmallDevice ? 20 : 30)
            
            // Bottom: Macros progress bars (horizontal layout)
            HStack(spacing: UIScreen.isSmallDevice ? 15 : 25) {
                MacroBar(label: "CARBS", current: currentCarbs, target: targetCarbs, unit: "g", color: .green)
                MacroBar(label: "PROTEIN", current: currentProtein, target: targetProtein, unit: "g", color: .green)
                MacroBar(label: "FAT", current: currentFat, target: targetFat, unit: "g", color: .green)
            }
            .padding(.horizontal, UIScreen.isSmallDevice ? 20 : 25)
            .padding(.bottom, UIScreen.isSmallDevice ? 10 : 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color(uiColor: .label).opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        
        // Title overlay
        Text("Daily Nutrition")
            .font(.title3)
            .fontWeight(.bold)
            .minimumScaleFactor(0.8)
            .lineLimit(1)
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
    }
}

// Macro progress bar component
struct MacroBar: View {
    let label: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(UIScreen.isSmallDevice ? .caption2 : .caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: UIScreen.isSmallDevice ? 5 : 6)
                        .fill(color.opacity(0.2))
                        .frame(height: UIScreen.isSmallDevice ? 5 : 6)
                    
                    RoundedRectangle(cornerRadius: UIScreen.isSmallDevice ? 5 : 6)
                        .fill(color)
                        .frame(width: geometry.size.width * min(current / target, 1.0), height: UIScreen.isSmallDevice ? 5 : 6)
                }
            }
            .frame(height: UIScreen.isSmallDevice ? 5 : 6)
            
            Text("\(Int(current))/\(Int(target))\(unit)")
                .font(UIScreen.isSmallDevice ? .caption : .caption)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }
}

// --- SLIDE 2: ACTIVITIES (Steps, Exercise, Stand) ---
struct ActivitiesCard: View {
    let metrics: HealthDashboardMetrics

    var body: some View {
        NavigationLink(destination: ActivityDetailView(initialMetrics: metrics)) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: UIScreen.isSmallDevice ? 8 : 12) {
                    // Spacer for title
                    Spacer()
                        .frame(height: UIScreen.isSmallDevice ? 30 : 40)
                    
                    VStack(spacing: UIScreen.isSmallDevice ? 12 : 20) {
                        ActivityRow(label: "Steps", current: metrics.steps, target: 10000, unit: "steps", color: .red)
                        ActivityRow(label: "Exercise", current: metrics.exerciseMinutes, target: 30, unit: "mins", color: .green)
                        ActivityRow(label: "Stand", current: metrics.standMinutes, target: 120, unit: "mins", color: .blue)
                    }
                    .padding(.horizontal, UIScreen.isSmallDevice ? 12 : 16)
                    .padding(.bottom, UIScreen.isSmallDevice ? 8 : 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: Color(uiColor: .label).opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
            
            // Title overlay
            Text("Activities")
                .font(.title3)
                .fontWeight(.bold)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .padding(.horizontal, 32)
                .padding(.top, 16)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActivityRow: View {
    let label: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIScreen.isSmallDevice ? 6 : 10) {
            HStack {
                Text(label)
                    .font(UIScreen.isSmallDevice ? .callout : .body)
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(current))/\(Int(target)) \(unit)")
                    .font(UIScreen.isSmallDevice ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: UIScreen.isSmallDevice ? 6 : 8)
                        .fill(color.opacity(0.2))
                        .frame(height: UIScreen.isSmallDevice ? 10 : 12)
                    
                    RoundedRectangle(cornerRadius: UIScreen.isSmallDevice ? 6 : 8)
                        .fill(color)
                        .frame(width: geometry.size.width * min(current / target, 1.0), height: UIScreen.isSmallDevice ? 10 : 12)
                }
            }
            .frame(height: UIScreen.isSmallDevice ? 10 : 12)
        }
    }
}

// --- SLIDE 3: SLEEP (Donut Chart) ---
struct SleepCard: View {
    let metrics: SleepBreakdown
    private let sleepGoalMinutes: Double = 8 * 60

    @ScaledMetric(relativeTo: .body) private var scaledDonutSize: CGFloat = UIScreen.isSmallDevice ? 100 : 120
    @ScaledMetric(relativeTo: .body) private var donutLineWidth: CGFloat = UIScreen.isSmallDevice ? 10 : 12
    
    private var donutSize: CGFloat {
        UIScreen.isSmallDevice ? max(scaledDonutSize, 80) : max(scaledDonutSize, 90)
    }

    private var sleepSegments: [(color: Color, value: Double)] {
        [
            (.orange, metrics.awakeMinutes),
            (.cyan, metrics.remMinutes),
            (.blue, metrics.coreMinutes),
            (.indigo, metrics.deepMinutes)
        ]
    }

    private var totalChartMinutes: Double {
        max(sleepSegments.reduce(0) { $0 + $1.value }, 1)
    }

    private var totalSleepText: String {
        formatDuration(minutes: metrics.totalMinutes)
    }

    private var totalSleepProgress: Double {
        min(max(metrics.totalMinutes / sleepGoalMinutes, 0), 1)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: UIScreen.isSmallDevice ? 8 : 12) {
                // Spacer for title
                Spacer()
                    .frame(height: UIScreen.isSmallDevice ? 30 : 40)
                
                HStack(spacing: UIScreen.isSmallDevice ? 12 : 20) {
                // Donut Chart
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.indigo.opacity(0.15), lineWidth: donutLineWidth)

                    Circle()
                        .trim(from: 0, to: totalSleepProgress)
                        .stroke(
                            AngularGradient(
                                colors: [.cyan, .blue, .indigo],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: donutLineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: totalSleepProgress)

                    VStack(spacing: 2) {
                        Image(systemName: "moon.stars.fill")
                            .font(UIScreen.isSmallDevice ? .body : .title3)
                            .foregroundStyle(.indigo)
                        Text(totalSleepText)
                            .font(UIScreen.isSmallDevice ? .callout : .body)
                            .fontWeight(.bold)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                }
                .frame(width: donutSize, height: donutSize)
                .layoutPriority(-1)
                Spacer()
                
                // Legend
                VStack(alignment: .leading, spacing: UIScreen.isSmallDevice ? 8 : 12) {
                    LegendItem(color: .orange, label: "Awake", value: formatDuration(minutes: metrics.awakeMinutes))
                    LegendItem(color: .cyan, label: "REM", value: formatDuration(minutes: metrics.remMinutes))
                    LegendItem(color: .blue, label: "Core", value: formatDuration(minutes: metrics.coreMinutes))
                    LegendItem(color: .indigo, label: "Deep", value: formatDuration(minutes: metrics.deepMinutes))
                }
                Spacer()
            }
            .padding(.horizontal, UIScreen.isSmallDevice ? 20 : 30)
            .padding(.bottom, UIScreen.isSmallDevice ? 8 : 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color(uiColor: .label).opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        
        // Title overlay
        Text("Sleep")
            .font(.title3)
            .fontWeight(.bold)
            .minimumScaleFactor(0.8)
            .lineLimit(1)
            .padding(.horizontal, 32)
            .padding(.top, 16)
        }
    }

    private func segmentStart(index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        let consumed = sleepSegments[..<index].reduce(0) { $0 + $1.value }
        return CGFloat(consumed / totalChartMinutes)
    }

    private func segmentEnd(index: Int) -> CGFloat {
        let consumed = sleepSegments[...index].reduce(0) { $0 + $1.value }
        return CGFloat(consumed / totalChartMinutes)
    }

    private func formatDuration(minutes: Double) -> String {
        let roundedMinutes = max(Int(minutes.rounded()), 0)
        let hours = roundedMinutes / 60
        let mins = roundedMinutes % 60
        return "\(hours)h \(mins)min"
    }
}

// Helper for Sleep Chart
struct TrimmedCircle: View {
    var start: CGFloat
    var end: CGFloat
    var color: Color
    var lineWidth: CGFloat = 12
    
    var body: some View {
        Circle()
            .trim(from: start, to: end)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            .rotationEffect(.degrees(-90))
    }
}

struct LegendItem: View {
    var color: Color
    var label: String
    var value: String
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: UIScreen.isSmallDevice ? 14 : 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(UIScreen.isSmallDevice ? .caption : .callout)
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(value)
                    .font(UIScreen.isSmallDevice ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
    }
}

struct ActiveCaloriesCard: View {
    var body: some View {
        HStack {
            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundStyle(.pink)
                .padding(10)
                .background(Color.pink.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text("Active Calories")
                    .fontWeight(.semibold)
                Text("From Apple Health")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("425").font(.title3).fontWeight(.bold)
                Text("cal burned").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color(uiColor: .label).opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

#Preview {
    DashboardView()
        .environment(AppStateManager())
}
