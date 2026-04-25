import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GOOGLE_PLACES_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY") ?? "";
const PLACES_BASE = "https://places.googleapis.com/v1";
const RADIUS_METERS = 1200; // ~15 min walk at 80 m/min

const FIELD_MASK = [
  "places.id",
  "places.displayName",
  "places.formattedAddress",
  "places.location",
  "places.rating",
  "places.currentOpeningHours.openNow",
  "places.regularOpeningHours.openNow",
  "places.priceLevel",
  "places.googleMapsUri",
  "places.reviews",
].join(",");

const REVIEW_KEYWORDS: Record<string, string[]> = {
  bec: ["bacon egg and cheese", "egg sandwich"],
  bagel: ["bagel"],
  pizza: ["pizza"],
};

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { category, latitude, longitude } = await req.json();

    if (!category || latitude == null || longitude == null) {
      return jsonError("Missing required fields: category, latitude, longitude", 400);
    }

    if (!["pizza", "bagel", "bec"].includes(category)) {
      return jsonError(`Unknown category '${category}'. Valid: pizza, bagel, bec`, 400);
    }

    const textQueries: Record<string, string> = {
      bec: "bacon egg and cheese",
      bagel: "bagel",
    };

    const data = textQueries[category]
      ? await searchByText(textQueries[category], latitude, longitude)
      : await searchByType(category, latitude, longitude);

    const keywords = REVIEW_KEYWORDS[category] ?? [];
    const places = (data.places ?? []).map((place: Record<string, unknown>) => ({
      ...place,
      highlightedReview: pickReview(place.reviews, keywords),
      reviews: undefined, // strip raw reviews from response
    }));

    logUsageEvent({ category, latitude, longitude, resultCount: places.length });

    return new Response(JSON.stringify({ places }), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("places-proxy error", e);
    return jsonError("Internal server error", 500);
  }
});

// Pizza + bagel: type-based nearby search (accurate Google place types exist)
async function searchByType(category: string, latitude: number, longitude: number) {
  const types = category === "pizza"
    ? ["pizza_restaurant"]
    : ["bagel_shop"];

  const res = await fetch(`${PLACES_BASE}/places:searchNearby`, {
    method: "POST",
    headers: googleHeaders(),
    body: JSON.stringify({
      includedTypes: types,
      locationRestriction: {
        circle: { center: { latitude, longitude }, radius: RADIUS_METERS },
      },
      rankPreference: "DISTANCE",
      maxResultCount: 10,
      languageCode: "en",
    }),
  });

  return handlePlacesResponse(res);
}

// BEC: text search — "bacon egg and cheese" by name is more accurate than place types
async function searchByText(query: string, latitude: number, longitude: number) {
  const res = await fetch(`${PLACES_BASE}/places:searchText`, {
    method: "POST",
    headers: googleHeaders(),
    body: JSON.stringify({
      textQuery: query,
      locationBias: {
        circle: { center: { latitude, longitude }, radius: RADIUS_METERS },
      },
      rankPreference: "DISTANCE",
      maxResultCount: 10,
      languageCode: "en",
    }),
  });

  return handlePlacesResponse(res);
}

function pickReview(reviews: unknown, keywords: string[]): { text: string; author: string } | null {
  if (!Array.isArray(reviews)) return null;
  for (const keyword of keywords) {
    for (const review of reviews) {
      const text: string = review?.text?.text ?? "";
      if (text.toLowerCase().includes(keyword.toLowerCase())) {
        return { text: truncate(text, 120), author: review?.authorAttribution?.displayName ?? "" };
      }
    }
  }
  return null;
}

function truncate(text: string, maxLength: number): string {
  return text.length <= maxLength ? text : text.slice(0, maxLength).trimEnd() + "…";
}

function googleHeaders() {
  return {
    "Content-Type": "application/json",
    "X-Goog-Api-Key": GOOGLE_PLACES_API_KEY,
    "X-Goog-FieldMask": FIELD_MASK,
  };
}

async function handlePlacesResponse(res: Response) {
  if (!res.ok) {
    const err = await res.text();
    console.error("Places API error", res.status, err);
    throw new Error("Upstream Places API error");
  }
  return res.json();
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

async function logUsageEvent(event: {
  category: string;
  latitude: number;
  longitude: number;
  resultCount: number;
}) {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    await fetch(`${supabaseUrl}/rest/v1/usage_events`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: supabaseKey,
        Authorization: `Bearer ${supabaseKey}`,
        Prefer: "return=minimal",
      },
      body: JSON.stringify({
        category: event.category,
        result_count: event.resultCount,
        lat_approx: Math.round(event.latitude * 1000) / 1000,
        lng_approx: Math.round(event.longitude * 1000) / 1000,
      }),
    });
  } catch {
    // Non-critical — swallow
  }
}
