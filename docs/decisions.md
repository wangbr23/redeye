# Decisions

Append-only log of architecture decisions. One entry per decision, newest at the bottom. Don't edit past entries — a reversed decision gets a new entry that supersedes the old one, rather than an edit.

## 2026-09-11 — Record architecture decisions

**Status:** Accepted

**Context:** We need a lightweight way to record why significant technical decisions were made, so future work — by any contributor, human or AI, in any tool — doesn't rediscover or accidentally reverse them without knowing the original reasoning.

**Decision:** We will keep architecture decisions in `docs/decisions.md`, one entry per decision, appended chronologically. Entries are append-only — a changed decision gets a new entry that supersedes the old one, rather than an edit.

**Consequences:** Decisions and their reasoning survive context resets, tool switches, and contributor turnover.

## 2026-09-11 — Swift/SwiftUI over React Native

**Status:** Accepted

**Context:** Need a downloadable iOS app for a small group (personal + friends). React Native/Expo would be faster to scaffold but Swift gives native MapKit, SwiftData, and CoreLocation without bridge layers.

**Decision:** Build the iOS app in Swift/SwiftUI. Use SwiftData for offline persistence, MapKit for maps, CoreLocation for on-demand location.

**Consequences:** iOS-only (no Android without a rewrite). Slower initial development but better native integration for maps, offline, and location — all core features. Iteration loop is simulator-based with periodic TestFlight builds for on-device testing.

## 2026-09-11 — Vercel + Supabase backend

**Status:** Accepted

**Context:** Need a backend for auth, trip persistence, AI generation, and Places API proxying. Scale is small (personal + friends). Options considered: Firebase, Vercel+Turso, Vercel+Supabase.

**Decision:** Vercel API routes (Next.js) for the API layer, Supabase for Postgres DB and auth. AI generation via Vercel AI SDK with Claude.

**Consequences:** Generous free tiers for this scale. Supabase Auth gives email + Apple Sign In with Row Level Security. Vercel API layer keeps API keys server-side and provides a place for business logic. Two services to manage instead of one (vs Firebase) but avoids vendor lock-in.

## 2026-09-11 — Offline-first with SwiftData + background sync

**Status:** Accepted

**Context:** Product spec requires offline viewing and editing (NFR-2.1, NFR-2.2) and no data loss on app close or network failure (NFR-3.1). Options: server-first with local cache, or local-first with background sync.

**Decision:** SwiftData is the read/write source of truth on-device. All user actions write to SwiftData first (optimistic, instant). A SyncService pushes changes to Supabase in the background. Conflict resolution is last-write-wins by timestamp. Pull sync fetches everything on foreground (acceptable at MVP scale).

**Consequences:** App is always fast and responsive regardless of connectivity. Sync logic is custom (no off-the-shelf solution for SwiftData ↔ Supabase). Last-write-wins is lossy under concurrent edits but acceptable since MVP excludes collaboration.

## 2026-09-11 — MVVM architecture for iOS app

**Status:** Accepted

**Context:** Need a clear separation pattern for SwiftUI views, business logic, and data access. Options: MV (pure SwiftUI with inline logic), MVVM, TCA.

**Decision:** MVVM with @Observable ViewModels and injected Services. Views are declarative with no business logic. Services (APIClient, SyncService, LocationService, AuthService) are singletons in the SwiftUI environment.

**Consequences:** Familiar pattern, testable ViewModels, clean separation. More boilerplate than MV but scales better as the app grows. Avoids TCA's complexity which is overkill for this scale.
