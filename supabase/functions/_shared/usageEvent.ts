const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const VALID_EVENT_TYPES = new Set([
  "places_search",
  "result_loaded",
  "drawer_open",
  "alternate_selected",
  "navigate_tapped",
  "share_tapped",
]);

const VALID_CATEGORIES = new Set(["pizza", "bagel", "bec"]);

export function usageCorsHeaders() {
  return CORS_HEADERS;
}

export async function insertUsageEvent(event: {
  event_type: string;
  category: string;
  latitude: number;
  longitude: number;
  result_count?: number;
  in_manhattan?: boolean;
}): Promise<void> {
  if (!VALID_EVENT_TYPES.has(event.event_type)) return;
  if (!VALID_CATEGORIES.has(event.category)) return;

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

  await fetch(`${supabaseUrl}/rest/v1/usage_events`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
      Prefer: "return=minimal",
    },
    body: JSON.stringify({
      event_type: event.event_type,
      category: event.category,
      result_count: event.result_count ?? 0,
      lat_approx: Math.round(event.latitude * 1000) / 1000,
      lng_approx: Math.round(event.longitude * 1000) / 1000,
      in_manhattan: event.in_manhattan ?? null,
    }),
  });
}
