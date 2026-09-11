# Redeye

AI-powered travel planner for iOS — plan structured or unstructured trips with AI-generated itineraries, maps, and offline support.

## Stack
- Language/runtime: Swift 5.9+ / iOS 17+, TypeScript / Node.js 24
- Framework: SwiftUI (iOS app), Next.js (Vercel API routes)
- Package manager: Swift Package Manager (iOS), npm (API)
- Database: Supabase (Postgres + Auth)
- AI: Vercel AI SDK + Claude (itinerary generation)

## Commands
- Install: `cd api && npm install`
- Dev/run: Open `Redeye/Redeye.xcodeproj` in Xcode; `cd api && npm run dev`
- Test: Xcode test runner (Cmd+U); `cd api && npm test`
- Lint/typecheck: SwiftLint (iOS); `cd api && npx tsc --noEmit`
- Build: Xcode archive (iOS); `cd api && npm run build`

## Conventions
Cross-project coding principles (KISS, no god files, surface conflicts, etc.) live in `~/.claude/CLAUDE.md` — don't restate them here. Project coding conventions live in `CLEANCODE.md`; keep detailed code-quality rules there so this file stays focused on project context.

This section is only for what's specific to *this* repo:
- Code style: SwiftUI views use MVVM. API routes are thin handlers delegating to service modules.
- Testing approach: XCTest for iOS, vitest for API routes.
- Commit message format: conventional commits (`feat:`, `fix:`, `chore:`, etc.)

## Architecture
(Placeholder — fill in once the system has real shape. High-level modules/services and how they talk to each other. Update this when the shape changes, not on every commit.)

## Context files
Keep these current — they're what gives any session, or either CLI tool, continuity without re-deriving history from scratch.

- **AGENTS.md** (this file) — stack, commands, repo-specific conventions, architecture. Update only when one of those actually changes; it should stay stable day to day.
- **CLAUDE.md** — pointer to this file only. Don't duplicate content into it.
- **CLEANCODE.md** — coding conventions agents should follow while editing code. Update when recurring code-quality preferences or project-specific patterns become clear.
- **docs/journal.md** — append-only session log. Never edit past entries; if something turns out wrong, say so in a new one.
- **docs/decisions.md** — append-only log of significant technical decisions (dependency choices, schema changes, rejected approaches), one entry per decision. Never edit past entries — a reversed decision gets a new entry that supersedes the old one.
- **docs/designs/** — design documents (specs, mockups, research write-ups). One file per document; save the working version here rather than leaving it only in chat or artifact history.
- **TODO.md** — current and near-term work. The only file in this list meant to be edited freely rather than appended-only. Tasks carry an id, a manual/agent tag, and optional `depends-on` links so parallel-safe work can be computed rather than tracked by hand — see the `plan-tasks` skill.

**Before starting nontrivial work:** read this file, read CLEANCODE.md, skim the last few journal entries, check TODO.md.
**After finishing a session:** append a journal entry (what changed, why, what's next), update TODO.md, and append a decision entry if a decision worth remembering was made.
