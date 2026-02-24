import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  try {
    const body = await req.json()
    const { id_token } = body

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const clientOpts  = { auth: { autoRefreshToken: false, persistSession: false } }

    // Auth client — used ONLY for signInWithIdToken.
    // After signIn, this client's auth state becomes the user's JWT,
    // which would fail RLS checks on database operations.
    const authClient = createClient(supabaseUrl, serviceKey, clientOpts)

    // DB client — a separate instance whose auth state is never tainted
    // by signInWithIdToken, so it always uses the service role key
    // and bypasses RLS.
    const dbClient = createClient(supabaseUrl, serviceKey, clientOpts)

    // Verify the Google token via Supabase Auth
    const { data: authData, error: authError } = await authClient.auth.signInWithIdToken({
      provider: 'google',
      token: id_token,
      nonce: body?.nonce,
    })
    if (authError) {
      console.error('signInWithIdToken failed:', JSON.stringify(authError))
      return new Response(JSON.stringify({ error: authError.message, code: authError.code }), { status: 401 })
    }

    const jwt   = authData.session.access_token
    const email = authData.user.email ?? ''
    const name  = authData.user.user_metadata?.full_name
              ?? authData.user.user_metadata?.name
              ?? ''

    // Use multiple fallbacks to get a stable Google identifier
    const googleSub = authData.user.user_metadata?.sub
                   ?? authData.user.identities?.[0]?.id
                   ?? authData.user.id   // Supabase UUID as last resort

    console.log('User email:', email, '| googleSub:', googleSub)

    // Look up by email — always reliable for Google auth
    const { data: existing } = await dbClient
      .from('users')
      .select('*')
      .eq('email', email)
      .maybeSingle()

    if (!existing) {
      const { error: insertError } = await dbClient
        .from('users')
        .insert({ google_sub: googleSub, email, name })

      if (insertError) {
        console.error('Insert error:', JSON.stringify(insertError))
        return new Response(JSON.stringify({ error: insertError.message }), { status: 500 })
      }
    }

    const { data: profile } = await dbClient
      .from('users')
      .select('*')
      .eq('email', email)
      .single()

    return new Response(
      JSON.stringify({ jwt, is_new_user: !existing, profile }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    console.error('Unhandled exception:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
