# TODO

Current and near-term work. Mutable — edit freely, unlike the journal or decisions log.

Task format: `- [ ] \`T<n>\` <description> — <manual|agent>[, depends-on: T<a>, T<b>]`. IDs are sequential and never reused. A task is safe to hand to a parallel agent once every id in its `depends-on` is checked off. See the `plan-tasks` skill.

- [ ] `T1` Set up Xcode project with SwiftUI app target — manual
- [ ] `T2` Set up Vercel API (Next.js) in `api/` directory — agent
- [ ] `T3` Set up Supabase project and create schema (trips, trip_days, activities) — manual
- [ ] `T4` Build trip CRUD views (create, list, edit, archive, delete) — agent, depends-on: T1, T3
- [ ] `T5` Build structured mode day-by-day itinerary view — agent, depends-on: T4
- [ ] `T6` Build unstructured mode categorized list view — agent, depends-on: T4
- [ ] `T7` AI itinerary generation endpoint and UI — agent, depends-on: T2, T4
- [ ] `T8` Map view with activity pins and current location — agent, depends-on: T4
- [ ] `T9` Offline support with SwiftData sync — agent, depends-on: T4
- [ ] `T10` Google Places API integration (stretch) — agent, depends-on: T2
