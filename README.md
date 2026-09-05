# VitaChat

A chat-first, multimodal health & wellness journal. Users log their day via text (photo/video coming in a later
phase), and Mo — the app's mascot and AI — extracts structured data (food, sleep, mood, activity, stress,
symptoms) behind a warm conversational reply, cross-checked against a persistent medical profile in real time
(e.g. allergy alerts).

See [`PRD-health-wellness-chat-app.md`](PRD-health-wellness-chat-app.md) for product scope and
[`Development-Prompt-Health-App.md`](Development-Prompt-Health-App.md) for the design/architecture brief this build
follows. Visual design (palette, type, screen flows) follows the "Warm Paper" VitaChat prototype
(`Baby elephant mobile app design.zip` — a Claude Design canvas export).

**Stack:** Flutter (frontend) + Python Flask (backend: Flask-Smorest, SQLAlchemy, Celery, PostgreSQL, Redis,
S3-compatible object storage via MinIO, Stripe for billing).

## What's built (this pass)

Foundation + Phase 1 MVP, plus caregiver mode and subscriptions: onboarding (basics, conditions, allergies,
medications, baseline vitals, one manual lab value, goals, privacy), medical profile (versioned), text-based
chat logging with pluggable LLM extraction (Anthropic / OpenAI / Gemini, or a zero-key mock extractor),
real-time allergy alerts, Today summary, Trends with a lightweight sleep/mood correlation call-out, Logbook,
Goals, **caregiver mode** (invite by email, permission-scoped read access to logs/trends/profile), and
**subscriptions** (Stripe Checkout + billing portal, or a zero-key "mock" mode that upgrades instantly for
local dev/demo — same pluggable-provider pattern as the LLM extractor). The free tier caps Logbook history at
30 days (`FREE_TIER_LOGBOOK_DAYS`); Premium removes the cap.

**Deferred to later phases** (per the PRD roadmap): photo/video logging, OCR lab-report scanning (the
onboarding lab step and Medical Profile still take one value by hand), PDF report export (the Reports screen
explains this and links to Premium), proactive weekly check-ins, B2B/clinic layer.

## Repo layout

```
backend/            Flask API (domain-separated packages: accounts, medical_profile, logging, analytics,
                     goals, media, notifications, reports, caregiver, billing)
frontend/            Flutter app
  packages/health_ui/  Shared design system package (tokens, MoMascot widget, Memory Trail component)
docker-compose.yml    Postgres + Redis + MinIO + backend API + Celery worker
.env.example          Copy to .env and fill in before running docker compose
```

## Backend

### Run with Docker Compose (recommended)

```bash
cp .env.example .env   # already done if you're reading this after setup
docker compose up --build
```

This starts Postgres, Redis, MinIO (with the `health-media` bucket auto-created), the Flask API, and a Celery
worker. The API container runs `flask db upgrade` on startup via `entrypoint.sh`.

The API is mapped to host port **5001** (`ports: "5001:5000"` in `docker-compose.yml`) — port 5000 is
commonly taken by macOS's AirPlay Receiver. If that's not an issue on your machine, feel free to change it
back to `5000:5000` (and update the frontend's default `API_BASE_URL` — see below).

### Run locally (without Docker)

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

export FLASK_APP=wsgi.py
export DATABASE_URL=sqlite:///dev.db   # or point at a local Postgres
flask db upgrade

flask --app wsgi run   # or: python wsgi.py
```

Run the test suite:

```bash
source .venv/bin/activate && pytest -q
```

### LLM provider

Set `LLM_PROVIDER` to `anthropic`, `openai`, or `gemini` and the matching API key
(`ANTHROPIC_API_KEY` / `OPENAI_API_KEY` / `GOOGLE_API_KEY`) in `.env`. With no key set (or
`LLM_PROVIDER=mock`), the app runs a deterministic keyword-based extractor — no live LLM calls, fully
offline-testable.

### Billing provider

Set `STRIPE_SECRET_KEY` (+ `STRIPE_PUBLISHABLE_KEY`, `STRIPE_PRICE_ID`, `STRIPE_WEBHOOK_SECRET`) to bill
against real Stripe. With no key set, billing runs in **mock mode**: `POST /api/v1/billing/checkout-session`
upgrades the account to Premium immediately (no network calls, no Stripe account needed), and
`POST /api/v1/billing/portal-session` downgrades it back to free. See `app/billing/service.py`.

### Caregiver mode

`app/caregiver` — invite-by-email links from an owner account to a caregiver account, each with three
independent permission flags (view logs, view trends/reports, edit profile). An invitee doesn't need an
account yet; the link resolves once they sign up with the invited email and accept. Cross-account reads go
through one gated endpoint, `GET /api/v1/caregiver/access/<owner_user_id>/summary` — it doesn't yet proxy
every existing endpoint (today/trends/logbook) for an "acting as caregiver" view; that's a natural follow-up.

### Adding a new log type

Register it in [`app/logging/types.py`](backend/app/logging/types.py) — a name, a field schema, and
optional handlers. No migration, no changes to the extraction pipeline or existing types
(see `app/logging/registry.py`).

## Frontend

```bash
cd frontend
flutter pub get
flutter run
```

By default the app points at the deployed production API — the one a real device (or a plain `flutter run`
with no flags) actually needs, since "localhost" from a physical phone means the phone itself, not this
machine. See `lib/core/api/api_config.dart`. To point a local run at the Docker Compose stack instead
(host port 5001) or a local `flask run` (see above), override explicitly:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:5001/api/v1
# Android emulator (aliases the host machine rather than the emulator itself):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5001/api/v1
```

Run tests/analysis:

```bash
flutter analyze
flutter test
cd packages/health_ui && flutter test   # design system package
```

> The design system uses `google_fonts` (Newsreader + DM Sans), which fetches font files over the network on
> first use per device (falling back to a system font if offline). No bundled font assets are included.

## Design system (`packages/health_ui`)

Tokens (color/type/spacing — "Warm Paper": cream surfaces, charcoal ink, terracotta accent), the `MoMascot`
widget (named states: `idle`, `thinking`, `celebrating`, `alerting`, `remembering`), `LogConfirmationCard`,
`AlertBanner`, and the `MemoryTrailTimeline` — the app's one deliberate structural signature, used on Trends
and Logbook. See [`Development-Prompt-Health-App.md`](Development-Prompt-Health-App.md) §2–3 for the
rationale behind each, and the design source zip for the full VitaChat prototype these were re-themed to.
