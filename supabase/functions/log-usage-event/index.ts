import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { checkRateLimit } from "../_shared/rateLimit.ts";
import { insertUsageEvent, usageCorsHeaders } from "../_shared/usageEvent.ts";

serve(async (req) => {
  const headers = usageCorsHeaders();

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers });
  }

  // Generous limit: several funnel steps per session, still bounded per IP
  if (!checkRateLimit(req, 40)) {
    return jsonError("Too many requests", 429, headers);
  }

  try {
    const body = await req.json();
    const { event_type, category, latitude, longitude, result_count, in_manhattan } = body;

    if (!event_type || !category || latitude == null || longitude == null) {
      return jsonError("Missing required fields: event_type, category, latitude, longitude", 400, headers);
    }

    const lat = Number(latitude);
    const lng = Number(longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return jsonError("Invalid coordinates", 400, headers);
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return jsonError("Coordinates out of range", 400, headers);
    }

    const count = result_count == null ? 0 : Number(result_count);
    if (!Number.isFinite(count) || count < 0 || count > 50) {
      return jsonError("Invalid result_count", 400, headers);
    }

    await insertUsageEvent({
      event_type,
      category,
      latitude: lat,
      longitude: lng,
      result_count: count,
      in_manhattan: in_manhattan === true ? true : in_manhattan === false ? false : undefined,
    });

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...headers, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("log-usage-event error", e);
    return jsonError("Internal server error", 500, headers);
  }
});

function jsonError(message: string, status: number, headers: Record<string, string>) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}
