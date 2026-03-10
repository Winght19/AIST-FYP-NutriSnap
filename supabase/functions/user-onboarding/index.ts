import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Validate the JWT and extract the Supabase user
    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    )
    if (authError || !user) {
      console.error('Auth error:', authError)
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    // Use email as the stable lookup key — always present for Google auth
    const userEmail = user.email
    if (!userEmail) {
      return new Response(JSON.stringify({ error: 'No email on user' }), { status: 400 })
    }

    const body = await req.json()
    console.log('Request body:', JSON.stringify(body))

    // --- Mifflin-St Jeor TDEE Calculation ---
    const weightKg  = Number(body.weight_kg)
    const heightCm  = Number(body.height_cm)
    const gender    = body.gender     as string
    const weeklyHrs = Number(body.exercise_hours_per_week)
    const goal      = body.primary_goal as string

    const dob = new Date(body.date_of_birth)
    if (isNaN(dob.getTime())) {
      return new Response(JSON.stringify({ error: 'Invalid date_of_birth' }), { status: 400 })
    }
    const age = Math.floor((Date.now() - dob.getTime()) / (365.25 * 24 * 60 * 60 * 1000))
    console.log('Computed age:', age)

    const bmr = gender === 'Male'
      ? 10 * weightKg + 6.25 * heightCm - 5 * age + 5
      : 10 * weightKg + 6.25 * heightCm - 5 * age - 161

    const activityMultiplier =
      weeklyHrs <= 1  ? 1.2   :
      weeklyHrs <= 3  ? 1.375 :
      weeklyHrs <= 5  ? 1.55  :
      weeklyHrs <= 10 ? 1.725 : 1.9

    let tdee = bmr * activityMultiplier
    if (goal === 'Lose Weight')                           tdee -= 500
    if (goal === 'Gain Weight' || goal === 'Gain Muscle') tdee += 300

    const dailyCalorieGoal = Math.round(tdee)
    const proteinGoal      = Math.round(weightKg * 2.0)
    const fatGoal          = Math.round(tdee * 0.25 / 9)
    const carbsGoal        = Math.round((tdee - proteinGoal * 4 - fatGoal * 9) / 4)

    console.log('Targets:', { dailyCalorieGoal, proteinGoal, fatGoal, carbsGoal })

    // --- Save to database ---
    // Uses upsert so it works even if auth-google failed to insert the row.
    const { data: profile, error: updateError } = await supabase
      .from('users')
      .upsert({
        email: userEmail,                               // match key
        google_sub:               userEmail,            // safe fallback
        name:                     user.user_metadata?.full_name ?? user.user_metadata?.name ?? '',
        date_of_birth:            body.date_of_birth,
        weight_kg:                weightKg,
        height_cm:                heightCm,
        gender,
        primary_goal:             goal,
        exercise_hours_per_week:  weeklyHrs,
        allergens:                body.allergens ?? [],
        preferred_cuisines:       body.preferred_cuisines ?? [],
        preferred_meal_types:     body.preferred_meal_types ?? [],
        preferred_diets:          body.preferred_diets ?? [],
        daily_calorie_goal:       dailyCalorieGoal,
        protein_goal:             proteinGoal,
        carbs_goal:               carbsGoal,
        fat_goal:                 fatGoal,
        is_profile_complete:      true,
        last_modified_at:         new Date().toISOString(),
      }, { onConflict: 'email' })
      .select('*')
      .single()

    if (updateError) {
      console.error('DB upsert error:', JSON.stringify(updateError))
      return new Response(JSON.stringify({ error: updateError.message }), { status: 500 })
    }

    return new Response(JSON.stringify(profile), {
      headers: { 'Content-Type': 'application/json' },
    })

  } catch (err) {
    console.error('Unhandled exception:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
