import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type',
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Validate the JWT and extract the Supabase user
    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    )
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders })
    }

    const userEmail = user.email
    if (!userEmail) {
      return new Response(JSON.stringify({ error: 'No email on user' }), { status: 400, headers: corsHeaders })
    }

    // Look up the user row to get their remote_id
    const { data: userRow, error: userError } = await supabase
      .from('users')
      .select('remote_id')
      .eq('email', userEmail)
      .single()

    if (userError || !userRow) {
      return new Response(JSON.stringify({ error: 'User not found' }), { status: 404, headers: corsHeaders })
    }

    const userId = userRow.remote_id

    // ─── GET: list meals ───
    if (req.method === 'GET') {
      const url = new URL(req.url)
      const days = Number(url.searchParams.get('days') ?? '30')
      const since = new Date(Date.now() - days * 86400000).toISOString()

      const { data, error } = await supabase
        .from('meals')
        .select('*')
        .eq('user_id', userId)
        .gte('timestamp', since)
        .order('timestamp', { ascending: false })

      if (error) {
        console.error('GET meals error:', JSON.stringify(error))
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders })
      }

      // For each meal, fetch its food items
      const mealsWithFoods = await Promise.all(
        (data ?? []).map(async (meal: Record<string, unknown>) => {
          const { data: foods } = await supabase
            .from('foods')
            .select('*')
            .eq('meal_id', meal.remote_id)

          return { ...meal, foods: foods ?? [] }
        })
      )

      return new Response(JSON.stringify(mealsWithFoods), { headers: corsHeaders })
    }

    // ─── POST: create a new meal ───
    if (req.method === 'POST') {
      const body = await req.json()

      const mealRow = {
        user_id:          userId,
        name:             body.name,
        meal_type:        body.meal_type,
        timestamp:        body.timestamp ?? new Date().toISOString(),
        last_modified_at: body.last_modified_at ?? new Date().toISOString(),
        calories:         body.calories ?? 0,
        protein:          body.protein ?? 0,
        carbs:            body.carbs ?? 0,
        fat:              body.fat ?? 0,
        fiber:            body.fiber,
        calcium:          body.calcium,
        iron:             body.iron,
        potassium:        body.potassium,
        sodium:           body.sodium,
        zinc:             body.zinc,
        vitamin_a:        body.vitamin_a,
        vitamin_d:        body.vitamin_d,
        vitamin_c:        body.vitamin_c,
        cholesterol:      body.cholesterol,
        trans_fat:        body.trans_fat,
        saturated_fat:    body.saturated_fat,
        sugar:            body.sugar,
      }

      const { data: meal, error: mealError } = await supabase
        .from('meals')
        .insert(mealRow)
        .select('*')
        .single()

      if (mealError) {
        console.error('POST meals error:', JSON.stringify(mealError))
        return new Response(JSON.stringify({ error: mealError.message }), { status: 500, headers: corsHeaders })
      }

      // Insert food items if provided
      let foods: unknown[] = []
      if (body.foods && Array.isArray(body.foods) && body.foods.length > 0) {
        const foodRows = body.foods.map((f: Record<string, unknown>) => ({
          meal_id:      meal.remote_id,
          name:         f.name,
          serving_size: f.serving_size ?? 1,
          serving_unit: f.serving_unit ?? 'serving',
          calories:     f.calories ?? 0,
          protein:      f.protein ?? 0,
          carbs:        f.carbs ?? 0,
          fat:          f.fat ?? 0,
        }))

        const { data: insertedFoods, error: foodsError } = await supabase
          .from('foods')
          .insert(foodRows)
          .select('*')

        if (foodsError) {
          console.error('POST foods error:', JSON.stringify(foodsError))
          // Meal was created but foods failed — still return the meal
        }
        foods = insertedFoods ?? []
      }

      return new Response(JSON.stringify({ ...meal, foods }), { status: 201, headers: corsHeaders })
    }

    // ─── PUT: update an existing meal ───
    if (req.method === 'PUT') {
      const url = new URL(req.url)
      const segments = url.pathname.split('/')
      const mealId = segments[segments.length - 1]

      if (!mealId || mealId === 'meals') {
        return new Response(JSON.stringify({ error: 'Missing meal ID in path' }), { status: 400, headers: corsHeaders })
      }

      const body = await req.json()

      const updates: Record<string, unknown> = {
        last_modified_at: body.last_modified_at ?? new Date().toISOString(),
      }

      const fields = [
        'name', 'meal_type', 'timestamp',
        'calories', 'protein', 'carbs', 'fat', 'fiber',
        'calcium', 'iron', 'potassium', 'sodium', 'zinc',
        'vitamin_a', 'vitamin_d', 'vitamin_c',
        'cholesterol', 'trans_fat', 'saturated_fat', 'sugar',
      ]
      for (const f of fields) {
        if (body[f] !== undefined) updates[f] = body[f]
      }

      const { data: meal, error } = await supabase
        .from('meals')
        .update(updates)
        .eq('remote_id', mealId)
        .eq('user_id', userId)       // security: can only update own meals
        .select('*')
        .single()

      if (error) {
        console.error('PUT meals error:', JSON.stringify(error))
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders })
      }

      // Re-fetch foods
      const { data: foods } = await supabase
        .from('foods')
        .select('*')
        .eq('meal_id', mealId)

      return new Response(JSON.stringify({ ...meal, foods: foods ?? [] }), { headers: corsHeaders })
    }

    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: corsHeaders })

  } catch (err) {
    console.error('Unhandled exception:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: corsHeaders })
  }
})
