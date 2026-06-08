import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { checkRateLimit } from "../_shared/rateLimit.ts";

const GOOGLE_PLACES_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY") ?? "";
const PLACES_BASE = "https://places.googleapis.com/v1";

// Bias results toward Manhattan — this is a NYC-only app.
const MANHATTAN_CENTER = { latitude: 40.78, longitude: -73.97 };
const BIAS_RADIUS_METERS = 12_000;
const MAX_QUERY_LENGTH = 200;

const FIELD_MASK = [
  "places.id",
  "places.displayName",
  "places.formattedAddress",
  "places.location",
].join(",");

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (!checkRateLimit(req, 20)) {
    return jsonError("Too many requests", 429);
  }

  try {
    const { query } = await req.json();

    if (typeof query !== "string") {
      return jsonError("Missing required field: query", 400);
    }

    const trimmed = query.trim().slice(0, MAX_QUERY_LENGTH);
    if (!trimmed) {
      return jsonResults([]);
    }

    const res = await fetch(`${PLACES_BASE}/places:searchText`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY,
        "X-Goog-FieldMask": FIELD_MASK,
      },
      body: JSON.stringify({
        textQuery: trimmed,
        locationBias: {
          circle: { center: MANHATTAN_CENTER, radius: BIAS_RADIUS_METERS },
        },
        maxResultCount: 5,
        languageCode: "en",
        regionCode: "US",
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      console.error("Places API error", res.status, err);
      throw new Error("Upstream Places API error");
    }

    const data = await res.json();
    const results = (data.places ?? [])
      .map((place: Record<string, unknown>) => {
        const location = place.location as { latitude?: number; longitude?: number } | undefined;
        const displayName = place.displayName as { text?: string } | undefined;
        if (location?.latitude == null || location?.longitude == null) return null;
        return {
          name: displayName?.text ?? "",
          address: (place.formattedAddress as string | undefined) ?? "",
          latitude: location.latitude,
          longitude: location.longitude,
        };
      })
      .filter((r: unknown) => r !== null);

    return jsonResults(results);
  } catch (e) {
    console.error("geocode-proxy error", e);
    return jsonError("Internal server error", 500);
  }
});

function jsonResults(results: unknown[]) {
  return new Response(JSON.stringify({ results }), {
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}
