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
  "places.currentOpeningHours.periods",
  "places.regularOpeningHours.openNow",
  "places.regularOpeningHours.periods",
  "places.priceLevel",
  "places.googleMapsUri",
  "places.reviews",
].join(",");

const REVIEW_KEYWORDS: Record<string, string[]> = {
  bagel: ["bagel"],
  pizza: ["pizza"],
};

function reviewIsRelevant(text: string, category: string): boolean {
  const lower = text.toLowerCase();
  if (category === "bec") return lower.includes("egg") && lower.includes("cheese");
  return (REVIEW_KEYWORDS[category] ?? []).some((k) => lower.includes(k));
}

function wordCount(text: string): number {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Returns "closes 11pm" or "opens 7am" using NYC local time and the place's period data.
function computeHoursLabel(openingHours: Record<string, unknown> | null | undefined): string | null {
  if (!openingHours) return null;
  const openNow = openingHours.openNow as boolean | undefined;
  const periods = openingHours.periods as Array<{
    open?: { day: number; hour: number; minute: number };
    close?: { day: number; hour: number; minute: number };
  }> | undefined;
  if (!periods?.length) return null;

  // Current NYC time components
  const now = new Date();
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    weekday: "long",
    hour: "numeric",
    minute: "numeric",
    hour12: false,
  }).formatToParts(now);
  const dayNames: Record<string, number> = {
    Sunday: 0, Monday: 1, Tuesday: 2, Wednesday: 3,
    Thursday: 4, Friday: 5, Saturday: 6,
  };
  const currentDay = dayNames[parts.find((p) => p.type === "weekday")?.value ?? "Sunday"] ?? 0;
  const currentHour = parseInt(parts.find((p) => p.type === "hour")?.value ?? "0") % 24;
  const currentMin = parseInt(parts.find((p) => p.type === "minute")?.value ?? "0");
  const currentMins = currentHour * 60 + currentMin;

  const fmt = (hour: number, minute: number): string => {
    const suffix = hour < 12 ? "am" : "pm";
    const h = hour % 12 || 12;
    return minute === 0 ? `${h}${suffix}` : `${h}:${minute.toString().padStart(2, "0")}${suffix}`;
  };

  if (openNow) {
    for (const period of periods) {
      if (!period.close) return null; // 24/7
      const { day: od, hour: oh, minute: om } = period.open ?? { day: 0, hour: 0, minute: 0 };
      const { day: cd, hour: ch, minute: cm } = period.close;
      const openMins = oh * 60 + om;
      const closeMins = ch * 60 + cm;
      const active =
        (od === cd && od === currentDay && currentMins >= openMins && currentMins < closeMins) ||
        (od !== cd && od === currentDay && currentMins >= openMins) ||
        (od !== cd && cd === currentDay && currentMins < closeMins);
      if (active) return `closes ${fmt(ch, cm)}`;
    }
    return null;
  } else {
    for (let offset = 0; offset <= 7; offset++) {
      const checkDay = (currentDay + offset) % 7;
      for (const period of periods) {
        if ((period.open?.day ?? 0) !== checkDay) continue;
        const openMins = (period.open?.hour ?? 0) * 60 + (period.open?.minute ?? 0);
        if (offset === 0 && openMins <= currentMins) continue;
        return `opens ${fmt(period.open!.hour, period.open!.minute)}`;
      }
    }
    return null;
  }
}

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
    const places = (data.places ?? [])
      .map((place: Record<string, unknown>) => ({
        ...place,
        hoursLabel: computeHoursLabel(
          (place.currentOpeningHours ?? place.regularOpeningHours) as Record<string, unknown> | null,
        ),
        highlightedReview: pickReview(place.reviews, category),
        reviews: pickAllReviews(place.reviews, category),
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

function pickReview(reviews: unknown, category: string): { text: string; author: string } | null {
  if (!Array.isArray(reviews)) return null;
  for (const review of reviews) {
    const text: string = review?.text?.text ?? "";
    if (reviewIsRelevant(text, category) && wordCount(text) <= 60) {
      return { text, author: review?.authorAttribution?.displayName ?? "" };
    }
  }
  return null;
}

function pickAllReviews(reviews: unknown, category: string, max = 5): Array<{ text: string; author: string }> {
  if (!Array.isArray(reviews)) return [];
  return reviews
    .filter((r) => {
      const text: string = r?.text?.text ?? "";
      return reviewIsRelevant(text, category) && wordCount(text) <= 60;
    })
    .slice(0, max)
    .map((r) => ({ text: r?.text?.text ?? "", author: r?.authorAttribution?.displayName ?? "" }));
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
