import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GOOGLE_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY") ?? "";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Dark MTA-inspired map style
const MAP_STYLES = [
  "feature:all|element:geometry|color:0x0d0f14",
  "feature:all|element:labels|visibility:off",
  "feature:road|element:geometry|color:0x1c2130",
  "feature:road.arterial|element:geometry|color:0x242b3d",
  "feature:road.highway|element:geometry|color:0x2c3550",
  "feature:water|element:geometry|color:0x080b10",
  "feature:transit.line|element:geometry|color:0x1a1f2e",
  "feature:landscape|element:geometry|color:0x0d0f14",
  "feature:poi|visibility:off",
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { originLat, originLng, destLat, destLng, colorHex } = await req.json();

    if (originLat == null || originLng == null || destLat == null || destLng == null || !colorHex) {
      return jsonError("Missing required fields: originLat, originLng, destLat, destLng, colorHex", 400);
    }

    // Fetch walking route polyline from Directions API
    let polyline = "";
    try {
      const dirUrl =
        `https://maps.googleapis.com/maps/api/directions/json` +
        `?origin=${originLat},${originLng}` +
        `&destination=${destLat},${destLng}` +
        `&mode=walking` +
        `&key=${GOOGLE_API_KEY}`;

      const dirRes = await fetch(dirUrl);
      const dirData = await dirRes.json();
      polyline = dirData?.routes?.[0]?.overview_polyline?.points ?? "";
    } catch {
      // No route — fall back to marker-only map
    }

    const color = colorHex.replace("#", "");
    const styleParams = MAP_STYLES.map((s) => `&style=${encodeURIComponent(s)}`).join("");

    // size=342x130 + scale=2 → 684x260px retina tile
    let staticUrl =
      `https://maps.googleapis.com/maps/api/staticmap` +
      `?size=342x130&scale=2` +
      `&markers=color:0x${color}|${destLat},${destLng}` +
      `&markers=color:0xffffff|size:tiny|${originLat},${originLng}`;

    if (polyline) {
      staticUrl += `&path=color:0x${color}FF|weight:3|enc:${encodeURIComponent(polyline)}`;
    }

    staticUrl += styleParams + `&key=${GOOGLE_API_KEY}`;

    const imgRes = await fetch(staticUrl);
    if (!imgRes.ok) {
      const err = await imgRes.text();
      console.error("Static Maps API error", imgRes.status, err);
      throw new Error("Upstream Static Maps error");
    }

    const imgData = await imgRes.arrayBuffer();
    return new Response(imgData, {
      headers: {
        ...CORS_HEADERS,
        "Content-Type": imgRes.headers.get("Content-Type") ?? "image/png",
        "Cache-Control": "public, max-age=300",
      },
    });
  } catch (e) {
    console.error("maps-proxy error", e);
    return jsonError("Internal server error", 500);
  }
});

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}
