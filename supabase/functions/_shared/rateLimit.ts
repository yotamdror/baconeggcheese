const store = new Map<string, { count: number; windowStart: number }>();
const WINDOW_MS = 60_000;
let lastCleanup = Date.now();

export function checkRateLimit(req: Request, limit: number): boolean {
  const now = Date.now();

  // Prevent unbounded Map growth from many unique IPs
  if (now - lastCleanup > 300_000) {
    for (const [ip, entry] of store) {
      if (now - entry.windowStart > WINDOW_MS) store.delete(ip);
    }
    lastCleanup = now;
  }

  const ip =
    req.headers.get("x-forwarded-for")?.split(",")[0].trim() ??
    req.headers.get("x-real-ip") ??
    "unknown";

  const entry = store.get(ip);
  if (!entry || now - entry.windowStart > WINDOW_MS) {
    store.set(ip, { count: 1, windowStart: now });
    return true;
  }
  if (entry.count >= limit) return false;
  entry.count++;
  return true;
}
