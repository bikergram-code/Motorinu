// Supabase Edge Function: Moto KI-Biker-Assistent
// Proxies natural language queries to Ollama (Mistral 7B) on our server.
//
// Deploy: supabase functions deploy ai-assistant
// Secrets: supabase secrets set OLLAMA_URL=... OLLAMA_KEY=... OLLAMA_MODEL=...

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const SYSTEM_PROMPT = `Du bist Moto, der KI-Assistent der Bikergram Motorrad-App.
Regeln:
- Antworte IMMER auf Deutsch
- Maximal 2 kurze Sätze (der Fahrer hört per Lautsprecher während der Fahrt)
- KEIN Markdown, KEINE Emojis, KEINE Aufzählungen
- Sprich wie über Motorrad-Funk: knapp, klar, freundlich
- Du erhältst den Kontext des Fahrers (Position, Geschwindigkeit, Route)

Du MUSST als JSON antworten mit genau diesem Format:
{"response":"Deine gesprochene Antwort hier","action":{"type":"none","params":{}}}

Mögliche action.type Werte:
- "searchPoi" mit params {"query":"Suchbegriff","poiLabel":"Anzeigename"} — wenn der Fahrer einen Ort sucht
- "navigate" mit params {"address":"Zieladresse"} — wenn der Fahrer irgendwo hin will
- "reportBlitzer" mit params {} — wenn der Fahrer einen Blitzer melden will
- "none" mit params {} — für alle anderen Antworten (Wetter, Tipps, Fragen etc.)`;

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
    const { query, context } = await req.json();

    if (!query || typeof query !== 'string') {
      return new Response(
        JSON.stringify({ error: 'query is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── Build prompt with riding context ──
    const contextStr = context
      ? `\nFahrer-Kontext: Position ${context.lat?.toFixed(4)},${context.lon?.toFixed(4)}, ` +
        `Geschwindigkeit ${context.speed ?? 0} km/h, ` +
        `${context.isNavigating ? `navigiert nach ${context.routeDestination ?? 'unbekannt'}` : 'keine Navigation aktiv'}`
      : '';

    const userPrompt = `${contextStr}\n\nFahrer sagt: "${query}"`;

    // ── Call Ollama ──
    const ollamaUrl = Deno.env.get('OLLAMA_URL') ?? 'http://152.53.255.4/ollama';
    const ollamaKey = Deno.env.get('OLLAMA_KEY') ?? '';
    const ollamaModel = Deno.env.get('OLLAMA_MODEL') ?? 'mistral:7b-instruct-v0.3-q4_K_M';

    console.log(`[MotoAI] Query from ${user.id}: "${query}"`);

    const ollamaResponse = await fetch(`${ollamaUrl}/api/generate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(ollamaKey ? { 'X-Ollama-Key': ollamaKey } : {}),
      },
      body: JSON.stringify({
        model: ollamaModel,
        prompt: userPrompt,
        system: SYSTEM_PROMPT,
        stream: false,
        options: {
          temperature: 0.3,
          num_predict: 150,
        },
      }),
    });

    if (!ollamaResponse.ok) {
      console.error(`[MotoAI] Ollama error: ${ollamaResponse.status}`);
      return new Response(
        JSON.stringify({
          response: 'Entschuldigung, ich bin gerade nicht erreichbar.',
          action: { type: 'none', params: {} },
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const ollamaData = await ollamaResponse.json();
    const rawText = ollamaData.response ?? '';

    console.log(`[MotoAI] Ollama raw: ${rawText.substring(0, 200)}`);

    // ── Parse JSON from Ollama response ──
    let result;
    try {
      // Try to extract JSON from the response (model might add extra text)
      const jsonMatch = rawText.match(/\{[\s\S]*"response"[\s\S]*\}/);
      if (jsonMatch) {
        result = JSON.parse(jsonMatch[0]);
      } else {
        // Fallback: use raw text as response
        result = { response: rawText.trim(), action: { type: 'none', params: {} } };
      }
    } catch {
      // JSON parse failed — use raw text
      result = { response: rawText.trim(), action: { type: 'none', params: {} } };
    }

    // Ensure response structure
    if (!result.response) result.response = 'Keine Antwort erhalten.';
    if (!result.action) result.action = { type: 'none', params: {} };

    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('[MotoAI] Error:', err);
    return new Response(
      JSON.stringify({
        response: 'Entschuldigung, es gab einen Fehler. Versuche es nochmal.',
        action: { type: 'none', params: {} },
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
