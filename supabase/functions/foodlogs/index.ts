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

    // ─── GET: list food logs ───
    if (req.method === 'GET') {
      const url = new URL(req.url)
      const days = Number(url.searchParams.get('days') ?? '30')
      const since = new Date(Date.now() - days * 86400000).toISOString()

      const { data, error } = await supabase
        .from('food_logs')
        .select('*')
        .eq('user_id', userId)
        .gte('timestamp', since)
        .order('timestamp', { ascending: false })

      if (error) {
        console.error('GET food_logs error:', JSON.stringify(error))
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders })
      }

      return new Response(JSON.stringify(data), { headers: corsHeaders })
    }

    // ─── POST: create a new food log ───
    if (req.method === 'POST') {
      const body = await req.json()

      const row = {
        user_id:              userId,
        food_name:            body.food_name,
        timestamp:            body.timestamp ?? new Date().toISOString(),
        last_modified_at:     body.last_modified_at ?? new Date().toISOString(),
        calories:             body.calories ?? 0,
        protein:              body.protein ?? 0,
        carbohydrate:         body.carbohydrate ?? 0,
        fiber:                body.fiber ?? 0,
        calcium:              body.calcium ?? 0,
        iron:                 body.iron ?? 0,
        potassium:            body.potassium ?? 0,
        sodium:               body.sodium ?? 0,
        zinc:                 body.zinc ?? 0,
        vitamin_a:            body.vitamin_a ?? 0,
        vitamin_c:            body.vitamin_c ?? 0,
        vitamin_d:            body.vitamin_d ?? 0,
        vitamin_b1:           body.vitamin_b1 ?? 0,
        vitamin_b2:           body.vitamin_b2 ?? 0,
        vitamin_b3:           body.vitamin_b3 ?? 0,
        vitamin_b5:           body.vitamin_b5 ?? 0,
        vitamin_b6:           body.vitamin_b6 ?? 0,
        vitamin_b9:           body.vitamin_b9 ?? 0,
        vitamin_b12:          body.vitamin_b12 ?? 0,
        cholesterol:          body.cholesterol ?? 0,
        trans_fat:            body.trans_fat ?? 0,
        saturated_fat:        body.saturated_fat ?? 0,
        mono_unsaturated_fat: body.mono_unsaturated_fat ?? 0,
        poly_unsaturated_fat: body.poly_unsaturated_fat ?? 0,
        sugar:                body.sugar ?? 0,
      }

      const { data, error } = await supabase
        .from('food_logs')
        .insert(row)
        .select('*')
        .single()

      if (error) {
        console.error('POST food_logs error:', JSON.stringify(error))
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders })
      }

      return new Response(JSON.stringify(data), { status: 201, headers: corsHeaders })
    }

    // ─── PUT: update an existing food log ───
    if (req.method === 'PUT') {
      const url = new URL(req.url)
      // Extract the ID from the path: /foodlogs/<remote_id>
      const segments = url.pathname.split('/')
      const logId = segments[segments.length - 1]

      if (!logId || logId === 'foodlogs') {
        return new Response(JSON.stringify({ error: 'Missing food log ID in path' }), { status: 400, headers: corsHeaders })
      }

      const body = await req.json()

      const updates: Record<string, unknown> = {
        last_modified_at: body.last_modified_at ?? new Date().toISOString(),
      }

      // Only update fields that are present in the request body
      const fields = [
        'food_name', 'timestamp', 'calories', 'protein', 'carbohydrate',
        'fiber', 'calcium', 'iron', 'potassium', 'sodium', 'zinc',
        'vitamin_a', 'vitamin_c', 'vitamin_d',
        'vitamin_b1', 'vitamin_b2', 'vitamin_b3', 'vitamin_b5', 'vitamin_b6',
        'vitamin_b9', 'vitamin_b12',
        'cholesterol', 'trans_fat', 'saturated_fat',
        'mono_unsaturated_fat', 'poly_unsaturated_fat', 'sugar',
      ]
      for (const f of fields) {
        if (body[f] !== undefined) updates[f] = body[f]
      }

      const { data, error } = await supabase
        .from('food_logs')
        .update(updates)
        .eq('remote_id', logId)
        .eq('user_id', userId)       // security: can only update own logs
        .select('*')
        .single()

      if (error) {
        console.error('PUT food_logs error:', JSON.stringify(error))
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders })
      }

      return new Response(JSON.stringify(data), { headers: corsHeaders })
    }

    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: corsHeaders })

  } catch (err) {
    console.error('Unhandled exception:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: corsHeaders })
  }
})
