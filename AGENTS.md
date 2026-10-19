# BEC project instructions

These rules extend `~/Projects/AGENTS.md` and apply to the BEC repository.

## Thread naming

Title every thread so it reads on a phone: the slug, a one-word stage, and
for build the step. For example `map-pins find`, `map-pins spec`,
`map-pins build 3/5`, `gps-drift fix`.

- Slug first: lowercase, hyphenated, 2–3 words.
- Stage is one of: ask (a question), find (discovery), spec (planning),
  build (building the agreed plan), fix (a bug or a tweak).
- build shows the plan's step as current/total, for example `build 3/5`,
  never a bare number. The other stages show no step.
- Add ✓ when a thread finishes its stage but the work isn't finished:
  `map-pins spec ✓`. When the work is finished and verified, the title is
  `map-pins done`.
- Prefix HOLD when the owner parks it: `HOLD map-pins build 3/5`.
- No emoji (✓ and other plain symbols are fine). No project name, no
  description.
- Set the title yourself where the app allows it and check that it shows;
  otherwise put it on the first line of your first reply. Retitle whenever
  the stage or the build step changes.

## Sources of truth

- `README.md` owns product behavior, architecture, Manhattan direction math,
  search strategy, and the phone-debug workflow.
- `CHANGELOG.md` owns shipped App Store versions, builds, and release notes.
- `BEC/BEC/` is the SwiftUI client truth; `supabase/functions/` and migrations are
  backend truth. `appstore/`, `marketing/`, and `privacy-policy/` own published
  copy for those surfaces.
- Code and the changelog override stale roadmap prose. The README currently has
  a duplicated “Future iterations” section; do not infer status from headings.

## Architecture constraints

- Preserve SwiftUI, Swift 5, iOS 18.2+, the flat Xcode layout, and zero
  third-party client dependencies unless the user explicitly changes direction.
- API secrets stay behind Supabase Edge Functions and never enter the app.
- The 29-degree Manhattan grid offset exists in Swift and TypeScript; change and
  test both sides together.
- Preserve the Manhattan polygon regression tests, particularly the reported
  East River coordinate.

## Verification

- Build: `xcodebuild -project BEC/BEC.xcodeproj -scheme BEC -sdk
  iphonesimulator -destination 'generic/platform=iOS Simulator'
  -derivedDataPath /tmp/bec-derived CODE_SIGNING_ALLOWED=NO build`.
- Run `xcodebuild -project BEC/BEC.xcodeproj -scheme BEC -showdestinations`
  before choosing a simulator for tests. Then run the BEC scheme tests with that
  simulator ID and the same derived-data/signing flags.
- Simulator success does not replace physical-device location, heading,
  shake-debug, TestFlight, or App Store validation.

## Git, backend, and mobile handoffs

- Inspect the current branch; work may intentionally live on named feature or
  Claude branches. Do not assume `main` or delete branches casually.
- Confirm Supabase JWT/public-function behavior before deployment; local config
  may not describe every deployed function. Never commit `.env` files.
- Update `CHANGELOG.md` when app version/build or release behavior changes.
- For a ChatGPT/Claude iOS report, include the BEC Debug Sheet verbatim plus
  source app, date, app version/build, repo branch, and base commit. Reconcile it
  using `~/Projects/CONTEXT_BRIDGE.md`; the transcript is evidence, not truth.
