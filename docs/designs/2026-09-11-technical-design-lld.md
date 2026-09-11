# Redeye — Low-Level Design

**Last updated:** 2026-09-11
**HLD:** [`2026-09-11-technical-design.md`](2026-09-11-technical-design.md)
**Product Spec:** [`product-spec.md`](product-spec.md)

## Overview

The iOS app is a SwiftUI MVVM app backed by SwiftData for local persistence and a Vercel-hosted Next.js API for sync, AI generation, and Places search. The app reads and writes SwiftData exclusively; a background SyncService reconciles with Supabase. This document pins every mechanism left open by the HLD and traces each file, interface, and flow back to the product spec requirements it fulfills.

---

## 1. Package/File Layout

### 1.1 iOS App (`Redeye/`)

```
Redeye/
├── RedeyeApp.swift                 — @main entry, ModelContainer setup, root navigation, service injection
├── ContentView.swift               — Tab bar root (Trips / Map / Nearby)
│
├── Models/
│   ├── Trip.swift                  — @Model: trip entity with all fields
│   ├── TripDay.swift               — @Model: day within a structured trip
│   ├── Activity.swift              — @Model: activity entity
│   ├── SyncStatus.swift            — enum: synced, pendingCreate, pendingUpdate, pendingDelete
│   └── ActivityCategory.swift      — enum: restaurant, attraction, shopping, museum, nightlife, other
│
├── Views/
│   ├── Trips/
│   │   ├── TripListView.swift      — list of active + archived trips (FR-1.2)
│   │   ├── TripRowView.swift       — single trip row in list
│   │   ├── CreateTripView.swift    — create trip sheet (FR-1.1)
│   │   └── EditTripView.swift      — edit trip details (FR-1.3)
│   │
│   ├── Itinerary/
│   │   ├── StructuredTripView.swift     — day tabs + activity timeline (FR-2.1, FR-2.2)
│   │   ├── DayColumnView.swift          — single day's activity list
│   │   ├── UnstructuredTripView.swift   — area/category grouped list (FR-3.1, FR-3.2)
│   │   ├── AreaSectionView.swift        — single area group with category subsections
│   │   └── UnassignedActivitiesView.swift — holding area for unassigned activities (FR-2.6)
│   │
│   ├── Activities/
│   │   ├── ActivityDetailView.swift     — full activity view (FR-6.3)
│   │   ├── EditActivityView.swift       — add/edit activity form (FR-2.3, FR-3.3, FR-7.3)
│   │   └── ActivityRowView.swift        — compact row used in lists
│   │
│   ├── Generate/
│   │   ├── GenerateView.swift           — generation trigger + progress (FR-4.1, FR-4.4)
│   │   └── ReviewProposalsView.swift    — accept/reject AI results (FR-4.5)
│   │
│   ├── Map/
│   │   ├── TripMapView.swift            — map with activity pins (FR-6.1, FR-6.2)
│   │   ├── ActivityAnnotation.swift     — custom pin per category (FR-6.2)
│   │   └── ActivityMapCallout.swift     — tap-to-open summary (FR-6.3)
│   │
│   ├── Nearby/
│   │   └── NearbyListView.swift         — distance-sorted activities (FR-6.6, FR-7.1)
│   │
│   ├── Search/
│   │   ├── SearchView.swift             — search input + results (FR-5.1, FR-5.2)
│   │   └── SearchResultRow.swift        — single search result with add action (FR-5.3)
│   │
│   └── Auth/
│       ├── AuthGateView.swift           — login/signup screen
│       └── AppleSignInButton.swift      — ASAuthorizationController wrapper
│
├── ViewModels/
│   ├── TripListViewModel.swift          — trip list logic, archive/delete (FR-1.2, FR-1.4, FR-1.5)
│   ├── CreateTripViewModel.swift        — trip creation + trip_day generation (FR-1.1)
│   ├── EditTripViewModel.swift          — trip editing + date-change day regeneration (FR-1.3, FR-1.6, FR-2.7)
│   ├── StructuredItineraryViewModel.swift — day navigation, activity ordering (FR-2.1–2.7)
│   ├── UnstructuredListViewModel.swift  — area/category grouping, flat list toggle (FR-3.1–3.6)
│   ├── ActivityDetailViewModel.swift    — status changes, open in maps (FR-6.3, FR-6.4, FR-7.2)
│   ├── EditActivityViewModel.swift      — add/edit validation + save (FR-2.3, FR-3.3, FR-7.3)
│   ├── GenerateViewModel.swift          — stream parsing, proposal state (FR-4.1–4.8)
│   ├── MapViewModel.swift               — annotations, day filter, home base pin (FR-6.1–6.8)
│   ├── NearbyViewModel.swift            — distance calc, radius filter (FR-6.6, FR-7.1)
│   ├── SearchViewModel.swift            — query debounce, results (FR-5.1–5.4)
│   └── AuthViewModel.swift              — login/signup/token state
│
├── Services/
│   ├── APIClient.swift              — HTTP wrapper: request building, JWT attachment, error mapping
│   ├── SSEClient.swift              — Server-Sent Events stream reader for AI generation
│   ├── SyncService.swift            — offline-first sync engine (NFR-2.1, NFR-2.2, NFR-3.1, NFR-3.2)
│   ├── LocationService.swift        — CLLocationManager wrapper (NFR-4.1–4.4)
│   ├── AuthService.swift            — Supabase Auth + Keychain storage
│   └── NetworkMonitor.swift         — NWPathMonitor wrapper, publishes isOnline (NFR-2.5)
│
├── Utilities/
│   ├── CLLocation+Distance.swift    — extension for distance-to-activity calculation
│   ├── Date+Formatting.swift        — date display helpers
│   └── View+Modifiers.swift         — shared view modifiers (e.g. card style)
│
└── Resources/
    ├── Assets.xcassets               — app icon, category colors
    └── Info.plist                     — location usage descriptions
```

**God-file risk:** `SyncService.swift` handles push, pull, merge, retry — could grow large. Split into `SyncPushWorker` and `SyncPullWorker` if it exceeds ~300 lines.

### 1.2 API (`api/`)

```
api/
├── app/
│   ├── api/
│   │   ├── trips/
│   │   │   └── route.ts              — GET (list), POST (create)
│   │   ├── trips/[id]/
│   │   │   └── route.ts              — GET (detail + activities), PATCH (update), DELETE
│   │   ├── trips/[id]/activities/
│   │   │   └── route.ts              — POST (add activity)
│   │   ├── trips/[id]/activities/reorder/
│   │   │   └── route.ts              — PATCH (batch reorder)
│   │   ├── trips/[id]/generate/
│   │   │   └── route.ts              — POST (AI generation, SSE stream)
│   │   ├── activities/[id]/
│   │   │   └── route.ts              — PATCH (update), DELETE
│   │   └── places/
│   │       ├── search/
│   │       │   └── route.ts          — GET (text search proxy)
│   │       └── [placeId]/
│   │           └── route.ts          — GET (place details proxy)
│   └── layout.ts
├── lib/
│   ├── supabase.ts                   — createClient with service role + per-request auth client
│   ├── auth.ts                       — middleware: extract + verify JWT, attach user_id
│   ├── ai.ts                         — AI SDK config, model selection, system prompts
│   ├── places.ts                     — Google Places API client wrapper
│   └── schemas.ts                    — Zod schemas for request/response validation + AI structured output
├── package.json
└── tsconfig.json
```

### 1.3 Supabase (`supabase/`)

```
supabase/
└── migrations/
    └── 001_initial_schema.sql        — trips, trip_days, activities tables + RLS policies + updated_at trigger
```

---

## 2. Data Model — Shape Sketches

### 2.1 SwiftData Models

```
Trip
  id: UUID                           — local ID, matches server ID after sync
  serverId: UUID?                    — nil until confirmed by server
  userId: String                     — from auth, used for local filtering
  title: String
  destination: String
  startDate: Date
  endDate: Date
  mode: TripMode                     — .structured | .unstructured
  homeBaseName: String?
  homeBaseAddress: String?
  homeBaseLat: Double?
  homeBaseLng: Double?
  preferences: [String: Any]?        — stored as JSON Data in SwiftData
  status: TripStatus                 — .active | .archived
  syncStatus: SyncStatus
  lastModified: Date                 — local write timestamp
  createdAt: Date
  days: [TripDay]                    — @Relationship, cascade delete
  activities: [Activity]             — @Relationship, cascade delete
```

```
TripDay
  id: UUID
  serverId: UUID?
  trip: Trip                         — @Relationship(inverse: \Trip.days)
  date: Date
  dayNumber: Int
  notes: String?
  syncStatus: SyncStatus
  lastModified: Date
  activities: [Activity]             — @Relationship, nullify on delete
```

```
Activity
  id: UUID
  serverId: UUID?
  trip: Trip                         — @Relationship(inverse: \Trip.activities)
  tripDay: TripDay?                  — @Relationship(inverse: \TripDay.activities), nil = unassigned or unstructured
  name: String
  descriptionText: String?           — "description" is a reserved name in Swift
  category: ActivityCategory
  area: String?
  latitude: Double?
  longitude: Double?
  address: String?
  startTime: Date?                   — time-of-day stored as Date, display only HH:mm
  endTime: Date?
  durationMin: Int?
  sortOrder: Int
  source: ActivitySource             — .manual | .aiGenerated | .placesAPI
  placeId: String?
  status: ActivityStatus             — .planned | .visited | .skipped
  notes: String?
  isProposed: Bool                   — transient: true during AI review, not synced
  syncStatus: SyncStatus
  lastModified: Date
  createdAt: Date
```

**Invariant INV-1:** An activity with `tripDay != nil` must belong to the same trip as that day (`activity.trip == activity.tripDay.trip`). Enforced in EditActivityViewModel before save.

**Invariant INV-2:** When `trip.mode == .unstructured`, all activities for that trip must have `tripDay == nil` and `startTime == nil` and `endTime == nil`. Enforced during mode switch (FR-1.6).

**Invariant INV-3:** `TripDay.dayNumber` is 1-indexed and contiguous within a trip. Regenerated on date changes (FR-2.7).

### 2.2 API Zod Schemas (`lib/schemas.ts`)

```
CreateTripInput
  title: string
  destination: string
  startDate: string (ISO date)
  endDate: string (ISO date)
  mode: "structured" | "unstructured"
  homeBaseName?: string
  homeBaseAddress?: string
  homeBaseLat?: number
  homeBaseLng?: number
  preferences?: object

UpdateTripInput — partial of CreateTripInput + { status?: "active" | "archived" }

CreateActivityInput
  name: string
  category: "restaurant" | "attraction" | "shopping" | "museum" | "nightlife" | "other"
  tripDayId?: string (uuid)
  area?: string
  latitude?: number
  longitude?: number
  address?: string
  startTime?: string (HH:mm)
  endTime?: string (HH:mm)
  durationMin?: number
  sortOrder?: number
  source?: "manual" | "ai_generated" | "places_api"
  placeId?: string
  notes?: string

UpdateActivityInput — partial of CreateActivityInput + { status?: "planned" | "visited" | "skipped" }

ReorderInput — array of { id: string, sortOrder: number, tripDayId?: string | null }

GeneratedStructuredDay (AI output schema)
  dayNumber: number
  activities: GeneratedActivity[]

GeneratedUnstructuredGroup (AI output schema)
  area: string
  activities: GeneratedActivity[]

GeneratedActivity
  name: string
  category: enum
  description: string
  area: string
  latitude: number
  longitude: number
  address: string
  durationMin: number
  startTime?: string (structured only)
  endTime?: string (structured only)
```

### 2.3 Supabase Schema Invariants

- `updated_at` trigger: a `BEFORE UPDATE` trigger on `trips` and `activities` sets `updated_at = now()`. This is the server-side clock for conflict resolution.
- RLS policy: all tables have `USING (auth.uid() = user_id)` for SELECT/UPDATE/DELETE and `WITH CHECK (auth.uid() = user_id)` for INSERT.
- Cascade: `trip_days.trip_id` and `activities.trip_id` have `ON DELETE CASCADE`. `activities.trip_day_id` has `ON DELETE SET NULL` (day deleted → activity becomes unassigned, not deleted).

---

## 3. Interfaces / API Surface

### 3.1 API Routes

| Method | Route | Input | Output | Auth | Req |
|--------|-------|-------|--------|------|-----|
| GET | /api/trips | ?status=active\|archived | `Trip[]` (with nested days + activities) | JWT | FR-1.2 |
| POST | /api/trips | CreateTripInput | `Trip` (with generated days if structured) | JWT | FR-1.1 |
| GET | /api/trips/[id] | — | `Trip` with days + activities | JWT | FR-1.2 |
| PATCH | /api/trips/[id] | UpdateTripInput | `Trip` (days regenerated if dates changed) | JWT | FR-1.3, FR-1.4, FR-1.6 |
| DELETE | /api/trips/[id] | — | 204 | JWT | FR-1.5 |
| POST | /api/trips/[id]/activities | CreateActivityInput | `Activity` | JWT | FR-2.3, FR-3.3, FR-7.3 |
| PATCH | /api/trips/[id]/activities/reorder | ReorderInput | 204 | JWT | FR-2.4, FR-2.5, FR-3.4, FR-3.5 |
| PATCH | /api/activities/[id] | UpdateActivityInput | `Activity` | JWT | FR-7.2 |
| DELETE | /api/activities/[id] | — | 204 | JWT | — |
| POST | /api/trips/[id]/generate | — | SSE stream of activities | JWT | FR-4.1–4.4 |
| GET | /api/places/search | ?query&lat&lng | `PlaceResult[]` | JWT | FR-5.1, FR-5.2 |
| GET | /api/places/[placeId] | — | `PlaceDetail` | JWT | FR-5.4 |

### 3.2 iOS Service Protocols

```
APIClient
  func fetchTrips(status: TripStatus?) async throws -> [TripDTO]
  func createTrip(_ input: CreateTripDTO) async throws -> TripDTO
  func updateTrip(id: UUID, _ input: UpdateTripDTO) async throws -> TripDTO
  func deleteTrip(id: UUID) async throws
  func createActivity(tripId: UUID, _ input: CreateActivityDTO) async throws -> ActivityDTO
  func updateActivity(id: UUID, _ input: UpdateActivityDTO) async throws -> ActivityDTO
  func deleteActivity(id: UUID) async throws
  func reorderActivities(tripId: UUID, _ items: [ReorderItemDTO]) async throws
  func generateItinerary(tripId: UUID) -> AsyncThrowingStream<GeneratedActivityDTO, Error>
  func searchPlaces(query: String, near: CLLocationCoordinate2D?) async throws -> [PlaceResultDTO]
  func placeDetail(placeId: String) async throws -> PlaceDetailDTO
```

The `generateItinerary` method returns an `AsyncThrowingStream` — the SSE mechanism described in §4.2.

```
SyncService
  var isSyncing: Bool                — published, for UI indicators
  func pushPendingChanges() async    — push all local pending writes to server
  func pullAndMerge() async          — fetch server state, merge into SwiftData
  func syncAll() async               — pull then push (called on foreground)
  func enqueuePush()                 — schedule a background push after a local write
```

```
LocationService
  var currentLocation: CLLocation?   — published, nil until requested
  var authorizationStatus: CLAuthorizationStatus — published
  func requestLocation()             — one-shot location fix (not continuous)
```

```
AuthService
  var isAuthenticated: Bool          — published
  var currentUserId: String?         — published
  func signInWithEmail(email: String, password: String) async throws
  func signUpWithEmail(email: String, password: String) async throws
  func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws
  func signOut()
  func refreshTokenIfNeeded() async throws -> String   — returns valid JWT
```

```
NetworkMonitor
  var isOnline: Bool                 — published, from NWPathMonitor
```

---

## 4. Flow Sequences

### 4.1 App Launch (NFR-1.6: sub-2s to usable)

1. `RedeyeApp.init` — create `ModelContainer` with Trip, TripDay, Activity schemas
2. `RedeyeApp.body` — inject services into environment, show `AuthGateView`
3. `AuthService.init` — read Keychain for stored Supabase session
4. If session exists and not expired → set `isAuthenticated = true`, show `ContentView`
5. If session expired → attempt `refreshTokenIfNeeded()` in background; show `ContentView` immediately (offline-capable)
6. If no session → show login screen
7. `ContentView.onAppear` → `SyncService.syncAll()` in a background Task (pull then push)
8. `NetworkMonitor.init` → start `NWPathMonitor`, publish `isOnline`

### 4.2 Create Trip (FR-1.1)

1. User taps "+" on TripListView → sheet presents `CreateTripView`
2. User fills: title, destination, start date, end date, mode, optional home base + preferences
3. `CreateTripViewModel.save()`:
   a. Create `Trip` in SwiftData with `syncStatus: .pendingCreate`
   b. If mode == .structured: generate `TripDay` objects for each date in range (INV-3)
   c. Dismiss sheet → TripListView updates reactively
   d. `SyncService.enqueuePush()` → background POST /api/trips
   e. On success: set `serverId`, set `syncStatus: .synced` on trip and days

### 4.3 View Structured Trip (FR-2.1, FR-2.2)

1. User taps trip in list → `StructuredTripView` with trip's `TripDay` array
2. Days displayed as horizontally scrollable tabs (Day 1, Day 2, ...)
3. Selected day shows activities sorted by `startTime`, then `sortOrder`
4. Unassigned activities (tripDay == nil) available via a pull-up section at bottom (FR-2.6)
5. Drag-to-reorder within a day: update `sortOrder` values in SwiftData, `enqueuePush()` (FR-2.4)
6. Long-press activity → context menu: move to day, remove from day, edit, delete (FR-2.5, FR-2.6)

### 4.4 View Unstructured Trip (FR-3.1, FR-3.2, FR-3.6)

1. User taps trip in list → `UnstructuredTripView`
2. Activities queried: `WHERE tripDayId == nil`, grouped by `area` property
3. Within each area section, sub-grouped by `category` (FR-3.2)
4. Toggle at top switches between grouped view and flat list sorted by `sortOrder` (FR-3.6)
5. Drag-to-reorder within a group: update `sortOrder`, `enqueuePush()` (FR-3.4)
6. Swipe actions: move to different area, change category, edit, delete (FR-3.5)

### 4.5 AI Generation + Accept/Reject (FR-4.1–4.8)

1. User taps "Generate Itinerary" on trip detail → sheet presents `GenerateView`
2. If trip has existing AI-generated activities: show warning that re-generation replaces them (FR-4.7)
3. User confirms → `GenerateViewModel.generate()`:
   a. Delete existing activities with `source == .aiGenerated` from SwiftData (manual ones preserved per FR-4.7)
   b. Call `APIClient.generateItinerary(tripId:)` → returns `AsyncThrowingStream`
   c. For each `GeneratedActivityDTO` received:
      - Create `Activity` in SwiftData with `isProposed: true`, `source: .aiGenerated`
      - UI updates reactively — activities appear one by one (FR-4.4)
   d. On stream complete: transition to `ReviewProposalsView`
4. `ReviewProposalsView` shows all proposed activities with accept/reject toggles (FR-4.5)
5. User taps "Accept Selected":
   a. Accepted: set `isProposed = false`, assign to appropriate day (structured) or area (unstructured)
   b. Rejected: delete from SwiftData
   c. `SyncService.enqueuePush()` — only accepted activities sync to server

### 4.6 Mode Switch (FR-1.6)

1. User changes mode in `EditTripView`
2. `EditTripViewModel.switchMode(to:)`:
   a. **Structured → Unstructured:**
      - Set `trip.mode = .unstructured`
      - For all activities: set `tripDay = nil`, `startTime = nil`, `endTime = nil`
      - Preserve `area` (already set) and `sortOrder`
      - Delete all `TripDay` objects for this trip
      - Enforce INV-2
   b. **Unstructured → Structured:**
      - Set `trip.mode = .structured`
      - Generate `TripDay` objects from date range (INV-3)
      - All activities remain with `tripDay = nil` (unassigned)
      - User assigns them to days manually
   c. `SyncService.enqueuePush()`

### 4.7 Sync — Push (NFR-2.2, NFR-3.1)

1. `SyncService.pushPendingChanges()` called by `enqueuePush()` or `syncAll()`
2. Query SwiftData for all records where `syncStatus != .synced`, ordered by `lastModified`
3. For each pending record:
   a. `.pendingCreate` → POST to API → on success, update `serverId` + set `.synced`
   b. `.pendingUpdate` → PATCH to API with `lastModified` as If-Unmodified-Since → on success, set `.synced`
   c. `.pendingDelete` → DELETE to API → on success, remove from SwiftData
4. On network failure: leave `syncStatus` as-is, retry on next `enqueuePush()` or foreground event
5. Process trips before activities (parent before child) to avoid FK violations

### 4.8 Sync — Pull + Merge (NFR-2.1, NFR-3.2)

1. `SyncService.pullAndMerge()` called on app foreground and after successful push
2. Fetch GET /api/trips (returns all trips with nested days + activities)
3. For each server record:
   a. Find matching local record by `serverId`
   b. If no local match: insert new record with `syncStatus: .synced`
   c. If local match with `.synced`: overwrite with server data
   d. If local match with `.pending*`: keep local version (local wins for pending changes)
4. For local records with `.synced` that have no server match: delete locally (deleted on server/another device)
5. **Do not** delete local `.pending*` records missing from server — they haven't been pushed yet

### 4.9 Map View (FR-6.1–6.8)

1. User taps Map tab → `TripMapView`
2. `MapViewModel` loads activities for the currently selected trip from SwiftData
3. Each activity with non-nil lat/lng becomes an `ActivityAnnotation`:
   - Icon: SF Symbol by category (fork.knife, building.columns, bag, theatermasks, music.mic, mappin) (FR-6.2)
   - Color: per-category from Assets.xcassets
4. Home base shown as house.fill annotation in distinct color (FR-6.8)
5. Day filter (structured mode): segmented control selects a day → MapViewModel filters annotations by `tripDay` (FR-6.7)
6. Tap annotation → `ActivityMapCallout` popover with name, category, time, notes snippet (FR-6.3)
7. "Directions" button in callout → `openInMaps()` (FR-6.4):
   - Build `MKMapItem` from coordinates
   - Check `UIApplication.canOpenURL("comgooglemaps://")` → if yes, open Google Maps URL
   - Otherwise `MKMapItem.openInMaps(launchOptions:)` for Apple Maps
8. User location button: `MapUserLocationButton()` in `.mapControls` — only shows after LocationService has authorization (FR-6.5)

### 4.10 Nearby Activities (FR-6.6, FR-7.1)

1. User taps Nearby tab → `NearbyListView`
2. `NearbyViewModel.onAppear`:
   a. If `LocationService.authorizationStatus == .notDetermined`: call `requestLocation()` which triggers permission prompt (NFR-4.1)
   b. If denied: show explanatory message, list all activities without distance (NFR-4.4)
   c. If authorized: get one-shot location fix
3. With location: calculate distance from `currentLocation` to each activity's coordinates using `CLLocation.distance(from:)`
4. Filter by radius (default 1 km, adjustable via stepper/slider) (FR-6.6)
5. Sort by distance ascending
6. In structured mode: also highlight which activities are for today (FR-7.1) by matching `TripDay.date` to current date

### 4.11 Activity Search (FR-5.1–5.4)

1. User opens search from trip detail → `SearchView`
2. Text input with 300ms debounce in `SearchViewModel`
3. On query change: call `APIClient.searchPlaces(query:near:)` passing trip destination coordinates as location bias
4. Results displayed as `SearchResultRow`: name, category, address, rating (FR-5.2)
5. "Add" button on each result → `EditActivityView` pre-filled with place data (FR-5.3):
   - Name, address, lat/lng, category (mapped from Google type), placeId populated
   - In structured mode: user picks a day and time
   - In unstructured mode: user picks an area (pre-filled with place neighborhood if available)
6. Browsable discovery (FR-5.4): when search query is empty, show AI-generated suggestions for the destination — these come from the trip's existing AI activities or a lightweight prompt, not a Places API call

### 4.12 Quick-Add Activity (FR-7.3)

1. From trip detail or nearby view, FAB-style "+" button
2. Opens `EditActivityView` in quick-add mode: only name and category required
3. Area defaults to nearest known area (from location if available, else trip destination)
4. If structured mode: defaults to today's TripDay if within trip date range
5. Save → SwiftData write → `enqueuePush()`

### 4.13 Trip Date Change (FR-2.7)

1. User edits dates in `EditTripView`
2. `EditTripViewModel.updateDates(newStart:newEnd:)`:
   a. Determine days to add and days to remove
   b. Activities on removed days: set `tripDay = nil` (become unassigned), not deleted
   c. Insert new `TripDay` objects for added dates
   d. Renumber all days sequentially (INV-3)
   e. Save to SwiftData, `enqueuePush()`

---

## 5. Mechanisms

### 5.1 SSE Streaming for AI Generation

**Mechanism:** Server uses Vercel AI SDK `streamObject()` which outputs a `text/event-stream` response. Client uses `URLSession` with `AsyncBytes` to read line by line.

**Why SSE over WebSocket:** The AI generation is a unidirectional server→client stream. SSE is simpler (no connection upgrade, works through all proxies), and `streamObject()` outputs SSE natively. WebSocket would add complexity with no benefit for a one-way stream.

**Client implementation:**
```
SSEClient
  func stream(url: URL, token: String) -> AsyncThrowingStream<Data, Error>
  — Opens URLRequest with Accept: text/event-stream
  — Reads URLSession.bytes(for:) line by line
  — Parses SSE format: lines starting with "data: " are payloads
  — Yields each parsed JSON chunk
  — Handles reconnection: not needed, generation is one-shot
```

### 5.2 SwiftData Sync Status Tracking

**Mechanism:** Every model has a `syncStatus: SyncStatus` enum and `lastModified: Date`. All ViewModel writes set `syncStatus` to the appropriate pending state and `lastModified` to `Date()`. SyncService queries `syncStatus != .synced` to find work.

**Why per-record status over a change log:** Simpler — no separate table to manage, no ordering concerns, no cleanup. The downside is we can't replay the exact sequence of changes, but we don't need to: last-write-wins means only the final state matters.

### 5.3 Retry Queue for Failed Syncs

**Mechanism:** There is no separate retry queue. Pending records *are* the queue — SyncService scans for `syncStatus != .synced` on every push cycle. Push cycles are triggered by: (a) `enqueuePush()` after a local write (debounced 2 seconds), (b) app foreground event, (c) `NetworkMonitor` transitioning from offline to online.

**Why debounce:** A user rapidly editing (reordering, renaming) shouldn't fire a request per keystroke. 2-second debounce batches rapid edits into one push.

### 5.4 Pull Sync — Full Fetch vs Incremental

**Mechanism:** Pull fetches all trips + activities in one GET /api/trips call. No cursor, no delta sync.

**Why full fetch:** At MVP scale (handful of trips, tens to low hundreds of activities), the full response is <100KB. Incremental sync adds timestamp tracking, cursor management, and tombstone handling — complexity that doesn't pay off until the dataset is much larger. The accepted weakening: a user with hundreds of trips would see slower pull syncs, but that's well outside MVP scope.

### 5.5 Conflict Resolution — Last-Write-Wins

**Mechanism:** On pull merge, if a local `.synced` record has been updated on the server, the server version wins (overwrite local). If a local `.pending*` record conflicts with a server version, compare `lastModified` (local) vs `updated_at` (server) — the newer timestamp wins.

**Accepted weakening:** Two concurrent edits to different fields of the same record → the later one wins entirely, the earlier one's field changes are lost. Acceptable because MVP excludes collaboration (one user per trip).

### 5.6 Location Permission Timing

**Mechanism:** `LocationService` does NOT call `requestWhenInUseAuthorization()` on init. It exposes `requestLocation()` which checks authorization status: if `.notDetermined`, requests permission first, then gets location. This means the system permission dialog appears only when the user takes a location-dependent action (tap Map tab or Nearby tab).

**Why:** NFR-4.1 requires on-demand permission, not at launch. Users who never use map features are never prompted.

### 5.7 isProposed Flag for AI Review

**Mechanism:** `Activity.isProposed` is a local-only Bool (not in the Supabase schema, not synced). Activities created during AI generation start with `isProposed = true`. On accept: set to `false`, set `syncStatus: .pendingCreate`. On reject: delete from SwiftData. SyncService ignores records with `isProposed == true`.

**Why a flag instead of a separate staging area:** Keeps the data model flat. Activities are real SwiftData objects from the moment they're generated, so the review UI uses the same views/ViewModels as the rest of the app. The flag just gates sync.

### 5.8 Sort Order Management

**Mechanism:** `Activity.sortOrder` is an integer. On insert, set to `max(sortOrder) + 1` within the group (day or area). On reorder (drag-and-drop), recalculate all `sortOrder` values in the group as 0, 1, 2, ... based on new positions. The reorder API endpoint accepts the full list of `{id, sortOrder}` for the group.

**Why full-group reorder instead of swap:** Avoids gaps and duplicates in sortOrder, which would accumulate over many individual swaps. The group is small (typically <20 items), so sending all positions is negligible.

---

## 6. Failure/Degradation Paths

| Failure | Behavior | Requirement |
|---------|----------|-------------|
| Network down during normal use | App continues normally reading/writing SwiftData. Sync banner shows "Offline". Push queue accumulates. | NFR-2.1, NFR-2.2, NFR-2.5 |
| Network down during AI generation | Stream fails → show "Generation requires internet. Try again when connected." No partial results saved (all-or-nothing for a generation run). | NFR-2.4 |
| Network down during Places search | Show "Search requires internet." Search input disabled. | NFR-2.4 |
| API returns 401 (token expired) | APIClient intercepts → call `AuthService.refreshTokenIfNeeded()` → retry once. If refresh fails → sign out, show login. | — |
| API returns 5xx | Show transient error banner. Pending sync retries on next cycle. No data loss. | NFR-3.1 |
| Supabase down | Same as 5xx — local SwiftData unaffected, sync retries. | NFR-3.1 |
| App killed mid-write | SwiftData writes are committed before the ViewModel returns. The write is either fully in SwiftData or not at all. | NFR-3.1 |
| App killed mid-sync-push | The record stays `.pending*` in SwiftData. Next app launch push will retry. | NFR-3.1 |
| Location permission denied | Map shows activities without user location dot. Nearby list shows all activities without distance sorting, with message "Enable location for distance sorting." | NFR-4.4 |
| Google Places API quota exceeded | Search returns error → show "Search temporarily unavailable." AI suggestions still work (different service). | — |
| AI generation returns malformed output | Zod schema validation on server rejects the chunk. Stream error sent to client → show "Generation failed, try again." | — |
| SwiftData migration needed (model change) | Lightweight migration via SwiftData's `VersionedSchema`. If migration fails, wipe local cache and re-pull from server (server is the durable store). | — |

---

## 7. Test Mapping

| HLD Verification | Concrete Tests |
|------------------|---------------|
| FR-1 Trip CRUD | `TripCRUDTests.swift`: create trip (verify days generated for structured), edit fields, archive (verify status change), delete (verify cascade to days + activities) |
| FR-2 Structured mode | `StructuredModeTests.swift`: add activity to day (verify sort order), reorder within day, move between days, remove from day (verify unassigned), change dates (verify day regeneration + activity preservation) |
| FR-3 Unstructured mode | `UnstructuredModeTests.swift`: add activity with area, verify grouping, change area, flat list toggle, reorder within group |
| FR-1.6 Mode switch | `ModeSwitchTests.swift`: structured→unstructured (verify day/time cleared, activities preserved), unstructured→structured (verify days created, activities unassigned), enforce INV-2 |
| FR-4 AI generation | `GenerateTests.swift`: mock SSE stream, verify activities created with isProposed=true, accept flow (isProposed cleared, syncStatus set), reject flow (deleted), re-generate warning |
| FR-5 Search | `SearchTests.swift`: mock Places response, verify debounce (rapid typing = single request), add result to trip (verify fields populated) |
| FR-6 Maps | `MapTests.swift`: verify annotations created for activities with coordinates, category icons/colors, day filter, home base pin. `NavigationTests.swift`: verify Apple Maps / Google Maps URL construction |
| FR-6.6 + FR-7.1 Nearby | `NearbyTests.swift`: mock location, verify distance calculation, radius filter, today highlighting |
| FR-7.2 Status tracking | `ActivityStatusTests.swift`: mark visited, mark skipped, verify persistence |
| NFR-1 Performance | `PerformanceTests.swift`: measure trip list load time (<1s), itinerary load time (<1s), with 50 trips / 500 activities dataset |
| NFR-2 Offline | `SyncTests.swift`: write while "offline" (mock APIClient failure), verify SwiftData has data, "reconnect" (mock success), verify push + merge |
| NFR-3 Data integrity | `DataIntegrityTests.swift`: simulate app kill (save context mid-test), verify no partial writes. Conflict test: local pending + server newer → verify correct winner |
| NFR-4 Privacy | `LocationTests.swift`: verify requestLocation not called on init, verify denied state hides location UI, verify no CLLocationManager.startUpdatingLocation (no continuous tracking) |
| API routes | `api/__tests__/trips.test.ts`: CRUD operations with mocked Supabase. `api/__tests__/generate.test.ts`: mock AI SDK, verify SSE output format. `api/__tests__/places.test.ts`: mock Google API, verify proxy |

---

## 8. Open Questions

**OQ-1: Apple Sign In — how to handle email relay addresses?**
Apple's private email relay generates random @privaterelay.appleid.com addresses. Supabase stores whatever email Apple provides. For MVP, this is fine — we don't send transactional email. If we add email features later, we need to either request the real email (user can deny) or use push notifications instead.
*Accepted-for-now:* Store whatever Apple provides, don't depend on the email being reachable.

**OQ-2: Coordinate accuracy for AI-generated activities**
Claude's training data may have imprecise or outdated coordinates. Should we verify AI coordinates against Google Places on accept?
*Accepted-for-now:* Ship without verification. Pins will be in the right neighborhood, which is good enough for navigation (user taps "Directions" for actual routing). Add Places verification as a fast-follow if users report issues.

**OQ-3: SwiftData + background sync threading**
SwiftData's `ModelContext` is not thread-safe. SyncService needs its own `ModelContext` on a background actor, separate from the main-thread context the UI uses.
*Accepted-for-now:* Use `ModelActor` for SyncService's background context. Changes propagate to the main context via SwiftData's built-in coordinator. Test for race conditions in `SyncTests`.

**OQ-4: Preferences schema**
The `preferences` field is typed as `jsonb` / `[String: Any]` — intentionally unstructured. What keys does the AI prompt actually use?
*Accepted-for-now:* Start with `{"interests": [string], "pace": "relaxed"|"moderate"|"packed", "budget": "budget"|"moderate"|"luxury"}`. Extend as prompt engineering reveals what's useful. The flexible schema means no migration needed.
