# Journal

Append-only. One entry per work session. Newest at the bottom. Don't edit past entries — if something's wrong now, say so in a new entry.

## 2026-09-11 — project created

Initialized project scaffold (AGENTS.md, CLEANCODE.md, decisions log, TODO). Nothing built yet.

Decided on stack: SwiftUI (iOS), Next.js API routes on Vercel (backend), Supabase (Postgres + Auth), Claude via AI SDK (itinerary generation). Architecture doc published as an artifact covering data model (trips, trip_days, activities), two-mode design (structured vs unstructured), offline strategy (SwiftData as local source of truth with background sync), and AI generation flow.

Wrote product spec (`docs/designs/product-spec.md`) — 33 functional requirements across 8 groups (trip management, structured mode, unstructured mode, AI generation, search, maps, on-trip experience, route planning stretch goal) and 17 non-functional requirements across 6 groups (performance, offline, data integrity, privacy, distribution, usability).

Wrote technical design doc (`docs/designs/2026-09-11-technical-design.md`) mapping every product requirement to implementation. Key decisions recorded: offline-first with SwiftData + background sync (last-write-wins), MVVM architecture with @Observable ViewModels + injected Services. Defined full Supabase schema, API surface (4 route groups), iOS screen map (11 screens), sync strategy, and 5-phase build order. Codex review skipped per user request.
