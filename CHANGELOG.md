# Changelog

Tracks App Store submissions: marketing version, build number (`CURRENT_PROJECT_VERSION`), and what each one means. Add an entry here whenever you bump the version for an archive/submission.

## 1.2 (build 3) — 2026-06-10
First version with the in-app tip ("Pay me" → `bec.support`, $0.99 consumable) actually working end-to-end.
- Fixed `Products.storekit`: was an old v2.0-schema config that wasn't loading under Xcode 26.5, causing `Product.products(for:)` to return empty. Rewritten in the current v5.0 schema.
- Fixed `displayPrice` (was $1.99, should be $0.99 to match the IAP description).
- Verified working in Simulator with StoreKit Testing config.
- **Before submitting**: create the `bec.support` Consumable IAP in App Store Connect (Product ID `bec.support`, $0.99, "Buy Me a Coffee"), attach it to this version (first IAP must be reviewed alongside a build), and confirm it works against a Sandbox tester via TestFlight.

## 1.0 (build 2) — App Store resubmission
- Fixed Guideline 5.1.5: location permission dead-end (added manual location entry fallback).
- Fixed unresponsive IAP button.

## 1.0 (build 1) — initial submission
- First App Store submission.
