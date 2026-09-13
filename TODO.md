# TODO

Current and near-term work. Mutable — edit freely, unlike the journal or decisions log.

Task format: `- [ ] \`T<n>\` <description> — <manual|agent>[, depends-on: T<a>, T<b>]`. IDs are sequential and never reused. A task is safe to hand to a parallel agent once every id in its `depends-on` is checked off. See the `plan-tasks` skill.

## Phase 1: Foundation

- [x] `T1` Create Xcode project (SwiftUI app target, iOS 17+, bundle ID, signing) — manual
- [x] `T2` Set up Supabase project, create initial schema migration (trips, trip_days, activities tables, RLS policies, updated_at trigger) — manual, design: docs/designs/2026-09-11-technical-design-lld.md
- [x] `T3` Scaffold Next.js API project in `api/` with TypeScript, install dependencies (supabase-js, ai, zod) — agent, complexity: simple
- [x] `T4` Define SwiftData models (Trip, TripDay, Activity, SyncStatus, enums) with relationships and invariants — agent, complexity: complex, depends-on: T1, design: docs/designs/2026-09-11-technical-design-lld.md
- [x] `T5` Define Zod validation schemas in `api/lib/schemas.ts` (CreateTripInput, UpdateTripInput, CreateActivityInput, UpdateActivityInput, ReorderInput, AI output schemas) — agent, complexity: simple, depends-on: T3, design: docs/designs/2026-09-11-technical-design-lld.md
- [x] `T6` Create Supabase client helpers in `api/lib/supabase.ts` and auth middleware in `api/lib/auth.ts` — agent, complexity: simple, depends-on: T3
- [x] `T7` Create APIClient service (HTTP wrapper with JWT attachment, request/response encoding, error mapping) — agent, complexity: simple, depends-on: T1, T5
- [x] `T8` Create AuthService (Supabase Auth, Keychain storage, token refresh, Apple Sign In) — agent, complexity: complex, depends-on: T1
- [x] `T9` Create NetworkMonitor service (NWPathMonitor wrapper, publishes isOnline) — agent, complexity: simple, depends-on: T1
- [ ] `T10` Create auth UI (AuthGateView, login/signup form, AppleSignInButton) — agent, complexity: simple, depends-on: T8
- [ ] `T11` Wire up app entry point (RedeyeApp.swift: ModelContainer, service injection, AuthGateView → ContentView with tab bar) — agent, complexity: simple, depends-on: T4, T8, T9, T10

## Phase 2: Trip CRUD

- [ ] `T12` API route: GET/POST /api/trips (list with status filter, create with trip_day generation) — agent, complexity: simple, depends-on: T5, T6
- [ ] `T13` API route: GET/PATCH/DELETE /api/trips/[id] (detail with nested days+activities, update with date-change day regeneration, delete with cascade) — agent, complexity: complex, depends-on: T12
- [ ] `T14` TripListView + TripListViewModel (active/archived sections, archive/delete with confirmation) — agent, complexity: simple, depends-on: T4, T7, T11, design: docs/designs/2026-09-11-technical-design-lld.md
- [ ] `T15` CreateTripView + CreateTripViewModel (form with destination, dates, mode picker, optional home base + preferences, trip_day generation on save) — agent, complexity: simple, depends-on: T14
- [ ] `T16` EditTripView + EditTripViewModel (edit fields, date change with day regeneration, mode switch logic) — agent, complexity: complex, depends-on: T14, design: docs/designs/2026-09-11-technical-design-lld.md

## Phase 3: Activity Views

- [ ] `T17` ActivityRowView + ActivityDetailView + ActivityDetailViewModel (compact row, full detail, status changes, open-in-maps) — agent, complexity: simple, depends-on: T4
- [ ] `T18` EditActivityView + EditActivityViewModel (add/edit form with validation, quick-add mode with minimal fields) — agent, complexity: simple, depends-on: T17
- [ ] `T19` API route: POST /api/trips/[id]/activities + PATCH/DELETE /api/activities/[id] (activity CRUD) — agent, complexity: simple, depends-on: T13
- [ ] `T20` API route: PATCH /api/trips/[id]/activities/reorder (batch reorder) — agent, complexity: simple, depends-on: T19
- [ ] `T21` StructuredTripView + StructuredItineraryViewModel (day tabs, chronological activity list, unassigned section) — agent, complexity: complex, depends-on: T14, T17, T18, design: docs/designs/2026-09-11-technical-design-lld.md
- [ ] `T22` Drag-to-reorder and move-between-days for structured mode — agent, complexity: complex, depends-on: T21, T20
- [ ] `T23` UnstructuredTripView + UnstructuredListViewModel (area/category grouping, flat list toggle) — agent, complexity: complex, depends-on: T14, T17, T18, design: docs/designs/2026-09-11-technical-design-lld.md
- [ ] `T24` Drag-to-reorder and move-between-areas for unstructured mode — agent, complexity: complex, depends-on: T23, T20

## Phase 4: AI Generation

- [ ] `T25` AI SDK configuration in `api/lib/ai.ts` (model selection, system prompt construction from trip data) — agent, complexity: complex, depends-on: T3, design: docs/designs/2026-09-11-technical-design-lld.md
- [ ] `T26` API route: POST /api/trips/[id]/generate (streamObject with structured/unstructured Zod schemas, SSE output) — agent, complexity: complex, depends-on: T25, T5, T13
- [ ] `T27` SSEClient service (URLSession AsyncBytes, SSE line parsing, AsyncThrowingStream output) — agent, complexity: complex, depends-on: T7, design: docs/designs/2026-09-11-technical-design-lld.md
- [ ] `T28` GenerateView + GenerateViewModel (trigger generation, stream parsing, progressive activity display) — agent, complexity: complex, depends-on: T27, T4
- [ ] `T29` ReviewProposalsView (accept/reject individual activities, accept-all, isProposed flag gating) — agent, complexity: simple, depends-on: T28

## Phase 5: Maps & Location

- [ ] `T30` LocationService (CLLocationManager wrapper, on-demand permission, one-shot location fix, denied state) — agent, complexity: complex, depends-on: T1, design: docs/designs/2026-09-11-technical-design-lld.md
- [ ] `T31` TripMapView + MapViewModel (Map with activity annotations, category-colored SF Symbol pins, home base marker, day filter) — agent, complexity: complex, depends-on: T4, T17, T30, design: docs/designs/2026-09-11-technical-design-lld.md
- [ ] `T32` ActivityAnnotation + ActivityMapCallout (custom pin rendering, tap-to-open summary, directions button with Apple Maps / Google Maps routing) — agent, complexity: simple, depends-on: T31
- [ ] `T33` NearbyListView + NearbyViewModel (distance calculation, radius filter with adjustable default, today highlighting for structured mode) — agent, complexity: complex, depends-on: T30, T17, design: docs/designs/2026-09-11-technical-design-lld.md

## Phase 6: Search & Discovery

- [ ] `T34` Google Places client in `api/lib/places.ts` — agent, complexity: simple, depends-on: T3
- [ ] `T35` API routes: GET /api/places/search + GET /api/places/[placeId] (proxy with API key server-side) — agent, complexity: simple, depends-on: T34, T6
- [ ] `T36` SearchView + SearchViewModel (text input with 300ms debounce, results display, add-to-trip action) — agent, complexity: simple, depends-on: T7, T18, T35
- [ ] `T37` Browsable discovery (suggestions from AI-generated activities when search query is empty) — agent, complexity: simple, depends-on: T36, T4

## Phase 7: Offline & Sync

- [ ] `T38` SyncService — push worker (scan pendingCreate/Update/Delete, POST/PATCH/DELETE to API, update syncStatus, 2s debounce, parent-before-child ordering) — agent, complexity: complex, depends-on: T7, T4, T9, design: docs/designs/2026-09-11-technical-design-lld.md
- [ ] `T39` SyncService — pull worker (fetch all trips from API, merge into SwiftData: server-wins for synced, local-wins for pending, delete orphaned synced records) — agent, complexity: complex, depends-on: T38, design: docs/designs/2026-09-11-technical-design-lld.md
- [ ] `T40` Wire sync triggers (enqueuePush after every ViewModel write, syncAll on foreground, retry on online transition) — agent, complexity: simple, depends-on: T39
- [ ] `T41` Offline indicator UI (subtle banner when NetworkMonitor.isOnline == false) — agent, complexity: simple, depends-on: T9, T11

## Phase 8: Polish & Distribution

- [ ] `T42` Dark mode pass (verify all views, fix any hardcoded colors) — agent, complexity: simple, depends-on: T21, T23, T31, T33
- [ ] `T43` Dynamic Type support (verify text scales, fix any fixed-size fonts) — agent, complexity: simple, depends-on: T42
- [ ] `T44` One-handed usability pass (verify primary actions reachable with thumb, FAB placement) — manual, depends-on: T42
- [ ] `T45` TestFlight build and distribution to friends — manual, depends-on: T40, T42
