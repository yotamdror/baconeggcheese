import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GOOGLE_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY") ?? "";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Manhattan avenues run ~29° west of true north
const MANHATTAN_GRID_OFFSET = 29;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { originLat, originLng, destLat, destLng } = await req.json();

    if (originLat == null || originLng == null || destLat == null || destLng == null) {
      return jsonError("Missing required fields: originLat, originLng, destLat, destLng", 400);
    }

    const dirUrl =
      `https://maps.googleapis.com/maps/api/directions/json` +
      `?origin=${originLat},${originLng}` +
      `&destination=${destLat},${destLng}` +
      `&mode=walking` +
      `&key=${GOOGLE_API_KEY}`;

    const dirRes = await fetch(dirUrl);
    const dirData = await dirRes.json();

    const leg = dirData?.routes?.[0]?.legs?.[0];
    if (!leg) {
      return jsonError("No route found", 404);
    }

    const durationMinutes = Math.max(1, Math.round(leg.duration.value / 60));
    const blockDescription = buildBlockDescription(leg.steps ?? []);

    return new Response(JSON.stringify({ durationMinutes, blockDescription }), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("directions-proxy error", e);
    return jsonError("Internal server error", 500);
  }
});

function computeBearing(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const lat1R = lat1 * Math.PI / 180;
  const lat2R = lat2 * Math.PI / 180;
  const y = Math.sin(dLng) * Math.cos(lat2R);
  const x = Math.cos(lat1R) * Math.sin(lat2R) - Math.sin(lat1R) * Math.cos(lat2R) * Math.cos(dLng);
  return (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
}

// Decomposes walking steps into uptown/downtown blocks and crosstown avenues
// using vector projection onto the Manhattan street grid.
function buildBlockDescription(steps: Array<{
  start_location: { lat: number; lng: number };
  end_location: { lat: number; lng: number };
  distance: { value: number };
}>): string {
  let nsMeters = 0; // positive = uptown
  let ewMeters = 0; // positive = east

  for (const step of steps) {
    const bearing = computeBearing(
      step.start_location.lat, step.start_location.lng,
      step.end_location.lat, step.end_location.lng,
    );
    // Rotate so 0° aligns with "uptown" along Manhattan avenues
    const gridRad = ((bearing - MANHATTAN_GRID_OFFSET + 360) % 360) * Math.PI / 180;
    const dist = step.distance.value;
    nsMeters += Math.cos(gridRad) * dist;
    ewMeters += Math.sin(gridRad) * dist;
  }

  const nsBlocks = Math.round(Math.abs(nsMeters) / 80);
  const ewAvenues = Math.round(Math.abs(ewMeters) / 274);
  const nsDir = nsMeters >= 0 ? "uptown" : "downtown";
  const ewDir = ewMeters >= 0 ? "east" : "west";

  const words = [
    "zero", "one", "two", "three", "four", "five", "six", "seven",
    "eight", "nine", "ten", "eleven", "twelve", "thirteen",
    "fourteen", "fifteen", "sixteen", "seventeen", "eighteen",
    "nineteen", "twenty",
  ];
  const word = (n: number) => n < words.length ? words[n] : `${n}`;

  const nsStr = nsBlocks > 0
    ? `${word(nsBlocks)} ${nsBlocks === 1 ? "block" : "blocks"} ${nsDir}`
    : null;
  const ewStr = ewAvenues > 0
    ? `${word(ewAvenues)} ${ewAvenues === 1 ? "ave" : "aves"} ${ewDir}`
    : null;

  if (nsStr && ewStr) return `${nsStr} and ${ewStr}`;
  if (nsStr) return nsStr;
  if (ewStr) return ewStr;
  return "right here";
}

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}
