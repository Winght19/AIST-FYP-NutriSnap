# NutriSnap Data Models

This folder contains the SwiftData models that define the core data structure for the NutriSnap application. These models handle user accounts, meal logging, and nutritional tracking.

## Overview

The data architecture consists of three main entities with the following relationships:
- **User** (1) → (Many) **Meals** → (Many) **Foods**

```
User
├── meals: [Meal]
    └── foods: [Food]
```

---

## Files

### 1. `User.swift`

Represents a registered user account with their profile information and nutritional goals.

#### Properties

**Unique Identifiers:**
- `id: UUID` - Unique identifier for the user (auto-generated)
- `email: String` - User's email address (unique, stored in lowercase)

**Authentication:**
- `passwordHash: String` - Hashed password using SHA256 for secure storage
- `createdAt: Date` - Account creation timestamp

**Profile Information:**
- `name: String` - User's display name
- `age: Int?` - User's age (optional)
- `weight: Double?` - User's weight in kilograms (optional)
- `height: Double?` - User's height in centimeters (optional)
- `gender: String?` - User's gender (optional)
- `activityLevel: String?` - Activity level: "sedentary", "light", "moderate", "active", "very_active" (optional)

**Daily Nutritional Goals:**
- `dailyCalorieGoal: Double` - Target daily calorie intake (default: 2000)
- `proteinGoal: Double` - Target daily protein in grams (default: 150g)
- `carbsGoal: Double` - Target daily carbohydrates in grams (default: 250g)
- `fatGoal: Double` - Target daily fat in grams (default: 70g)

**Relationships:**
- `meals: [Meal]?` - Collection of all meals logged by the user (cascade delete)

#### Initialization
```swift
User(email: String, name: String, passwordHash: String)
```
- Automatically generates UUID and sets creation date
- Converts email to lowercase
- Sets default nutritional goals

---

### 2. `Meal.swift`

Represents a single meal or eating occasion (breakfast, lunch, dinner, snack) logged by a user.

#### Properties

**Identifiers:**
- `id: UUID` - Unique identifier for the meal (auto-generated)
- `name: String` - Name/description of the meal
- `mealType: String` - Type of meal: "breakfast", "lunch", "dinner", "snack"
- `timestamp: Date` - When the meal was consumed

**Media:**
- `imageData: Data?` - Binary data for meal photo (optional)

**Basic Macronutrients:**
- `calories: Double` - Total calories (kcal)
- `protein: Double` - Total protein (g)
- `carbs: Double` - Total carbohydrates (g)
- `fat: Double` - Total fat (g)

**Detailed Macronutrients:**
- `fiber: Double?` - Dietary fiber (g)
- `sugar: Double?` - Total sugars (g)
- `cholesterol: Double?` - Cholesterol (mg)
- `transFat: Double?` - Trans fat (g)
- `saturatedFat: Double?` - Saturated fat (g)
- `monounsaturatedFat: Double?` - Monounsaturated fat (g)
- `polyunsaturatedFat: Double?` - Polyunsaturated fat (g)

**Minerals:**
- `calcium: Double?` - Calcium (mg)
- `iron: Double?` - Iron (mg)
- `potassium: Double?` - Potassium (mg)
- `sodium: Double?` - Sodium (mg)
- `zinc: Double?` - Zinc (mg)

**Vitamins:**
- `vitaminA: Double?` - Vitamin A (μg)
- `vitaminD: Double?` - Vitamin D (μg)
- `vitaminC: Double?` - Vitamin C (mg)
- `vitaminB1: Double?` - Thiamine/B1 (mg)
- `vitaminB2: Double?` - Riboflavin/B2 (mg)
- `vitaminB3: Double?` - Niacin/B3 (mg)
- `vitaminB5: Double?` - Pantothenic Acid/B5 (mg)
- `vitaminB6: Double?` - Pyridoxine/B6 (mg)
- `vitaminB9: Double?` - Folate/B9 (μg)
- `vitaminB12: Double?` - Cobalamin/B12 (μg)

**Relationships:**
- `user: User?` - The user who logged this meal
- `foods: [Food]?` - Collection of individual food items in this meal (cascade delete)

#### Initialization
```swift
Meal(name: String, mealType: String, timestamp: Date = Date())
```
- Automatically generates UUID
- Defaults timestamp to current date/time
- Initializes macronutrients to 0

---

### 3. `Food.swift`

Represents an individual food item within a meal, including serving size and complete nutritional information.

#### Properties

**Identifiers:**
- `id: UUID` - Unique identifier for the food item (auto-generated)
- `name: String` - Name of the food item

**Serving Information:**
- `servingSize: Double` - Quantity of the serving (e.g., 1, 0.5, 2)
- `servingUnit: String` - Unit of measurement (e.g., "cup", "oz", "g", "serving")

**Basic Macronutrients:**
- `calories: Double` - Calories per serving (kcal)
- `protein: Double` - Protein per serving (g)
- `carbs: Double` - Carbohydrates per serving (g)
- `fat: Double` - Fat per serving (g)

**Detailed Macronutrients:**
- `fiber: Double?` - Dietary fiber (g)
- `sugar: Double?` - Total sugars (g)
- `cholesterol: Double?` - Cholesterol (mg)
- `transFat: Double?` - Trans fat (g)
- `saturatedFat: Double?` - Saturated fat (g)
- `monounsaturatedFat: Double?` - Monounsaturated fat (g)
- `polyunsaturatedFat: Double?` - Polyunsaturated fat (g)

**Minerals:**
- `calcium: Double?` - Calcium (mg)
- `iron: Double?` - Iron (mg)
- `potassium: Double?` - Potassium (mg)
- `sodium: Double?` - Sodium (mg)
- `zinc: Double?` - Zinc (mg)

**Vitamins:**
- `vitaminA: Double?` - Vitamin A (μg)
- `vitaminD: Double?` - Vitamin D (μg)
- `vitaminC: Double?` - Vitamin C (mg)
- `vitaminB1: Double?` - Thiamine/B1 (mg)
- `vitaminB2: Double?` - Riboflavin/B2 (mg)
- `vitaminB3: Double?` - Niacin/B3 (mg)
- `vitaminB5: Double?` - Pantothenic Acid/B5 (mg)
- `vitaminB6: Double?` - Pyridoxine/B6 (mg)
- `vitaminB9: Double?` - Folate/B9 (μg)
- `vitaminB12: Double?` - Cobalamin/B12 (μg)

**Relationships:**
- `meal: Meal?` - The meal this food item belongs to

#### Initialization
```swift
Food(name: String, servingSize: Double = 1, servingUnit: String = "serving")
```
- Automatically generates UUID
- Defaults serving size to 1
- Defaults serving unit to "serving"
- Initializes macronutrients to 0

---

## Data Relationships

### Cascade Deletion
The models use cascade deletion rules to maintain data integrity:

- **Delete User** → Automatically deletes all associated Meals
- **Delete Meal** → Automatically deletes all associated Foods

### Example Data Structure
```swift
User(
    email: "user@example.com",
    name: "John Doe",
    meals: [
        Meal(
            name: "Breakfast",
            mealType: "breakfast",
            timestamp: Date(),
            foods: [
                Food(name: "Oatmeal", servingSize: 1, servingUnit: "cup"),
                Food(name: "Banana", servingSize: 1, servingUnit: "medium")
            ]
        )
    ]
)
```

---

## SwiftData Features

### Unique Attributes
- `User.id` and `User.email` are marked as unique
- `Meal.id` and `Food.id` are marked as unique
- Prevents duplicate entries and ensures data integrity

### Optional Properties
- Most detailed nutrients are optional (`Double?`)
- Allows flexibility for incomplete nutritional data
- Supports gradual data enrichment as more information becomes available

### Default Values
- User goals have sensible defaults (2000 kcal, 150g protein, etc.)
- Timestamps default to current date/time
- Serving sizes default to 1 "serving"

---

## Usage Notes

### Password Security
- Passwords are stored as SHA256 hashes
- Never store plain text passwords
- Consider using Apple's CryptoKit for production applications

### Units of Measurement
- **Weight:** Kilograms (kg)
- **Height:** Centimeters (cm)
- **Energy:** Kilocalories (kcal)
- **Macronutrients:** Grams (g)
- **Vitamins/Minerals:** Milligrams (mg) or Micrograms (μg)

### Meal Types
Standard meal type values:
- `"breakfast"`
- `"lunch"`
- `"dinner"`
- `"snack"`

### Activity Levels
Standard activity level values:
- `"sedentary"` - Little or no exercise
- `"light"` - Exercise 1-3 days/week
- `"moderate"` - Exercise 3-5 days/week
- `"active"` - Exercise 6-7 days/week
- `"very_active"` - Physical job or 2x daily training

---

## Future Enhancements

Potential additions to the data model:
- [ ] Custom food database/favorites
- [ ] Meal templates and recipes
- [ ] Water intake tracking
- [ ] Exercise/activity logging
- [ ] Body measurements history
- [ ] Health app integration metadata
- [ ] Nutrition targets by meal
- [ ] Food allergies/preferences
- [ ] Meal sharing/social features
- [ ] Barcode/UPC storage for foods
