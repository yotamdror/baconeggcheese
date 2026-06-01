import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { checkRateLimit } from "../_shared/rateLimit.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (!checkRateLimit(req, 5)) {
    return jsonError("Too many requests", 429);
  }

  try {
    const { message, app_version } = await req.json();

    if (!message || typeof message !== "string" || message.trim().length === 0) {
      return jsonError("message is required", 400);
    }

    if (message.length > 2000) {
      return jsonError("message too long (max 2000 chars)", 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const res = await fetch(`${supabaseUrl}/rest/v1/feedback`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: supabaseKey,
        Authorization: `Bearer ${supabaseKey}`,
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        message: message.trim(),
        app_version: app_version ?? null,
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error("feedback insert error", res.status, err);
      return jsonError("Failed to save feedback", 500);
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("submit-feedback error", e);
    return jsonError("Internal server error", 500);
  }
});

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}
