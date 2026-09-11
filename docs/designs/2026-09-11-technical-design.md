# Redeye — Technical Design

**Last updated:** 2026-09-11
**LLD:** [`2026-09-11-technical-design-lld.md`](2026-09-11-technical-design-lld.md)

## Problem

We have a product spec (`docs/designs/product-spec.md`) defining a travel planner app with 8 functional requirement groups (FR-1 through FR-8) and 6 non-functional groups (NFR-1 through NFR-6). This document maps those requirements to concrete technical implementation — data model, API surface, app architecture, sync strategy — so that build work can proceed against a clear contract.

## Grounding

- **Product spec:** `docs/designs/product-spec.md` — 33 functional requirements, 17 non-functional requirements
- **Decided stack:** Swift/SwiftUI iOS app, Next.js API routes on Vercel, Supabase Postgres + Auth, Claude via Vercel AI SDK (`docs/decisions.md`)
- **No existing code.** This is the first technical design for a greenfield project.

## Goals

- Cover every FR and NFR in the product spec with a concrete implementation approach
- Define the data model, API surface, and app architecture clearly enough to build from
- Keep the design simple for the stated scale (personal + friends)

## Non-goals

- Multi-tenant architecture or horizontal scaling
- Anything listed in the product spec's "Out of Scope for MVP"
- Pixel-level UI design (separate concern)

---

## 1. Repository Structure

```
redeye/
├── Redeye/                    # iOS app (Xcode project)
│   ├── App/                   # App entry point, configuration
│   ├── Models/                # SwiftData models
│   ├── Views/                 # SwiftUI views, organized by feature
│   │   ├── Trips/             # Trip list, create, edit
│   │   ├── Itinerary/         # Structured mode day-by-day view
│   │   ├── ActivityList/      # Unstructured mode categorized list
│   │   ├── Map/               # Map view, pins, nearby
│   │   ├── Search/            # Activity search
│   │   └── Generate/          # AI generation UI
│   ├── ViewModels/            # MVVM view models
│   ├── Services/              # API client, sync, location, auth
│   ├── Utilities/             # Extensions, helpers
│   └── Resources/             # Assets, colors, localization
├── api/                       # Vercel API (Next.js)
│   ├── app/
│   │   └── api/
│   │       ├── trips/         # Trip CRUD
│   │       ├── activities/    # Activity CRUD
│   │       ├── generate/      # AI itinerary generation
│   │       └── places/        # Google Places proxy
│   ├── lib/
│   │   ├── supabase.ts        # Supabase client + auth helpers
│   │   ├── ai.ts              # AI SDK configuration
│   │   └── places.ts          # Google Places client
│   └── package.json
├── supabase/
│   └── migrations/            # SQL migration files
└── docs/
```

## 2. Data Model

### 2.1 Supabase Schema (server, source of truth for sync)

All tables use RLS policies scoped to `auth.uid() = user_id`.

**`trips`**

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK, default gen_random_uuid() |
| user_id | uuid | FK → auth.users, set by RLS |
| title | text | not null |
| destination | text | not null |
| start_date | date | not null |
| end_date | date | not null |
| mode | text | 'structured' or 'unstructured', not null |
| home_base_name | text | nullable |
| home_base_address | text | nullable |
| home_base_lat | float8 | nullable |
| home_base_lng | float8 | nullable |
| preferences | jsonb | nullable, e.g. {"interests": ["food", "art"], "pace": "relaxed"} |
| status | text | 'active' or 'archived', default 'active' |
| updated_at | timestamptz | auto-updated via trigger |
| created_at | timestamptz | default now() |

Covers: FR-1.1 (create), FR-1.2 (list, filter by status), FR-1.3 (edit), FR-1.4 (archive via status), FR-1.5 (delete), FR-1.6 (mode switch).

**`trip_days`** — structured mode only, auto-generated from trip date range

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK |
| trip_id | uuid | FK → trips, cascade delete |
| date | date | not null |
| day_number | int | 1-indexed, not null |
| notes | text | nullable |

Covers: FR-2.1 (day-by-day breakdown), FR-2.7 (regenerated when dates change).

**`activities`**

| Column | Type | Notes |
|--------|------|-------|
| id | uuid | PK |
| trip_id | uuid | FK → trips, cascade delete |
| trip_day_id | uuid | FK → trip_days, nullable, cascade on day delete sets null |
| name | text | not null |
| description | text | nullable |
| category | text | not null: restaurant, attraction, shopping, museum, nightlife, other |
| area | text | nullable, neighborhood label for unstructured grouping |
| latitude | float8 | nullable (can be added without coordinates) |
| longitude | float8 | nullable |
| address | text | nullable |
| start_time | time | nullable, structured mode only |
| end_time | time | nullable, structured mode only |
| duration_min | int | nullable, estimated |
| sort_order | int | not null, default 0 |
| source | text | 'manual', 'ai_generated', 'places_api' |
| place_id | text | nullable, Google Places ID for future lookups |
| status | text | 'planned', 'visited', 'skipped', default 'planned' |
| notes | text | nullable |
| created_at | timestamptz | default now() |

Covers: FR-2.2–2.6 (structured operations via trip_day_id + sort_order + start_time), FR-3.1–3.5 (unstructured grouping via area + category + sort_order), FR-5.3 (add from search), FR-7.2 (mark visited/skipped), FR-7.3 (quick-add).

### 2.2 SwiftData Models (local, offline cache)

Mirror the Supabase schema with these additions per model:

```
syncStatus: SyncStatus     // .synced, .pendingCreate, .pendingUpdate, .pendingDelete
lastModified: Date         // local modification timestamp, used for conflict resolution
serverId: UUID?            // nullable until first sync confirms server-side ID
```

This covers NFR-2.1 (offline viewing), NFR-2.2 (offline editing), NFR-3.1 (changes survive app close).

### 2.3 Requirement Traceability — Data Model

| Requirement | How the data model supports it |
|-------------|-------------------------------|
| FR-1.6 mode switch | Set trip.mode, nullify trip_day_id/start_time/end_time on activities |
| FR-2.7 date change | Delete trip_days outside new range (activities cascade to null trip_day_id), insert new days |
| FR-3.1 area grouping | Query activities WHERE trip_day_id IS NULL GROUP BY area |
| FR-3.6 flat list | Query activities WHERE trip_day_id IS NULL ORDER BY sort_order |
| FR-6.8 home base pin | Read home_base_lat/lng from trip |
| FR-7.1 today's activities | Query trip_days WHERE date = today, join activities |

---

## 3. API Surface

All routes require a valid Supabase JWT in the `Authorization` header. The API is thin — it validates, delegates to Supabase or external services, and returns.

### 3.1 Trip CRUD

| Method | Route | Body | Notes |
|--------|-------|------|-------|
| GET | /api/trips | — | List user's trips (with optional ?status=active/archived) |
| POST | /api/trips | {title, destination, start_date, end_date, mode, ...} | Creates trip + trip_days if structured |
| GET | /api/trips/[id] | — | Trip with all activities and days |
| PATCH | /api/trips/[id] | partial fields | Updates trip; if dates change, regenerates trip_days |
| DELETE | /api/trips/[id] | — | Cascades to days and activities |

Covers: FR-1.1–1.6, NFR-1.1 (sub-1s, single query with RLS).

### 3.2 Activity CRUD

| Method | Route | Body | Notes |
|--------|-------|------|-------|
| POST | /api/trips/[id]/activities | {name, category, ...} | Add activity |
| PATCH | /api/activities/[id] | partial fields | Update activity (including day assignment, reorder) |
| DELETE | /api/activities/[id] | — | Remove activity |
| PATCH | /api/trips/[id]/activities/reorder | [{id, sort_order, trip_day_id?}] | Batch reorder |

Covers: FR-2.3–2.6, FR-3.3–3.5, FR-7.2 (PATCH status), FR-7.3 (POST with minimal fields).

### 3.3 AI Generation

| Method | Route | Body | Notes |
|--------|-------|------|-------|
| POST | /api/trips/[id]/generate | — | Streams AI-generated activities |

Implementation:
- Reads trip details (destination, dates, preferences, mode, existing manual activities)
- Calls Claude via Vercel AI SDK with `streamObject()` using a Zod schema
- **Structured mode schema:** array of `{day_number, activities: [{name, category, area, start_time, end_time, duration_min, latitude, longitude, address, description}]}`
- **Unstructured mode schema:** array of `{area, activities: [{name, category, description, latitude, longitude, address, duration_min}]}`
- Response streams as Server-Sent Events; the app appends activities as they arrive
- Generated activities are inserted with `source: 'ai_generated'`

Covers: FR-4.1–4.8, NFR-1.3 (streaming — first results in seconds).

### 3.4 Places Proxy

| Method | Route | Body/Params | Notes |
|--------|-------|-------------|-------|
| GET | /api/places/search | ?query=...&location=lat,lng | Text search, returns simplified results |
| GET | /api/places/[placeId] | — | Place details for a specific place |

Proxied server-side to keep the Google API key out of the client.

Covers: FR-5.1–5.4, NFR-1.4 (sub-1s, Google's API is fast).

---

## 4. iOS App Architecture

### 4.1 Pattern: MVVM + Services

```
View (SwiftUI)
  ↕ binds to
ViewModel (@Observable)
  ↕ calls
Services (APIClient, SyncService, LocationService, AuthService)
  ↕ reads/writes
SwiftData (ModelContext)
```

- **Views** are declarative, no business logic.
- **ViewModels** are `@Observable` classes. Each major screen gets one.
- **Services** are injected via SwiftUI's environment. They're singletons managed by the app's root.

### 4.2 Key Services

**APIClient** — Thin HTTP wrapper around the Vercel API. Handles JWT attachment, request/response encoding, SSE streaming for AI generation. No business logic.

**SyncService** — Manages the offline-first data flow:
1. All writes go to SwiftData first (optimistic, instant)
2. SyncService observes pending changes and pushes to the API in the background
3. On failure, changes stay queued with `syncStatus: .pendingXxx`
4. On app foreground or connectivity change, retries queued changes
5. Conflict resolution: last-write-wins using `updated_at` timestamp

Covers: NFR-2.1–2.2, NFR-3.1–3.2.

**LocationService** — Wraps CLLocationManager:
- Requests `whenInUse` permission only when the user taps a location-dependent feature
- Gets a single location fix (not continuous tracking)
- Exposes current location as an `@Observable` property
- Handles the denied/restricted case by publishing a `.denied` state the UI reacts to

Covers: NFR-4.1–4.4.

**AuthService** — Wraps Supabase Auth:
- Email + password sign up/in
- Apple Sign In via `ASAuthorizationController`
- Stores JWT in Keychain
- Refreshes token on expiry
- Publishes auth state for the UI to react to

### 4.3 Screen Map

| Screen | ViewModel | Product Requirements |
|--------|-----------|---------------------|
| Trip List | TripListViewModel | FR-1.2, FR-1.4, FR-7.1 |
| Create Trip | CreateTripViewModel | FR-1.1 |
| Trip Detail (structured) | StructuredItineraryViewModel | FR-2.1–2.7, FR-4.5–4.7 |
| Trip Detail (unstructured) | UnstructuredListViewModel | FR-3.1–3.6, FR-4.5–4.7 |
| Activity Detail | ActivityDetailViewModel | FR-6.3, FR-7.2 |
| Add/Edit Activity | EditActivityViewModel | FR-2.3, FR-3.3, FR-7.3 |
| AI Generation | GenerateViewModel | FR-4.1–4.4 |
| Map | MapViewModel | FR-6.1–6.8 |
| Nearby | NearbyViewModel | FR-6.6, FR-7.1 |
| Search | SearchViewModel | FR-5.1–5.4 |
| Settings/Auth | AuthViewModel | — |

### 4.4 Navigation

Tab-based root:
1. **Trips** — Trip list → Trip detail → Activity detail / Add / Edit
2. **Map** — Map view (scoped to selected trip)
3. **Nearby** — Distance-sorted activity list (scoped to selected trip, requires location)

Within Trip Detail, structured and unstructured are two views switched by `trip.mode`. The AI generation flow is a sheet presented over the trip detail.

---

## 5. Sync Strategy

### 5.1 Data Flow

```
User action → SwiftData write (instant) → UI updates
                                        → SyncService queues push
                                        → API call (background)
                                        → On success: mark .synced
                                        → On failure: stay .pendingXxx, retry later
```

### 5.2 Pull Sync

On app launch and on each foreground event:
1. Fetch all trips + activities for the user from the API (single request: GET /api/trips returns everything)
2. Merge into SwiftData: server wins for `.synced` records, local wins for `.pending*` records
3. After merge, push any remaining pending changes

For the scale of this app (handful of trips, dozens of activities), fetching everything is simpler and faster than incremental sync with cursors.

### 5.3 Conflict Resolution

Last-write-wins by `updated_at`. The server's `updated_at` trigger ensures a consistent timestamp. When a local pending change conflicts with a newer server version:
- If the local record is `.pendingUpdate`, compare `lastModified` vs server `updated_at`
- The newer timestamp wins
- This is sufficient for single-user-per-trip (MVP scope excludes collaboration)

### 5.4 Requirement Traceability — Sync

| Requirement | Implementation |
|-------------|---------------|
| NFR-2.1 offline viewing | SwiftData is the read source; API is never required for display |
| NFR-2.2 offline editing | Writes go to SwiftData first; sync is background |
| NFR-2.5 offline indicator | SyncService publishes `isOnline` state; a small banner shows when false |
| NFR-3.1 no data loss on close | SwiftData persists to SQLite; writes are committed before UI returns |
| NFR-3.2 conflict handling | last-write-wins with timestamp comparison |

---

## 6. Maps Implementation

Using MapKit (native, no third-party dependency):

- **Map view** uses `Map` SwiftUI component with `Annotation` for each activity
- **Category pins** use SF Symbols with category-specific colors (e.g. fork.knife for restaurant, building.columns for museum)
- **Home base** uses a distinct house icon annotation
- **Current location** shown via MapKit's built-in `mapControls { MapUserLocationButton() }` — only appears after location permission granted
- **Day filter** (FR-6.7): ViewModel filters the annotation array by selected trip_day_id
- **Nearby sorting** (FR-6.6): Calculate distance from CLLocation to each activity's coordinates, sort, filter by radius. Done on-device, no API call.
- **Open in Maps** (FR-6.4): `MKMapItem(placemark:).openInMaps()` for Apple Maps; URL scheme `comgooglemaps://` for Google Maps with fallback to Apple Maps if not installed

Covers: FR-6.1–6.8, NFR-1.5 (map render sub-2s — MapKit is native, no bridge).

---

## 7. AI Generation Implementation

### 7.1 Prompt Design

The API route constructs a prompt from trip data:

```
Destination: {trip.destination}
Dates: {trip.start_date} to {trip.end_date} ({n} days)
Preferences: {trip.preferences}
Mode: {trip.mode}
Home base: {trip.home_base_name} at {trip.home_base_address}
Existing activities (manual): [list of already-added activities to avoid duplicating]
```

System prompt instructs Claude to:
- Generate activities appropriate for the destination
- Mix popular highlights with lesser-known local spots (FR-4.8)
- Respect the stated preferences and pace
- Include realistic coordinates and addresses
- For structured mode: distribute across days with sensible timing
- For unstructured mode: group by real neighborhoods

### 7.2 Streaming Flow

1. iOS app calls POST /api/trips/[id]/generate
2. API uses `streamObject()` from AI SDK — structured output with Zod schema validation
3. Response is SSE stream; each chunk is a partial JSON object
4. iOS app uses `URLSession` with `AsyncBytes` to read the stream
5. As each complete activity is parsed, it's inserted into SwiftData with `source: .aiGenerated`
6. UI updates reactively as SwiftData changes

### 7.3 Accept/Reject Flow (FR-4.5)

AI-generated activities are inserted with a transient `isProposed: true` flag (local-only, not synced). The review screen shows them with accept/reject controls. Accepted activities clear the flag and sync. Rejected activities are deleted locally. This avoids syncing throwaway suggestions.

---

## 8. Auth Flow

1. App launches → check Keychain for stored Supabase session
2. If valid session: proceed to trip list, refresh token in background
3. If no session or expired: show auth screen
4. Auth screen offers: Email sign up/in, Sign in with Apple
5. On success: store session in Keychain, proceed to trip list

Sign in with Apple uses `ASAuthorizationController` → sends the identity token to Supabase's `signInWithIdToken()`. No custom backend auth logic needed.

---

## Risks

**Coordinate accuracy in AI generation.** Claude's training data includes place coordinates, but they may be imprecise or outdated. Mitigation: for accepted AI activities, optionally run a Places API lookup to verify/correct coordinates. Not blocking for MVP — approximate coordinates still place pins in the right neighborhood.

**Offline sync edge cases.** The last-write-wins strategy can lose data if the same activity is edited differently on two devices before sync. Mitigation: acceptable for MVP (single user, personal use). If collaboration is added later, this needs revisiting with field-level merging.

**Google Places API cost.** Free tier (~1,000 Enterprise calls/month) could be exceeded if search is heavily used. Mitigation: AI suggestions are the primary discovery path; Places search is secondary. Add client-side debouncing and result caching.

**SwiftData maturity.** SwiftData is newer than CoreData and has had rough edges in early releases. Mitigation: iOS 17+ gives us the post-1.0 version; keep the model simple (flat relationships, no deep nesting); fall back to CoreData only if a showstopper bug is hit.

---

## Rollout — Build Order

**Phase 1: Foundation**
- Xcode project setup (SwiftUI app target, iOS 17+)
- SwiftData models
- Supabase project + schema migration
- Auth flow (email + Apple Sign In)
- API project setup (Next.js on Vercel)
- Basic trip CRUD (API + iOS)

**Phase 2: Core Features**
- Structured mode view (day-by-day with activity management)
- Unstructured mode view (area/category grouping)
- Activity add/edit/delete
- Mode switching (FR-1.6)

**Phase 3: AI & Search**
- AI generation endpoint + streaming
- Generation UI with accept/reject flow
- Google Places proxy (if pursuing, otherwise defer)
- Activity search UI

**Phase 4: Maps & Location**
- Map view with activity pins
- Category-colored annotations
- Current location + nearby sorting
- Open in Apple Maps / Google Maps

**Phase 5: Offline & Polish**
- SyncService (background push, pull on foreground, retry queue)
- Offline indicator
- Drag-to-reorder for activities
- Dark mode polish
- Dynamic Type support
- TestFlight build

---

## Verification

| Requirement group | How we verify |
|-------------------|--------------|
| FR-1 Trip CRUD | Create, edit, archive, delete a trip in the simulator. Confirm data persists across app restarts. |
| FR-2 Structured mode | Create a multi-day trip, add/reorder/move activities between days, change dates and confirm day regeneration. |
| FR-3 Unstructured mode | Add activities with area labels, confirm grouping, switch to flat list view. |
| FR-4 AI generation | Generate for both modes, confirm streaming works, accept/reject individual activities. |
| FR-5 Search | Search for real places, add results to a trip. |
| FR-6 Maps | View pins on map, tap for detail, open in Apple Maps. Confirm category coloring and day filter. |
| FR-7 On-trip | Set device date to within a trip's range, confirm today's activities surface. Mark visited/skipped. |
| NFR-1 Performance | Time each operation in Instruments. Trip list and itinerary load should be sub-1s from SwiftData. |
| NFR-2 Offline | Enable airplane mode, confirm trips are viewable and editable. Disable, confirm sync. |
| NFR-3 Data integrity | Kill the app mid-edit, relaunch, confirm no data loss. |
| NFR-4 Privacy | Deny location permission, confirm app works. Grant, confirm location only fires on map/nearby. |
| NFR-5 Distribution | Archive build, upload to TestFlight, install on a real iPhone. |
| NFR-6 Usability | Test in dark mode, test with largest Dynamic Type, test one-handed reachability. |
