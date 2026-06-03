# BEC

Three things — bacon egg and cheese, bagel, pizza. The foods you want the closest open version of, at any hour, without thinking about it. BEC finds the nearest one that's actually open right now and tells you how to get there in Manhattan terms: not "7 min walk · northeast," but "two blocks downtown, one avenue east."

## The problem

Generic map apps give you compass directions. In Manhattan, compass directions are wrong — the street grid runs 29° west of true north. "Northeast" means nothing to a New Yorker. "Two blocks uptown, one avenue east" does.

## How it works

### 1. Are you in Manhattan?

Everything about the directions logic depends on knowing whether the user is on the Manhattan grid. A bounding box isn't good enough — it would include parts of the Bronx, Queens, and New Jersey. Instead, the app uses ray casting against a hand-traced 13-vertex polygon:

```swift
// ~13 vertices tracing Manhattan clockwise from the southern tip
let poly: [(x: Double, y: Double)] = [
    (-74.0200, 40.7000), // SW Battery Park
    (-74.0060, 40.7020), // SE tip / Whitehall
    (-73.9975, 40.7065), // Seaport – Brooklyn Bridge Manhattan side
    (-73.9720, 40.7280), // FDR ~Houston St
    // ... 9 more vertices up the island
    (-74.0200, 40.7260), // SW near Holland Tunnel
]
var inside = false
var j = poly.count - 1
for i in 0..<poly.count {
    let xi = poly[i].x, yi = poly[i].y
    let xj = poly[j].x, yj = poly[j].y
    if (yi > py) != (yj > py), px < (xj - xi) * (py - yi) / (yj - yi) + xi {
        inside = !inside
    }
    j = i
}
```

A user bug report — coordinates in the East River near the Brooklyn Bridge returning `true` — drove the polygon refinement and a regression test:

```swift
@Test func reportedBugCoordinatesNotInManhattan() {
    // 40.70022, -73.99549 is in the East River near the Brooklyn Bridge,
    // not Manhattan — incorrectly returned true before the polygon fix.
    let location = CLLocation(latitude: 40.70022, longitude: -73.99549)
    #expect(LocationManager.isInManhattan(location) == false)
}
```

### 2. Grid-aligned bearing

Manhattan avenues run ~29° west of true north. To tell a user which way to walk, the app rotates the true bearing by that offset before bucketing into uptown/downtown/crosstown:

```swift
// BEC/Models.swift
let g = (b - 29 + 360).truncatingRemainder(dividingBy: 360)
switch g {
case 315..<360, 0..<45: return "uptown"
case 45..<135:          return "crosstown"
case 135..<225:         return "downtown"
default:                return "crosstown"
}
```

The same offset appears in the backend, where it's used to project each walking step onto the grid axes:

```typescript
// supabase/functions/directions-proxy/index.ts
const MANHATTAN_GRID_OFFSET = 29;
const gridRad = ((bearing - MANHATTAN_GRID_OFFSET + 360) % 360) * Math.PI / 180;
nsMeters += Math.cos(gridRad) * dist;  // positive = uptown
ewMeters += Math.sin(gridRad) * dist;  // positive = east
```

Keeping the constant in both places means the iOS direction label and the backend block description always agree on what "uptown" means.

### 3. Block size calibration

Once you have meters along each grid axis, you need to convert them to blocks. Manhattan blocks are not uniform:

- **Cross streets** (north-south): ~80 m per block
- **Avenues** (east-west): ~274 m per avenue

The edge function vector-projects all of Google's walking steps onto the grid, then divides:

```typescript
const nsBlocks  = Math.round(Math.abs(nsMeters) / 80);
const ewAvenues = Math.round(Math.abs(ewMeters) / 274);
const nsDir = nsMeters >= 0 ? "uptown" : "downtown";
const ewDir = ewMeters >= 0 ? "east" : "west";
```

The result is a human-readable string returned to the app:

```
two blocks downtown
one avenue east
```

### 4. Search strategy by category

Not all food categories map cleanly to Google place types. The Places API (New) has accurate types for `pizza_restaurant` and `bagel_shop`, so those use a nearby search ranked by distance. BEC ("bacon egg and cheese") is a menu item, not a place category — searching by type returns breakfast restaurants, not bodegas. A text search on "bacon egg and cheese" works better:

```typescript
// supabase/functions/places-proxy/index.ts
const textQueries = { bec: "bacon egg and cheese", bagel: "bagel" };
const data = textQueries[category]
  ? await searchByText(textQueries[category], latitude, longitude)
  : await searchByType(category, latitude, longitude);
```

Reviews are filtered to only surface ones that mention the actual product — a bagel shop review that never says "bagel" gets dropped, and a BEC review needs both "egg" and "cheese" to qualify.

## Architecture

```
iPhone (SwiftUI)
    │
    ├── LocationManager    CLLocation + heading, isInManhattan ray cast
    ├── PlacesService   ──► Supabase Edge Function ──► Google Places API (New)
    └── DirectionsService ► Supabase Edge Function ──► Google Directions API
                                    │
                              Deno / TypeScript
                              Rate limiting · block math · hours labels · usage logging
```

The Supabase edge functions act as an authenticated proxy: API keys stay off the device, per-IP rate limiting is enforced, and the block math runs server-side so the Swift client stays simple. Usage events log the category and a rounded coordinate (3 decimal places ≈ 111 m precision) with no user identity attached.

## QA tooling

Diagnosing location bugs from a phone is awkward. A shake-to-open debug sheet snapshots the full session state into a copyable plain-text report:

```
BEC Debug Report
Captured: Jun 3, 2026, 9:41:32 AM

--- SCREEN ---
Place:     LEO'S BAGELS
Walk time: 7 min
Direction: UPTOWN
Status:    OPEN · closes 3pm

--- LOCATION ---
Coordinates:   40.75800, -73.98550
Accuracy:      ±12 m
GPS fix:       09:41:29
isInManhattan: true

--- COMPASS ---
Heading: 344.2°

--- FEATURE FLAGS ---
blockCalculator: true

--- APP ---
Version: 1.2 (8)
iOS:     18.5
```

During development the workflow was: notice a wrong direction in the field → shake → Copy Report → paste into Claude Code mobile → fix the polygon or the grid offset. The debug sheet made it practical to close bugs from a phone without ever opening Xcode.

## Stack

- **iOS**: Swift, SwiftUI, CoreLocation
- **Backend**: Deno (TypeScript) on Supabase Edge Functions
- **APIs**: Google Places API (New), Google Directions API
