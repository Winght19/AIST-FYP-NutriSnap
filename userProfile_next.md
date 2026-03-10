The most logical next steps, in priority order:

## 1. Build in Xcode first (do this now)

Open the project and build (`⌘B`). The schema change (`User.self`, `Meal.self`, `Food.self` now added alongside `FoodLog.self`) will likely cause SwiftData to throw a migration error on first launch if you have an existing simulator store. To clear it:

```bash
# Wipe the simulator app container so SwiftData starts fresh
xcrun simctl uninstall booted com.YOUR_BUNDLE_ID
```

Fix any compiler errors that surface before moving on.

---

## 2. Build your backend (the biggest blocker)

The entire service layer is wired and ready, but it points to `https://api.nutrisnap.app` which doesn't exist yet. You need **five endpoints** minimum:

| Endpoint | Method | Purpose |
|---|---|---|
| `/auth/google` | POST | Exchange Google ID token for app JWT |
| `/user/profile` | GET | Fetch profile (validates token) |
| `/user/onboarding` | POST | Save onboarding data, return computed targets |
| `/foodlogs` | POST / PUT | Create / update a food log entry |
| `/meals` | POST / PUT | Create / update a meal |

A fast path: **Supabase** gives you auth, a Postgres DB, and auto-generated REST endpoints in under an hour. Your `APIClient` will work with any REST backend — just update the `baseURL` in `APIClient.swift`.

---

## 3. Connect `HomeView` to real SwiftData data

Currently `HomeView` has hardcoded calorie numbers. Now that `User` has `dailyCalorieGoal` and `FoodLog` has a `user` relationship, wire the query to filter by the current user:

```swift
@Query private var logs: [FoodLog]

// Replace with a predicate-filtered query once currentUser is available:
// @Query(filter: #Predicate<FoodLog> { $0.user?.remoteID == currentUserRemoteID })
```

The `NutritionSlide` card's `currentCal`, `targetCal`, and macro bars should all read from live `@Query` results.

---

## 4. Implement write-through on every food log save

Whenever a user saves a new `FoodLog` (in `NutriLog.swift` or wherever your logging flow lives), follow the pattern from Step 16:

```swift
let log = FoodLog(name: item.name, calories: item.calories, ...)
log.user = appStateManager.currentUser
modelContext.insert(log)
try? modelContext.save()                            // UI updates immediately
syncService.writeThrough(foodLog: log, modelContext: modelContext)  // cloud in background
```

---

## 5. Handle the `error` app state in your UI

Right now `ErrorView` just has a "Try Again" button that sends back to `.unauthenticated`. For network errors during sync (not auth errors), you probably want to stay `.authenticated` and show a non-blocking banner instead. That's a polish step but worth planning.