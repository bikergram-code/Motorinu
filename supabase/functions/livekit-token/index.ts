// Supabase Edge Function: LiveKit Token Generator
// Generates JWT tokens for LiveKit rooms with host/viewer permissions.
//
// Deploy: supabase functions deploy livekit-token
// Secrets: supabase secrets set LIVEKIT_API_KEY=... LIVEKIT_API_SECRET=... LIVEKIT_URL=...

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { AccessToken } from 'npm:livekit-server-sdk';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // ── Verify Supabase auth ──
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing Authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── Parse request ──
    const { roomName, isHost } = await req.json();

    if (!roomName || typeof roomName !== 'string') {
      return new Response(
        JSON.stringify({ error: 'roomName is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── Get user profile for display name ──
    const { data: profile } = await supabase
      .from('profiles')
      .select('username, display_name')
      .eq('id', user.id)
      .single();

    const displayName = profile?.display_name ?? profile?.username ?? 'User';

    // ── Generate LiveKit token ──
    const apiKey = Deno.env.get('LIVEKIT_API_KEY');
    const apiSecret = Deno.env.get('LIVEKIT_API_SECRET');

    if (!apiKey || !apiSecret) {
      return new Response(
        JSON.stringify({ error: 'LiveKit credentials not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const at = new AccessToken(apiKey, apiSecret, {
      identity: user.id,
      name: displayName,
    });

    at.addGrant({
      room: roomName,
      roomJoin: true,
      canPublish: isHost === true,      // Only host can publish video/audio
      canSubscribe: true,               // Everyone can subscribe
      canPublishData: true,             // Data channel for future use
    });

    // Token valid for 2 hours
    at.ttl = '2h';

    const token = await at.toJwt();
    const livekitUrl = Deno.env.get('LIVEKIT_URL') ?? '';

    return new Response(
      JSON.stringify({ token, url: livekitUrl }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('Token generation error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
