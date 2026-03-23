import Foundation
import SwiftData

/// Owns all bidirectional data movement between SwiftData and the cloud.
/// Three responsibilities:
///   1. Initial sync on login — pull cloud records into SwiftData.
///   2. Write-through sync — attempt cloud write immediately after every local change.
///   3. Foreground reconciliation flush — retry all dirty records when app becomes active.
///
/// @MainActor is applied per-method (not the class) so the init can be called
/// from any context, while methods that touch ModelContext still run on the main thread.
final class SyncService {
    private let apiClient: APIClient
    private let keychainManager: KeychainManager

    init(apiClient: APIClient = .shared, keychainManager: KeychainManager = .shared) {
        self.apiClient = apiClient
        self.keychainManager = keychainManager
    }

    // MARK: - Initial Sync (called on login for existing users)

    /// Pulls cloud data then flushes any locally-dirty records.
    /// The app stays in the `.syncing` state until this completes.
    @MainActor
    func initialSync(for userRemoteID: String, modelContext: ModelContext) async throws {
        guard let token = keychainManager.retrieveToken() else { return }
        try await pullRecentData(for: userRemoteID, token: token, modelContext: modelContext)
        try await flushPendingSync(for: userRemoteID, token: token, modelContext: modelContext)
    }

    // MARK: - Write-Through (fire-and-forget after every local save)

    /// Attempts to push a single FoodLog to the cloud in the background.
    /// On failure, needsSync stays true and the next flush will retry.
    @MainActor
    func writeThrough(foodLog: FoodLog, modelContext: ModelContext) {
        guard let token = keychainManager.retrieveToken(),
              let userRemoteID = foodLog.user?.remoteID else { return }

        Task {
            do {
                let dto = makeFoodLogDTO(from: foodLog, userRemoteID: userRemoteID)
                let saved: FoodLogDTO = foodLog.remoteID == nil
                    ? try await apiClient.post("/foodlogs", body: dto, token: token)
                    : try await apiClient.put("/foodlogs/\(foodLog.remoteID!)", body: dto, token: token)
                foodLog.remoteID = saved.remoteID
                foodLog.needsSync = false
                try? modelContext.save()
            } catch {
                // Intentionally silent — needsSync remains true for the next flush pass.
            }
        }
    }

    /// Attempts to push a single Meal to the cloud in the background.
    @MainActor
    func writeThrough(meal: Meal, modelContext: ModelContext) {
        guard let token = keychainManager.retrieveToken(),
              let userRemoteID = meal.user?.remoteID else { return }

        Task {
            do {
                let dto = makeMealDTO(from: meal, userRemoteID: userRemoteID)
                let saved: MealDTO = meal.remoteID == nil
                    ? try await apiClient.post("/meals", body: dto, token: token)
                    : try await apiClient.put("/meals/\(meal.remoteID!)", body: dto, token: token)
                meal.remoteID = saved.remoteID
                meal.needsSync = false
                try? modelContext.save()
            } catch {
                // Intentionally silent.
            }
        }
    }

    // MARK: - Foreground Reconciliation Flush

    /// Finds every dirty FoodLog and Meal and retries the cloud write.
    /// Called when the app returns to the foreground via scenePhase.
    @MainActor
    func flushPendingSync(for userRemoteID: String, token: String, modelContext: ModelContext) async throws {
        let dirtyFoodLogs = try modelContext.fetch(
            FetchDescriptor<FoodLog>(predicate: #Predicate { $0.needsSync == true })
        )
        for log in dirtyFoodLogs where log.user?.remoteID == userRemoteID {
            do {
                let dto = makeFoodLogDTO(from: log, userRemoteID: userRemoteID)
                let saved: FoodLogDTO = log.remoteID == nil
                    ? try await apiClient.post("/foodlogs", body: dto, token: token)
                    : try await apiClient.put("/foodlogs/\(log.remoteID!)", body: dto, token: token)
                log.remoteID = saved.remoteID
                log.needsSync = false
            } catch {
                // Leave needsSync = true; will retry next time.
            }
        }

        let dirtyMeals = try modelContext.fetch(
            FetchDescriptor<Meal>(predicate: #Predicate { $0.needsSync == true })
        )
        for meal in dirtyMeals where meal.user?.remoteID == userRemoteID {
            do {
                let dto = makeMealDTO(from: meal, userRemoteID: userRemoteID)
                let saved: MealDTO = meal.remoteID == nil
                    ? try await apiClient.post("/meals", body: dto, token: token)
                    : try await apiClient.put("/meals/\(meal.remoteID!)", body: dto, token: token)
                meal.remoteID = saved.remoteID
                meal.needsSync = false
            } catch {
                // Leave needsSync = true.
            }
        }

        try? modelContext.save()
    }

    // MARK: - Pull (cloud → SwiftData)

    /// Pulls FoodLog and Meal records for the past 30 days.
    /// Uses last-write-wins: local record wins if its lastModifiedAt is newer.
    @MainActor
    private func pullRecentData(for userRemoteID: String, token: String, modelContext: ModelContext) async throws {
        let remoteFoodLogs: [FoodLogDTO] = try await apiClient.get(
            "/foodlogs?userId=\(userRemoteID)&days=30", token: token
        )
        for dto in remoteFoodLogs {
            upsertFoodLog(from: dto, modelContext: modelContext)
        }

        let remoteMeals: [MealDTO] = try await apiClient.get(
            "/meals?userId=\(userRemoteID)&days=30", token: token
        )
        for dto in remoteMeals {
            upsertMeal(from: dto, modelContext: modelContext)
        }

        try? modelContext.save()
    }

    // MARK: - Upsert Helpers (Last-Write-Wins conflict resolution)

    @MainActor
    private func upsertFoodLog(from dto: FoodLogDTO, modelContext: ModelContext) {
        let remoteID = dto.remoteID
        let descriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            // Local record is newer — skip the cloud version.
            if existing.lastModifiedAt >= dto.lastModifiedAt { return }
            applyFoodLogDTO(dto, to: existing)
        } else {
            let newLog = FoodLog(name: dto.foodName, calories: dto.calories)
            applyFoodLogDTO(dto, to: newLog)
            modelContext.insert(newLog)
        }
    }

    private func applyFoodLogDTO(_ dto: FoodLogDTO, to log: FoodLog) {
        log.remoteID = dto.remoteID
        log.foodName = dto.foodName
        log.timestamp = dto.timestamp
        log.lastModifiedAt = dto.lastModifiedAt
        log.Calories = dto.calories
        log.Protein = dto.protein
        log.Carbohydrate = dto.carbohydrate
        log.Fiber = dto.fiber
        log.Calcium = dto.calcium
        log.Iron = dto.iron
        log.Potassium = dto.potassium
        log.Sodium = dto.sodium
        log.Zinc = dto.zinc
        log.VitaminA = dto.vitaminA
        log.VitaminC = dto.vitaminC
        log.VitaminD = dto.vitaminD
        log.VitaminB1 = dto.vitaminB1
        log.VitaminB2 = dto.vitaminB2
        log.VitaminB3 = dto.vitaminB3
        log.VitaminB5 = dto.vitaminB5
        log.VitaminB6 = dto.vitaminB6
        log.VitaminB9 = dto.vitaminB9
        log.VitaminB12 = dto.vitaminB12
        log.Cholesterol = dto.cholesterol
        log.TransFat = dto.transFat
        log.SaturatedFat = dto.saturatedFat
        log.MonoUnsaturatedFat = dto.monoUnsaturatedFat
        log.PolyUnsaturatedFat = dto.polyUnsaturatedFat
        log.Sugar = dto.sugar
        log.needsSync = false
    }

    @MainActor
    private func upsertMeal(from dto: MealDTO, modelContext: ModelContext) {
        let remoteID = dto.remoteID
        let descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            if existing.lastModifiedAt >= dto.lastModifiedAt { return }
            applyMealDTO(dto, to: existing)
        } else {
            let newMeal = Meal(name: dto.name, mealType: dto.mealType)
            applyMealDTO(dto, to: newMeal)
            modelContext.insert(newMeal)
        }
    }

    private func applyMealDTO(_ dto: MealDTO, to meal: Meal) {
        meal.remoteID = dto.remoteID
        meal.name = dto.name
        meal.mealType = dto.mealType
        meal.timestamp = dto.timestamp
        meal.lastModifiedAt = dto.lastModifiedAt
        meal.calories = dto.calories
        meal.protein = dto.protein
        meal.carbs = dto.carbs
        meal.fat = dto.fat
        meal.fiber = dto.fiber
        meal.calcium = dto.calcium
        meal.iron = dto.iron
        meal.potassium = dto.potassium
        meal.sodium = dto.sodium
        meal.zinc = dto.zinc
        meal.vitaminA = dto.vitaminA
        meal.vitaminD = dto.vitaminD
        meal.vitaminC = dto.vitaminC
        meal.cholesterol = dto.cholesterol
        meal.transFat = dto.transFat
        meal.saturatedFat = dto.saturatedFat
        meal.sugar = dto.sugar
        meal.needsSync = false
    }

    // MARK: - DTO Factories (SwiftData → DTO)

    private func makeFoodLogDTO(from log: FoodLog, userRemoteID: String) -> FoodLogDTO {
        FoodLogDTO(
            remoteID: log.remoteID ?? "",
            userID: userRemoteID,
            foodName: log.foodName,
            timestamp: log.timestamp,
            lastModifiedAt: log.lastModifiedAt,
            calories: log.Calories,
            protein: log.Protein,
            carbohydrate: log.Carbohydrate,
            fiber: log.Fiber,
            calcium: log.Calcium,
            iron: log.Iron,
            potassium: log.Potassium,
            sodium: log.Sodium,
            zinc: log.Zinc,
            vitaminA: log.VitaminA,
            vitaminC: log.VitaminC,
            vitaminD: log.VitaminD,
            vitaminB1: log.VitaminB1,
            vitaminB2: log.VitaminB2,
            vitaminB3: log.VitaminB3,
            vitaminB5: log.VitaminB5,
            vitaminB6: log.VitaminB6,
            vitaminB9: log.VitaminB9,
            vitaminB12: log.VitaminB12,
            cholesterol: log.Cholesterol,
            transFat: log.TransFat,
            saturatedFat: log.SaturatedFat,
            monoUnsaturatedFat: log.MonoUnsaturatedFat,
            polyUnsaturatedFat: log.PolyUnsaturatedFat,
            sugar: log.Sugar
        )
    }

    private func makeMealDTO(from meal: Meal, userRemoteID: String) -> MealDTO {
        let foodItems = (meal.foods ?? []).map { food in
            FoodItemDTO(
                remoteID: "",
                name: food.name,
                servingSize: food.servingSize,
                servingUnit: food.servingUnit,
                calories: food.calories,
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat
            )
        }
        return MealDTO(
            remoteID: meal.remoteID ?? "",
            userID: userRemoteID,
            name: meal.name,
            mealType: meal.mealType,
            timestamp: meal.timestamp,
            lastModifiedAt: meal.lastModifiedAt,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fat: meal.fat,
            fiber: meal.fiber,
            calcium: meal.calcium,
            iron: meal.iron,
            potassium: meal.potassium,
            sodium: meal.sodium,
            zinc: meal.zinc,
            vitaminA: meal.vitaminA,
            vitaminD: meal.vitaminD,
            vitaminC: meal.vitaminC,
            cholesterol: meal.cholesterol,
            transFat: meal.transFat,
            saturatedFat: meal.saturatedFat,
            sugar: meal.sugar,
            foods: foodItems
        )
    }
}
