# Recipe Database — Supabase Reference Guide

> **For iOS developers / AI agents**: This document describes the complete Supabase database setup for the recipe feature. Use this to build queries for browsing, searching, filtering, and displaying recipes in the iOS app.

## Connection Details

| Setting | Value |
|---------|-------|
| **Supabase URL** | `https://sqgwalooucvabofnjrcx.supabase.co` |
| **Publishable (anon) Key** | See `.env` → `SUPABASE_PULISHABLE_KEY` |
| **Auth** | All recipe tables have RLS with **public read** enabled — no login required to browse recipes |
| **Swift SDK** | Use the [supabase-swift](https://github.com/supabase/supabase-swift) package |

---

## Database Schema

### Entity-Relationship Overview

```
┌──────────────┐     ┌──────────────┐     ┌───────────────────┐
│   cuisines   │     │  difficulty   │     │ nutrient          │
│              │     │  _levels     │     │ _definitions      │
│ id, name     │     │ id, name     │     │ nutrient_id,      │
└──────┬───────┘     └──────┬───────┘     │ name, unit        │
       │                    │              └────────┬──────────┘
       │  cuisine_id        │  difficulty_id        │  nutrient_id
       ▼                    ▼                       ▼
┌──────────────────────────────────┐     ┌──────────────────────┐
│            recipes               │     │  recipe_nutrients    │
│                                  │     │                      │
│  id (PK), title,                │◄────│  recipe_id,          │
│  cuisine_id (FK),               │     │  nutrient_id,        │
│  difficulty_id (FK)             │     │  amount              │
└──────────┬───────────────────────┘     └──────────────────────┘
           │
           │  recipe_id (FK)
           ▼
    ┌──────────────────┐  ┌───────────────────┐  ┌──────────────────────┐
    │ raw_ingredients  │  │ parsed_directions  │  │ detailed_ingredients │
    │                  │  │                    │  │                      │
    │ id, recipe_id,   │  │ id, recipe_id,     │  │ id, recipe_id,       │
    │ ingredient_text  │  │ step_text          │  │ name, quantity, unit, │
    └──────────────────┘  └────────────────────┘  │ total_grams, fdc_id, │
                                                   │ matched_amount, ...  │
           │                                       └──────────────────────┘
           │  recipe_id (FK)
           ▼
    ┌───────────────────┐  ┌──────────────────────┐  ┌──────────────┐
    │ recipe_allergens  │  │ recipe_dietary_tags   │  │ recipe_ner   │
    │                   │  │                       │  │              │
    │ recipe_id,        │  │ recipe_id,            │  │ recipe_id,   │
    │ allergen_id (FK)  │  │ tag_id (FK)           │  │ ner_text     │
    └────────┬──────────┘  └────────┬──────────────┘  └──────────────┘
             │                      │
             ▼                      ▼
    ┌──────────────┐       ┌──────────────┐
    │  allergens   │       │ dietary_tags │
    │ id, name     │       │ id, name     │
    └──────────────┘       └──────────────┘
```

---

## Table Details

### `recipes` — Core recipe table (7,795 rows)

| Column | Type | Description |
|--------|------|-------------|
| `id` | `BIGINT` PK | Unique recipe ID |
| `title` | `TEXT` | Recipe name, e.g. "No-Bake Nut Cookies" |
| `cuisine_id` | `BIGINT` FK → `cuisines.id` | Cuisine category |
| `difficulty_id` | `BIGINT` FK → `difficulty_levels.id` | Difficulty level |

**Indexes**: trigram GIN index on `title` for fuzzy/ILIKE search, indexes on `cuisine_id` and `difficulty_id`.

---

### `cuisines` — 20 cuisine categories

| id | name |
|----|------|
| 1 | chinese |
| 2 | japanese |
| 3 | korean |
| 4 | southern_us |
| 5 | italian |
| 6 | mexican |
| 7 | french |
| 8 | indian |
| 9 | british |
| 10 | russian |
| 11 | greek |
| 12 | cajun_creole |
| 13 | filipino |
| 14 | irish |
| 15 | jamaican |
| 16 | thai |
| 17 | spanish |
| 18 | moroccan |
| 19 | brazilian |
| 20 | vietnamese |

---

### `difficulty_levels` — 3 levels

| id | name |
|----|------|
| 1 | Hard |
| 2 | Medium |
| 3 | Easy |

---

### `raw_ingredients` — Display-ready ingredient strings (55,483 rows)

| Column | Type | Description |
|--------|------|-------------|
| `id` | `BIGINT` PK | Auto-increment |
| `recipe_id` | `BIGINT` FK → `recipes.id` | Parent recipe |
| `ingredient_text` | `TEXT` | Human-readable string, e.g. "1 c. firmly packed brown sugar" |

**Use this table for displaying ingredients in the UI.**

---

### `detailed_ingredients` — Structured ingredient data (55,483 rows)

| Column | Type | Description |
|--------|------|-------------|
| `id` | `BIGINT` PK | Auto-increment |
| `recipe_id` | `BIGINT` FK | Parent recipe |
| `name` | `TEXT` | Parsed ingredient name, e.g. "brown sugar" |
| `fdc_id` | `BIGINT` | USDA FoodData Central ID (for nutrition lookup) |
| `quantity` | `DOUBLE PRECISION` | Numeric quantity, e.g. `1.0` |
| `unit` | `TEXT` | Unit of measure, e.g. "cup" |
| `total_grams` | `DOUBLE PRECISION` | Total weight in grams |
| `matched_amount` | `DOUBLE PRECISION` | USDA portion amount used |
| `matched_gram_weight` | `DOUBLE PRECISION` | USDA gram weight per portion |
| `matched_modifier` | `TEXT` | USDA portion modifier text |

**Use this table for nutrition calculations or ingredient-level analysis.**

---

### `parsed_directions` — Cooking steps (43,826 rows)

| Column | Type | Description |
|--------|------|-------------|
| `id` | `BIGINT` PK | Auto-increment |
| `recipe_id` | `BIGINT` FK | Parent recipe |
| `step_text` | `TEXT` | One cooking step, e.g. "Stir over medium heat until mixture bubbles." |

Steps are stored as individual rows (one per step), ordered by `id`.

---

### `allergens` — 9 allergen types

| id | name |
|----|------|
| 1 | soy_allergen |
| 2 | sesame_allergen |
| 3 | peanut_allergen |
| 4 | milk_allergen |
| 5 | egg_allergen |
| 6 | wheat_allergen |
| 7 | tree_nut_allergen |
| 8 | shellfish_allergen |
| 9 | fish_allergen |

---

### `recipe_allergens` — Junction table (7,639 rows)

| Column | Type | Description |
|--------|------|-------------|
| `recipe_id` | `BIGINT` PK, FK | Recipe |
| `allergen_id` | `BIGINT` PK, FK → `allergens.id` | Allergen present in recipe |

A recipe can have multiple allergens. **To exclude recipes with user allergens, filter here.**

---

### `dietary_tags` — 10 dietary categories

| id | name |
|----|------|
| 1 | high-protein |
| 2 | gluten-free |
| 3 | low-fat |
| 4 | vegetarianism |
| 5 | veganism |
| 6 | low-carbohydrate |
| 7 | diabetic |
| 8 | paleolithic |
| 9 | very-low-calories |
| 10 | ketogenic |

---

### `recipe_dietary_tags` — Junction table (12,973 rows)

| Column | Type | Description |
|--------|------|-------------|
| `recipe_id` | `BIGINT` PK, FK | Recipe |
| `tag_id` | `BIGINT` PK, FK → `dietary_tags.id` | Dietary tag |

A recipe can have multiple tags. **Use for dietary preference filtering.**

---

### `nutrient_definitions` — 25 tracked nutrients

| nutrient_id | name | unit |
|-------------|------|------|
| 1003 | Protein | G |
| 1005 | Carbohydrate, by difference | G |
| 1008 | Calories | KCAL |
| 1079 | Fiber | G |
| 1087 | Calcium | MG |
| 1089 | Iron | MG |
| 1092 | Potassium | MG |
| 1093 | Sodium | MG |
| 1095 | Zinc | MG |
| 1106 | Vitamin A | UG |
| 1114 | Vitamin D | UG |
| 1162 | Vitamin C | MG |
| 1165 | Vitamin B1 | MG |
| 1166 | Vitamin B2 | MG |
| 1167 | Vitamin B3 | MG |
| 1170 | Vitamin B5 | MG |
| 1175 | Vitamin B6 | MG |
| 1177 | Vitamin B9 | UG |
| 1178 | Vitamin B12 | UG |
| 1253 | Cholesterol | MG |
| 1257 | Trans Fat | G |
| 1258 | Saturated Fat | G |
| 1292 | Monounsaturated Fat | G |
| 1293 | Polyunsaturated Fat | G |
| 2000 | Sugar | G |

---

### `recipe_nutrients` — Per-recipe nutrition values (194,875 rows)

| Column | Type | Description |
|--------|------|-------------|
| `recipe_id` | `BIGINT` PK, FK | Recipe |
| `nutrient_id` | `BIGINT` PK, FK → `nutrient_definitions.nutrient_id` | Nutrient type |
| `amount` | `DOUBLE PRECISION` | Total amount for the **whole recipe** |

Each recipe has up to 25 nutrient rows. Amounts are for the full recipe (not per serving).

---

### `recipe_ner` — NER ingredient list (7,795 rows)

| Column | Type | Description |
|--------|------|-------------|
| `recipe_id` | `BIGINT` PK, FK | Recipe |
| `ner_text` | `TEXT` | JSON array of extracted ingredient names |

Example: `["brown sugar", "milk", "vanilla", "nuts", "butter", "bite size shredded rice biscuits"]`

**This is primarily used by the RAG pipeline for vector embedding, not for UI display.**

---

## Example Supabase Queries (Swift SDK)

### Fetch a single recipe with cuisine & difficulty

```swift
let recipe = try await supabase
    .from("recipes")
    .select("id, title, cuisine:cuisines(name), difficulty:difficulty_levels(name)")
    .eq("id", value: 0)
    .single()
    .execute()
```

### Fetch ingredients & directions for a recipe

```swift
let ingredients = try await supabase
    .from("raw_ingredients")
    .select("ingredient_text")
    .eq("recipe_id", value: recipeId)
    .execute()

let directions = try await supabase
    .from("parsed_directions")
    .select("step_text")
    .eq("recipe_id", value: recipeId)
    .order("id")
    .execute()
```

### Search recipes by title (fuzzy)

```swift
let results = try await supabase
    .from("recipes")
    .select("id, title, cuisine:cuisines(name), difficulty:difficulty_levels(name)")
    .ilike("title", pattern: "%stew%")
    .limit(20)
    .execute()
```

### Filter by cuisine

```swift
let results = try await supabase
    .from("recipes")
    .select("id, title, cuisine:cuisines(name)")
    .eq("cuisine_id", value: 1)  // 1 = chinese
    .execute()
```

### Filter by dietary tag (e.g. "vegan")

```swift
// Get recipe IDs with the "veganism" tag
let taggedRecipes = try await supabase
    .from("recipe_dietary_tags")
    .select("recipe_id, tag:dietary_tags!inner(name)")
    .eq("dietary_tags.name", value: "veganism")
    .execute()
```

### Exclude recipes with specific allergens

```swift
// Get recipe IDs that contain peanut allergen
let allergenRecipes = try await supabase
    .from("recipe_allergens")
    .select("recipe_id, allergen:allergens!inner(name)")
    .eq("allergens.name", value: "peanut_allergen")
    .execute()

// Then exclude these IDs from your main query
```

### Fetch nutrition for a recipe

```swift
let nutrients = try await supabase
    .from("recipe_nutrients")
    .select("amount, nutrient:nutrient_definitions(name, unit)")
    .eq("recipe_id", value: recipeId)
    .execute()
```

### Fetch a complete recipe (all details in one go)

```swift
// Option: Use multiple queries or create a Supabase database function (RPC)
// for a single "get full recipe" call that returns everything.

let recipe = try await supabase
    .from("recipes")
    .select("""
        id, title,
        cuisine:cuisines(name),
        difficulty:difficulty_levels(name),
        raw_ingredients(ingredient_text),
        parsed_directions(step_text),
        recipe_allergens(allergen:allergens(name)),
        recipe_dietary_tags(tag:dietary_tags(name)),
        recipe_nutrients(amount, nutrient:nutrient_definitions(name, unit))
    """)
    .eq("id", value: recipeId)
    .single()
    .execute()
```

---

## Example: Full Recipe Data Shape

For recipe ID `0` ("No-Bake Nut Cookies"), the full data looks like:

```json
{
  "id": 0,
  "title": "No-Bake Nut Cookies",
  "cuisine": { "name": "southern_us" },
  "difficulty": { "name": "Medium" },
  "raw_ingredients": [
    { "ingredient_text": "1 c. firmly packed brown sugar" },
    { "ingredient_text": "1/2 c. evaporated milk" },
    { "ingredient_text": "1/2 tsp. vanilla" },
    { "ingredient_text": "1/2 c. broken nuts (pecans)" },
    { "ingredient_text": "2 Tbsp. butter or margarine" },
    { "ingredient_text": "3 1/2 c. bite size shredded rice biscuits" }
  ],
  "parsed_directions": [
    { "step_text": "In a heavy 2-quart saucepan, mix brown sugar, nuts, evaporated milk and butter or margarine." },
    { "step_text": "Stir over medium heat until mixture bubbles all over top." },
    { "step_text": "Boil and stir 5 minutes more." },
    { "step_text": "Take off heat." },
    { "step_text": "Stir in vanilla and cereal; mix well." },
    { "step_text": "Using 2 teaspoons, drop and shape into 30 clusters on wax paper." },
    { "step_text": "Let stand until firm, about 30 minutes." }
  ],
  "recipe_allergens": [
    { "allergen": { "name": "milk_allergen" } }
  ],
  "recipe_dietary_tags": [
    { "tag": { "name": "gluten-free" } },
    { "tag": { "name": "vegetarianism" } }
  ],
  "recipe_nutrients": [
    { "amount": 19.88, "nutrient": { "name": "Protein", "unit": "G" } },
    { "amount": 61.66, "nutrient": { "name": "Carbohydrate, by difference", "unit": "G" } },
    { "amount": 974.63, "nutrient": { "name": "Calories", "unit": "KCAL" } },
    { "amount": 6.75, "nutrient": { "name": "Fiber", "unit": "G" } }
  ]
}
```

---

## Data Statistics

| Metric | Value |
|--------|-------|
| Total recipes | 7,795 |
| Cuisines | 20 |
| Difficulty levels | 3 (Easy, Medium, Hard) |
| Allergen types | 9 |
| Dietary tag types | 10 |
| Tracked nutrients | 25 |
| Avg ingredients per recipe | ~7 |
| Avg directions per recipe | ~6 steps |
| Nutrient values | Per whole recipe (not per serving) |
