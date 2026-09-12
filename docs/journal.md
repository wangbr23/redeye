# Journal

Append-only. One entry per work session. Newest at the bottom. Don't edit past entries — if something's wrong now, say so in a new entry.

## 2026-09-11 — project created

Initialized project scaffold (AGENTS.md, CLEANCODE.md, decisions log, TODO). Nothing built yet.

Decided on stack: SwiftUI (iOS), Next.js API routes on Vercel (backend), Supabase (Postgres + Auth), Claude via AI SDK (itinerary generation). Architecture doc published as an artifact covering data model (trips, trip_days, activities), two-mode design (structured vs unstructured), offline strategy (SwiftData as local source of truth with background sync), and AI generation flow.

Wrote product spec (`docs/designs/product-spec.md`) — 33 functional requirements across 8 groups (trip management, structured mode, unstructured mode, AI generation, search, maps, on-trip experience, route planning stretch goal) and 17 non-functional requirements across 6 groups (performance, offline, data integrity, privacy, distribution, usability).

Wrote technical design doc (`docs/designs/2026-09-11-technical-design.md`) mapping every product requirement to implementation. Key decisions recorded: offline-first with SwiftData + background sync (last-write-wins), MVVM architecture with @Observable ViewModels + injected Services. Defined full Supabase schema, API surface (4 route groups), iOS screen map (11 screens), sync strategy, and 5-phase build order. Codex review skipped per user request.

Wrote low-level design (`docs/designs/2026-09-11-technical-design-lld.md`). Pinned mechanisms: SSE streaming for AI generation (URLSession AsyncBytes, not WebSocket — one-way stream), per-record sync status (not a change log — simpler, sufficient for last-write-wins), debounced push (2s), full-fetch pull (acceptable at MVP scale), isProposed flag for AI review gating, sort_order full-group recalculation on reorder, on-demand location permission. Defined 13 flow sequences mapping every FR to concrete steps through named files. Four open questions logged: Apple relay email, AI coordinate accuracy, SwiftData background threading, preferences schema shape.

## 2026-09-12 — T4: SwiftData models

Created SwiftData models in `Redeye/Redeye/Models/`:
- `Trip.swift` — @Model with TripMode/TripStatus enums, relationships to days and activities (cascade delete), computed sortedDays and numberOfDays
- `TripDay.swift` — @Model with inverse relationship to Trip, nullify-on-delete relationship to activities, computed sortedActivities
- `Activity.swift` — @Model with ActivitySource/ActivityStatus enums, optional tripDay relationship (nil for unstructured or unassigned), isProposed transient flag
- `SyncStatus.swift` — enum (synced, pendingCreate, pendingUpdate, pendingDelete)
- `ActivityCategory.swift` — enum with displayName and systemImage (SF Symbol) for each category

Removed Xcode-generated `Item.swift`. Updated `RedeyeApp.swift` to register Trip/TripDay/Activity in the ModelContainer schema. Updated `ContentView.swift` to stub the three-tab layout (Trips/Map/Nearby) and remove Item references. Preferences stored as `preferencesData: Data?` (JSON-encoded) since SwiftData doesn't support `[String: Any]` directly. Build verified green on iPhone 17 simulator.

## 2026-09-12 — T5: Zod validation schemas

Created `api/lib/schemas.ts` with all Zod schemas from the LLD: CreateTripInput, UpdateTripInput, CreateActivityInput, UpdateActivityInput, ReorderInput, plus AI generation output schemas (GeneratedStructuredDay, GeneratedUnstructuredGroup, StructuredItinerary, UnstructuredItinerary). Exported inferred TypeScript types for request inputs. Used Zod 4 API (`gte`/`lte` instead of `min`/`max` on numbers, `z.record(z.string(), z.unknown())` for preferences). Typecheck green.

## 2026-09-12 — T6: Supabase client helpers and auth middleware

Fleshed out `api/lib/supabase.ts` and `api/lib/auth.ts` from the T3 stubs. Changes from stubs: added explicit `SupabaseClient` return type on `createSupabaseClient()`, exported `AuthResult` discriminated union type from auth, and `authenticateRequest()` now returns a ready-to-use RLS-scoped `supabase` client alongside `userId` and `token` — so route handlers get auth + client in one call instead of two steps. Typecheck green.
