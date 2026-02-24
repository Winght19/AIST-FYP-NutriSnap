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

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    )
    if (authError || !user) {
      console.error('Auth error:', authError)
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    const userEmail = user.email
    if (!userEmail) {
      return new Response(JSON.stringify({ error: 'No email on user' }), { status: 400 })
    }

    const { data: profile, error: dbError } = await supabase
      .from('users')
      .select('*')
      .eq('email', userEmail)
      .single()

    if (dbError) {
      console.error('DB error:', JSON.stringify(dbError))
      return new Response(JSON.stringify({ error: dbError.message }), { status: 404 })
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
