# Product Requirements Document
## VitaChat — Conversational Health & Wellness Companion
*(working name — replace with your brand)*

**Document version:** 1.0
**Platform:** Flutter (iOS/Android) + Python Flask (backend)
**Prepared for:** Exatech

---

## 1. Product Vision

Most health apps make the user do the work: pick a food from a database, log a number, tap through five screens to record a mood. **VitaChat flips that** — the user just talks (types, snaps a photo, or sends a short video) the way they'd text a friend, and the AI does the structuring, classification, and analysis in the background.

The wedge is: **conversational logging + a persistent medical context**, so the AI isn't just counting calories — it knows the user has a peanut allergy, is managing pre-diabetes, and is targeting a BP goal, and every log is interpreted against that context.

**One-line pitch:** *"A health journal that listens, watches, and warns — instead of one you have to fill out."*

---

## 2. Problem Statement

- Existing trackers (MyFitnessPal, HealthifyMe, Google Fit) require manual, structured entry — high drop-off after week 2–3.
- None of them hold a **medical profile** that actively cross-checks daily behavior (e.g., flag a food that conflicts with a known allergy or condition in real time).
- None accept **photos/videos as a first-class input** for food, symptoms, or activity — everything is dropdowns and search bars.
- Users with a condition (diabetic, hypertensive, post-surgery recovery) have no single place that combines lab reports + daily logs + AI-driven trend commentary.

---

## 3. Target Users

| Persona | Need |
|---|---|
| **Goal-driven user** (weight loss, cholesterol/BP control) | Frictionless daily logging, progress visibility |
| **Chronic-condition user** (diabetic, hypertensive, thyroid, PCOS) | Allergy/trigger alerts, trend correlation with labs |
| **Mental-wellness-focused user** | Mood/stress logging without a clinical feel |
| **Caregiver** *(proposed addition)* | Logs on behalf of a dependent (elderly parent, child) |

App is unisex/general-purpose by design — no gendered framing in onboarding or UI.

---

## 4. Core Differentiators (Product POV)

1. **Multimodal input as default**, not an afterthought — text, photo, and short video are equal citizens in the chat.
2. **Medical-context-aware AI** — every log is checked against the user's actual profile, not generic averages.
3. **Zero manual data entry** — extraction happens behind the reply, never a separate "add entry" flow.
4. **Doctor-ready exports** — the one thing generic trackers don't do well; a clean report to hand to a physician is a real retention hook.
5. *(Added)* **Passive trend narration** — instead of the user hunting through charts, the AI proactively opens conversations: *"Your BP readings this week trended higher after low-sleep nights — want to see the pattern?"*

---

## 5. Multimodal Chat — How Each Input Type Is Handled

| Input | Processing | Output |
|---|---|---|
| **Text** | LLM structured extraction (function-calling) | LogEntry (food/sleep/mood/activity/stress) |
| **Photo — food** | Vision-LLM identifies dish/items → portion estimate → calorie/macro lookup | Food LogEntry + calorie estimate, flagged if allergen match |
| **Photo — lab report/prescription** | OCR/document parsing → structured values | LabResult entries, linked to MedicalProfile |
| **Photo — symptom (rash, swelling, injury)** | Vision-LLM tags visual description only, **never a diagnosis** — routes to "flagged for your attention / consider consulting a doctor" | Symptom LogEntry with image reference |
| **Video — workout/activity** | Sampled frames + duration → activity type & intensity estimate | Activity LogEntry (type, duration, estimated calories burned) |
| **Video — symptom description (spoken)** | Transcribed via speech-to-text → same extraction pipeline as text | Symptom/mood LogEntry |

All media is stored (object storage, e.g. S3-compatible) with a reference in the LogEntry — never processed and discarded, since photos/videos are also useful for later doctor review.

---

## 6. Information Architecture (App Pages)

1. **Chat (Home)** — primary interface; text/photo/video input bar
2. **Today** — day summary card (calories, water, activity, mood, sleep) generated from chat, editable by tapping
3. **Trends & Analytics** — charts: weight, BP, calories vs. goal, mood over time, correlations (e.g. sleep vs. mood)
4. **Medical Profile** — conditions, allergies, goals, lab history (editable, versioned)
5. **Logbook** — searchable/filterable raw history of every entry (by type, date, media)
6. **Reports** — generate a PDF summary for a date range (doctor-visit ready)
7. **Goals** — active goals, progress %, milestones
8. **Settings & Privacy** — data export, delete account, consent management, caregiver access (if applicable)

---

## 7. Feature List

### 7.1 Onboarding
- Guided structured intake (not chat) for: demographics, existing conditions, allergies (structured list, not free text), medications, current goal(s), baseline vitals
- Scan report upload with OCR extraction, reviewed/confirmed by user before saving
- Consent screen (what data is stored, how it's used, opt-in for AI analysis) — required given data sensitivity

### 7.2 Conversational Logging
- Free-text, photo, and video input in one chat thread
- Multi-entity extraction per message (one message → multiple structured logs)
- Inline confirmation ("Logged: oatmeal + banana, ~320 kcal — edit?") so the user can correct AI misreads

### 7.3 Real-Time Safety Checks
- Allergy cross-check on every food log — immediate in-chat warning
- Medication/condition conflict flags (e.g., high-sodium meal logged for a BP-goal user)
- Configurable severity — hard warning for allergies, soft nudge for goal-conflicting choices

### 7.4 Analytics & Insights
- Daily/weekly/monthly aggregates: calories, macros, activity minutes, sleep, mood score
- Correlation surfacing (sleep vs mood, stress-hours vs food choices)
- Goal progress tracking against the target set at onboarding

### 7.5 Query & Recall
- Natural-language queries against the user's own history: *"What did I eat yesterday?"* / *"How's my BP trended this month?"*
- Answered via structured DB queries, not by re-reading raw chat — accurate and fast

### 7.6 Reports & Sharing
- Exportable PDF report for a chosen date range — logs, trends, lab history
- *(Proposed)* Shareable read-only link/report for a treating doctor, time-limited

### 7.7 *(Proposed additions)*
- **Caregiver mode** — a family member logs/monitors on behalf of a dependent, with permissioned access
- **Reminders** — medication times, meal logging nudges if the user goes quiet for a stretch of the day
- **Streaks/gentle gamification** — logging consistency, not weight-loss shaming — kept optional/toggleable given the mental-health logging angle
- **Weekly AI check-in** — a proactive chat message summarizing the week, not just passive dashboards

---

## 8. Data Model (Flask / SQLAlchemy)

- `User`
- `MedicalProfile` (conditions, goals, baseline vitals — versioned/history-tracked)
- `Allergy` (structured, linked to user)
- `LabResult` (source: OCR/manual, values, date, linked scan file)
- `LogEntry` (user, type [food/sleep/mood/activity/stress/symptom], timestamp, structured_payload JSONField, raw_text, media reference)
- `MediaAsset` (file reference, type [photo/video], linked LogEntry)
- `DailyAggregate` (computed via Celery: calories, activity minutes, mood score, sleep hours)
- `Goal` (type, target value, start/target date, status)
- `AlertLog` (trigger type, LogEntry reference, resolved/acknowledged)

---

## 9. System Architecture

```
Flutter App
   │  (text / photo / video)
   ▼
Flask REST API
   │
   ├─► LLM (structured/function-calling extraction) ──► LogEntry
   ├─► Vision-LLM / OCR pipeline (photos, scan reports) ──► LogEntry / LabResult
   ├─► Speech-to-text (video/audio) ──► text extraction pipeline
   ├─► Celery + Redis (aggregates, reminders, report generation)
   └─► PostgreSQL (structured logs) + Object storage (media)
```

- REST API (Flask + Flask-Smorest for resources/OpenAPI); Flask-SocketIO only if real-time streaming replies are wanted
- Media uploaded directly to object storage (signed URLs) — Flask never proxies large files
- Allergy/trigger checks run synchronously in the extraction step, before the chat reply is generated

---

## 10. Privacy & Compliance

- Health data is sensitive — encrypt at rest and in transit
- Explicit consent flow at onboarding (what's stored, how AI uses it, right to delete)
- Data retention & deletion controls in Settings (user can export or wipe all data)
- India's DPDP Act 2023 (and any target-market equivalent, e.g. HIPAA if expanding to the US) should shape the consent and storage design from day one — retrofitting later is costly
- AI symptom flags must carry a clear "not a medical diagnosis" disclaimer everywhere they appear

---

## 11. Monetization (SaaS Model)

| Tier | Includes |
|---|---|
| **Free** | Text logging, basic daily summary, limited history (e.g. 30 days) |
| **Premium** | Photo/video logging, full trend analytics, unlimited history, PDF reports |
| **Family/Caregiver** | Multiple linked profiles under one subscription |
| **B2B (proposed)** | White-labeled version for clinics/wellness centers to offer patients — separate revenue line beyond direct-to-consumer |

---

## 12. Success Metrics

- Day-7 / Day-30 retention (logging consistency is the core value signal)
- Average logs per active day (proxy for how "invisible" the logging friction really is)
- Allergy/trigger alerts delivered vs. acknowledged
- % of users completing a goal milestone
- Report-export usage (signals real-world utility, e.g. taken to a doctor)

---

## 13. Roadmap

**Phase 1 (MVP):** Onboarding + text-based chat logging + basic daily summary + allergy alerts + core Today/Trends/Logbook pages

**Phase 2:** Photo logging (food + scan reports), goal tracking, PDF reports

**Phase 3:** Video logging, caregiver mode, proactive AI weekly check-ins, B2B/clinic offering

---

## 14. Key Risks

| Risk | Mitigation |
|---|---|
| AI misclassifies food/activity → wrong calorie data | Always show extracted entry for user confirmation before finalizing |
| Symptom photo/video interpreted as medical advice | Hard-coded disclaimers, no diagnostic language, "consult a doctor" framing only |
| User trust in storing sensitive medical data | Transparent consent, visible privacy controls, local data export/delete |
| Logging fatigue despite low friction | Weekly AI check-ins and streaks to sustain engagement, not just passive tracking |
