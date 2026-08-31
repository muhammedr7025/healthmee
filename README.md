# Health

A chat-first, multimodal health & wellness journal. Users log their day via text (photo/video coming in a later
phase), and an AI extracts structured data (food, sleep, mood, activity, stress, symptoms) behind a warm
conversational reply, cross-checked against a persistent medical profile in real time (e.g. allergy alerts).

See [`PRD-health-wellness-chat-app.md`](PRD-health-wellness-chat-app.md) for product scope and
[`Development-Prompt-Health-App.md`](Development-Prompt-Health-App.md) for the design/architecture brief this build
follows.

**Stack:** Flutter (frontend) + Python Flask (backend: Flask-Smorest, SQLAlchemy, Celery, PostgreSQL, Redis,
S3-compatible object storage via MinIO).

## What's built (this pass)

Foundation + Phase 1 MVP: onboarding, medical profile (versioned), text-based chat logging with pluggable
LLM extraction (Anthropic / OpenAI / Gemini, or a zero-key mock extractor), real-time allergy alerts, Today
summary, Trends with a lightweight sleep/mood correlation call-out, Logbook, and Goals.

**Deferred to later phases** (per the PRD roadmap): photo/video logging, OCR lab-report scanning, PDF report
export, caregiver mode, proactive weekly check-ins, B2B/clinic layer. The chat input bar and Settings screen
already have placeholders for these so they can be wired in without restructuring.

## Repo layout

```
backend/            Flask API (domain-separated packages: accounts, medical_profile, logging, analytics,
                     goals, media, notifications, reports)
frontend/            Flutter app
  packages/health_ui/  Shared design system package (tokens, mascot widget, Memory Trail component)
docker-compose.yml    Postgres + Redis + MinIO + backend API + Celery worker
.env.example          Copy to .env and fill in before running docker compose
```

## Backend

### Run with Docker Compose (recommended)

```bash
cp .env.example .env   # already done if you're reading this after setup
docker compose up --build
```

This starts Postgres, Redis, MinIO (with the `health-media` bucket auto-created), the Flask API on
`:5000`, and a Celery worker. The API container runs `flask db upgrade` on startup via `entrypoint.sh`.

> Note: this was built and validated in an environment without a running Docker daemon, so the compose
> stack has been checked with `docker compose config` (renders correctly) and the migration has been
> verified end-to-end against SQLite — but the full multi-container stack itself hasn't been exercised.
> If anything doesn't come up cleanly on first `docker compose up`, check container logs first.

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

By default the app points at `http://localhost:5000/api/v1` (iOS simulator/desktop) or
`http://10.0.2.2:5000/api/v1` (Android emulator, which aliases the host machine). Override with
`flutter run --dart-define=API_BASE_URL=http://<your-host>:5000/api/v1` for a physical device.

Run tests/analysis:

```bash
flutter analyze
flutter test
cd packages/health_ui && flutter test   # design system package
```

> The design system uses `google_fonts`, which fetches font files over the network on first use per
> device (falling back to a system font if offline). No bundled font assets are included.

## Design system (`packages/health_ui`)

Tokens (color/type/spacing), the `KunjanMascot` widget (named states: `idle`, `thinking`, `celebrating`,
`alerting`, `remembering`), `LogConfirmationCard`, `AlertBanner`, and the `MemoryTrailTimeline` — the app's
one deliberate structural signature, used on Trends and Logbook. See
[`Development-Prompt-Health-App.md`](Development-Prompt-Health-App.md) §2–3 for the rationale behind each.
