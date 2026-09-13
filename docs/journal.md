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

## 2026-09-12 — T7: APIClient service

Created `Redeye/Redeye/Services/APIClient.swift` — the iOS HTTP client that all ViewModels and SyncService will use to talk to the API. Contains:

- **Response DTOs** (`TripDTO`, `TripDayDTO`, `ActivityDTO`, `PlaceResultDTO`, `PlaceDetailDTO`) — Codable structs with `CodingKeys` mapping snake_case JSON to Swift conventions.
- **Request DTOs** (`CreateTripDTO`, `UpdateTripDTO`, `CreateActivityDTO`, `UpdateActivityDTO`, `ReorderItemDTO`) — Encodable structs matching the Zod schemas from T5.
- **AnyCodable** — lightweight type-erased Codable wrapper for the `preferences` JSON field.
- **APIError** enum — covers unauthorized, notFound, validationError, serverError, networkError, decodingError. Parses error messages from the API's `{ error: string }` response shape.
- **APIClient** class (`@Observable`) — generic request builder with `tokenProvider` closure for JWT injection (will be wired to AuthService in T11). Methods match the LLD's service protocol: `fetchTrips`, `createTrip`, `updateTrip`, `deleteTrip`, `createActivity`, `updateActivity`, `deleteActivity`, `reorderActivities`, `searchPlaces`, `placeDetail`. SSE streaming (`generateItinerary`) deferred to T27 (SSEClient).

Design note: `tokenProvider` is a closure rather than a direct AuthService dependency — avoids a circular reference and lets tests inject tokens without mocking the full auth stack. The 401-retry-with-refresh logic (from the LLD's failure table) will be added when AuthService (T8) exists.

Build verified green on iPhone 17 simulator.

## 2026-09-12 — T8: AuthService

Created `Redeye/Redeye/Services/AuthService.swift` — authentication service using direct HTTP calls to Supabase Auth REST API. No external SDK dependency; uses the Security framework for Keychain and AuthenticationServices for Apple Sign In.

- **AuthSession** — Codable struct holding accessToken, refreshToken, expiresAt, userId. Persisted to Keychain.
- **KeychainHelper** — private enum wrapping Security framework for save/load/delete of the session. Uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` for offline access.
- **AuthError** — error enum covering invalidCredentials, emailTaken, networkError, serverError, noSession, appleSignInFailed, keychainError.
- **AuthService** (`@Observable`) — init reads Keychain for stored session. Publishes `isAuthenticated` and `currentUserId`. Methods: `signInWithEmail`, `signUpWithEmail`, `signInWithApple` (takes `ASAuthorizationAppleIDCredential`, sends id_token to Supabase), `signOut`, `refreshTokenIfNeeded` (returns valid JWT, 30s expiry buffer, signs out if refresh fails), `currentAccessToken`.

Design note: chose direct HTTP to Supabase Auth REST endpoints (`/auth/v1/token`, `/auth/v1/signup`) over adding the full Supabase Swift SDK — keeps the dependency footprint minimal since APIClient already handles all data HTTP. The `currentAccessToken()` method is what APIClient's `tokenProvider` closure will call (wired in T11). Apple Sign In sends the id_token to Supabase's `id_token` grant type per their OIDC provider support.

Build verified green on iPhone 17 simulator.

## 2026-09-13 — T9: NetworkMonitor service

Created `Redeye/Redeye/Services/NetworkMonitor.swift` — `@Observable` class wrapping `NWPathMonitor`. Publishes `isOnline` (Bool), updated on the main thread via `pathUpdateHandler`. Monitor runs on a dedicated serial dispatch queue; cancelled in `deinit`. Build verified green on iPhone 17 simulator.
