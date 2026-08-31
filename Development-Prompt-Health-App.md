# Development Prompt — "Health" App
### Conversational, multimodal health companion · Flutter + Flask · Mascot: baby elephant

This document is written to be handed directly to a development team (or an AI coding assistant) as the build brief. Section 0 is a condensed master prompt; the sections after it are the full detail behind every line of it.

---

## 0. Master Build Prompt (condensed — paste-ready)

> Build a cross-platform mobile app called **"Health"** using **Flutter** (frontend) and **Python Flask** (backend, Flask-Smorest + Celery + PostgreSQL). The app is a chat-first, multimodal health & wellness journal: users log their day via text, photo, or short video, and an AI extracts structured data (food, sleep, mood, activity, stress, symptoms) behind a natural conversational reply. The app maintains a persistent medical profile (conditions, allergies, goals, lab history) and cross-checks every log against it in real time (e.g. allergy alerts). The brand mascot is a baby elephant — chosen deliberately because elephants "never forget," mirroring the app's core promise of remembering everything about the user's health so they don't have to. The UI must be warm, calm, and emotionally friendly (this is a health app, not a spreadsheet), built on a distinctive design system (not generic AI-template defaults — see Section 2), with deliberate, purposeful motion (Section 3), and a backend architecture designed from day one so new log types, dashboard modules, and features can be added via configuration, not rearchitecture (Section 6–7).

---

## 1. Brand & Identity

- **Name:** Health
- **Mascot:** A baby elephant. Suggested name: **"Kunjan"** (Malayalam for "little one" — a nice regional touch given the Kerala base; swap freely if you want something else).
- **Why the mascot works, not just decorates:** elephants are famous for long memory — that's the entire value proposition of this app (it remembers your meals, your triggers, your trends, so you don't have to log them twice or forget a pattern). Every place the mascot appears should reinforce *memory, gentleness, and trust* — never generic cuteness for its own sake.
- **Voice & tone:** warm, plain, encouraging — never clinical, never guilt-tripping. Failure/empty states are framed as an invitation ("Nothing logged yet today — tell Kunjan what you had for breakfast"), not an error.

---

## 2. Design System (Tokens)

Avoid the generic "AI app" look (cream + terracotta, near-black + neon accent, broadsheet hairlines). This app's palette is grounded in its own subject: a savanna dawn, and Kerala's warm spice tones — not a template.

**Color**
| Token | Hex | Use |
|---|---|---|
| `bg.base` | `#FBF7F0` | App background — warm ivory, not stark white |
| `ink.primary` | `#3D4451` | Body text — soft elephant-grey, not pure black |
| `accent.primary` | `#E2A63B` | Turmeric gold — primary actions, highlights |
| `accent.secondary` | `#7A9B76` | Sage green — health/positive states, goal progress |
| `accent.tertiary` | `#8C96C6` | Dusty periwinkle — mood/emotional data, dawn-sky motif |
| `alert.trigger` | `#C65D4B` | Allergy/trigger warnings — muted terracotta-red, urgent but not alarming |

**Typography**
- Display face: a warm, slightly rounded serif (e.g. **Fraunces**) for headlines and the mascot's speech — carries personality, echoes the mascot's softness
- Body/UI face: a clean humanist sans (e.g. **Inter** or **IBM Plex Sans**) for chat text and UI labels — legibility first
- Data/utility face: a monospaced or tabular-figure face (e.g. **IBM Plex Mono**) for numbers — calories, BP readings, timestamps — so figures align cleanly in tables and trend cards

**Structural signature — "The Memory Trail":** rather than generic dividers or numbered steps, the Logbook and Trends screens use a soft, hand-drawn-feeling curved path (echoing a wandering elephant trail / a trunk's curve) that threads through each day's entries chronologically. This is the one deliberate, memorable visual signature of the app — used once, with restraint, not repeated as decoration everywhere.

**Iconography:** rounded corners throughout (16–24px radii on cards), soft drop shadows, no hard edges — visually consistent with "gentle giant" mascot personality.

---

## 3. Motion & Interaction Spec

Animation here should always *mean something* — not be decorative for its own sake.

- **AI "thinking" state:** replace the generic three-dot typing indicator with Kunjan (mascot) doing a slow ear-flap / breathing idle loop while the extraction pipeline runs.
- **Log confirmation:** when an entry is extracted from a message/photo/video, its confirmation card slides in with a gentle trunk-swoosh curve (matches the Memory Trail motif), not a flat fade.
- **Recall / query answers:** when the user asks something like "what did I eat yesterday," Kunjan does a brief "remembering" gesture (taps trunk to temple) before the answer renders — reinforces the memory metaphor functionally, not just cutely.
- **Goal milestone reached:** a short celebratory bounce/stomp animation from Kunjan — restrained, one-time, not a full-screen confetti overload.
- **Allergy/trigger alert:** a distinct, slightly firmer animation and haptic (short double-buzz) — must feel different in weight from positive confirmations, since this is a safety signal.
- **Chart transitions (Trends page):** value changes animate as smooth interpolations, not instant redraws, so trend direction is felt, not just read.
- Respect reduced-motion accessibility settings globally — all of the above degrade to simple fades/no-animation when enabled.

---

## 4. Screen-by-Screen UX Spec

1. **Onboarding** — structured multi-step form (not chat): conditions, allergies (chip-based multi-select, not free text), goals (visual goal-picker cards), baseline vitals, scan-report upload with OCR confirmation step. Kunjan narrates each step briefly ("Let's get your basics down").
2. **Chat (Home)** — primary screen. Persistent input bar with three entry modes (text / camera / video) equally weighted, not buried in a menu. Extracted entries render as compact confirmation cards inline in the chat thread, tap to edit.
3. **Today** — auto-generated day summary card: calories, water, activity, mood, sleep — each tile tappable to drill into detail or correct.
4. **Trends & Analytics** — chart-driven: weight, BP, calorie-vs-goal, mood-over-time, and correlation call-outs ("mood dipped on low-sleep days"). Memory Trail visual used here.
5. **Medical Profile** — editable, versioned (shows history of changes, not just current state).
6. **Logbook** — full searchable/filterable history by type/date/media, threaded along the Memory Trail.
7. **Reports** — date-range PDF export, doctor-visit-ready formatting.
8. **Goals** — active goals, progress bars, milestone markers.
9. **Settings & Privacy** — data export/delete, consent management, caregiver access controls.

---

## 5. Frontend Architecture (Flutter) — Built for Scale

- **Feature-first folder structure**, not layer-first — each module (`chat`, `today`, `trends`, `medical_profile`, `logbook`, `reports`, `goals`, `settings`) is self-contained with its own widgets/state/services, so new features are added as new folders, not scattered edits across shared files.
- **State management:** Riverpod (or Bloc) — chosen for testability and clean dependency injection as the app grows.
- **Design system as its own package** (`packages/health_ui`): all tokens, shared components (buttons, cards, the mascot widget, chart wrappers) live here — screens consume it, never redefine styles inline. This is what makes "add a new feature without breaking visual consistency" actually possible.
- **Mascot as a reusable animated widget** with named states (`idle`, `thinking`, `celebrating`, `alerting`, `remembering`) — any new feature can trigger an existing mascot state without new animation work.
- **Offline-friendly chat input:** messages/media queue locally and sync when connectivity returns — critical for a logging app people use throughout the day.

---

## 6. Backend Architecture (Flask) — Built for Scale

- **Domain-separated Flask blueprints/packages:** `accounts`, `medical_profile`, `logging`, `analytics`, `media`, `notifications`, `reports` — each independently testable/deployable in concept, even if deployed as one service initially.
- **`LogEntry` as a flexible, registry-driven model:** `type` is not a hardcoded enum baked into business logic — it's a registered type (food/sleep/mood/activity/stress/symptom today) with a JSON payload column (SQLAlchemy) validated against a per-type schema. **Adding a new log type (e.g. "hydration" or "medication taken") means registering a new type + schema, not migrating core tables or touching existing extraction code.**
- **Extraction pipeline as a pluggable chain:** LLM structured-extraction step → per-type validators → per-type side-effect handlers (e.g. the allergy-check handler only runs for `type=food`). New log types register their own validator/handler without modifying the pipeline itself.
- **API versioning from day one** (`/api/v1/...`) so mobile clients on older versions don't break as features are added.
- **Celery + Redis** for aggregates, reminders, and report generation — kept decoupled from the request/response cycle so heavier analysis never blocks the chat reply.
- **PostgreSQL** with proper indexing on `(user, type, timestamp)` for LogEntry — this is the query pattern that powers both recall ("what did I eat yesterday") and analytics, so it must be fast from day one, not optimized later.
- **Object storage (S3-compatible)** for media, accessed via signed URLs — Flask API never proxies large files.

---

## 7. Extensibility Framework (How Features Get Added Later)

This is the part that makes "scalable with possibility of feature adding" concrete rather than aspirational:

1. **New log type** → register type + JSON schema + optional validator/handler. No core migration.
2. **New dashboard module** (e.g. a future "hydration trend" card) → build as a self-contained widget in the Flutter feature folder + a corresponding aggregate in `analytics` — Today/Trends pages render a **configurable list of dashboard cards**, not a hardcoded layout, so new cards slot in without touching existing screens.
3. **New mascot behavior** → add a new named animation state to the shared mascot widget; any screen can call it.
4. **New alert/trigger type** (beyond allergies) → register a new condition-check function in the extraction pipeline's handler chain.
5. **New integration** (e.g. wearable device data, a clinic-facing B2B portal) → treated as a new data source feeding into the same `LogEntry`/`DailyAggregate` model, not a parallel system.

---

## 8. Non-Functional Requirements

- **Performance:** chat reply (extraction + response) target under ~2–3 seconds perceived latency; mascot "thinking" animation covers this gracefully.
- **Accessibility:** reduced-motion support, minimum tap target sizes, screen-reader labels on all chart data (not just visual).
- **Security & privacy:** encryption at rest/in transit, explicit consent flow, full data export/delete in Settings — required given this is medical data.
- **Scalability:** stateless API layer (horizontal scaling ready), background jobs isolated from request path, indexed time-series queries.

---

## 9. Suggested Build Sequence

1. Design system package + mascot widget states (foundation everything else builds on)
2. Onboarding + Medical Profile (structured data foundation)
3. Chat + text-based extraction pipeline + Today summary
4. Trends/Analytics + Logbook (Memory Trail visual)
5. Photo logging (food + scan reports) + allergy alert flow
6. Reports (PDF export)
7. Video logging + Goals + Settings/Privacy
8. Caregiver mode, proactive weekly check-ins, B2B/clinic layer (post-MVP)
