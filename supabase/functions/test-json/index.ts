Deno.serve(async (req: Request) => {
  const raw = await req.text();
  return new Response(JSON.stringify({ ok: true, len: raw.length }), { headers: { 'Content-Type': 'application/json' } });
});
