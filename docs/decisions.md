# Fit Odyssey — Architectural Decisions & Assumptions Log (ADR)

This document records the foundational architectural decisions, parameters, and assumptions established for the **Fit Odyssey** hackathon MVP.

---

## 1. Stack Consolidation & Scope Boundary

- **Decision:** Eliminate NestJS, Prisma, Next.js, Turborepo monorepo tooling, the `ml/` Python workspace, Firebase services, RBAC/AuditLog tables, and location GPS access.
- **Replacement:** 
  - **Mobile:** Flutter (Android first) with Riverpod, `go_router`, `camera`, `google_mlkit_pose_detection`, `flutter_tts`, `fl_chart`, `drift` (offline SQLite), `supabase_flutter`, `connectivity_plus`, `flutter_secure_storage`, and `share_plus`.
  - **Backend:** Pure Supabase (PostgreSQL with Row Level Security, Supabase Auth, PostgreSQL Functions/RPC, `pg_cron`, and one Edge Function `delete-account`).
  - **Web Dashboard:** Minimal React + Vite + TypeScript + `@supabase/supabase-js` read-only dashboard.
- **Rationale:** Dramatically reduces operational surface area, eliminates custom backend server maintenance, keeps latency minimal for mobile users, and leverages Postgres RLS and RPC for airtight server-side authority.

---

## 2. Pose Engine Smoothing: Single EMA Alpha Constant

- **Decision:** Fix the Exponential Moving Average (EMA) smoothing factor to **$\alpha = 0.6$** across the entire pose engine.
- **Landmark Visibility Cutoff:** Fix to **$0.6$**. Any landmark with a confidence score below $0.6$ is marked occluded/unreliable and not used for angle math.
- **Rationale:** Resolves contradictions in historical documentation (which cited $\alpha=0.6$, $\alpha=0.7$, and other variants). At 10–15 FPS inference on mobile, $\alpha = 0.6$ delivers an optimal balance between responsiveness (lag $< 100\text{ ms}$) and jitter suppression for joint angle trigonometry.

---

## 3. Server-Side Authority & Zero Client Direct Writes

- **Decision:** The mobile client and web client possess **zero direct INSERT, UPDATE, or DELETE privileges** on core gameplay and metric tables: `workouts`, `xp_events`, `streaks`, `trek_progress`, `user_checkpoints`, `goals`, `monthly_snapshots`, or `workout_rejections`.
- **Mechanism:** The PostgreSQL RPC `submit_workout(...)` operates as the sole write path. It runs with `SECURITY DEFINER` and a pinned `SET search_path = public, pg_temp;`. It derives user identity exclusively from `auth.uid()`.
- **Anti-Cheat:** Built directly into the RPC transaction to reject implausible rep rates (>60 reps/min), mismatched durations, or excessive daily workouts (>20 sessions/day).

---

## 4. Single Supabase Edge Function (`delete-account`)

- **Decision:** Maintain exactly one Edge Function across the entire platform: `delete-account`.
- **Security Rule:** The Supabase `service_role` key is restricted strictly to server-side environments (Supabase Edge Function runtime) and must **never** appear in `mobile/`, `web/`, or source control.
- **Functionality:** Authenticates caller JWT via `auth.uid()`, invokes Supabase Admin Auth API (`auth.admin.deleteUser`) using `SUPABASE_SERVICE_ROLE_KEY`, and leverages PostgreSQL `ON DELETE CASCADE` to wipe all associated database records.

---

## 5. Offline-First Synchronization & Idempotency

- **Decision:** When a workout finishes on mobile, it is committed immediately to a local SQLite table (`drift`) with `sync_status = PENDING` and a client-generated UUID `id`.
- **Sync Behavior:** A background `SyncManager` watches network status via `connectivity_plus`. When online, it calls `submit_workout` passing the client-generated UUID `p_id`.
- **Idempotency:** In PostgreSQL, `workouts` has primary key `id`. If a network retry occurs for a previously processed workout, `submit_workout` executes `ON CONFLICT (id) DO NOTHING` and returns the previously computed gamification results without double-crediting XP, streaks, or checkpoints.

---

## 6. Local Development & Docker Fallback Strategy

- **Decision:** Primary local backend uses Supabase CLI (`supabase start`, requires Docker).
- **Fallback Plan:** If Docker is unavailable or unsupported on the developer host machine:
  1. Fall back to a hosted Supabase Free Tier project.
  2. Maintain migrations strictly in `/supabase/migrations` and apply using `supabase db push --linked`.
  3. **Mitigation for Free-Tier 7-Day Inactivity Pause:** For hackathon evaluation and staging, a scheduled cron ping or test script (`scripts/ping-supabase.sh`) will keep the hosted instance active.

---

## 7. Privacy & Regulatory Alignment (India DPDP Act 2023)

- **Decision:** Discard GDPR-centric terminology in favor of the **Digital Personal Data Protection (DPDP) Act, 2023 (India)**.
- **Camera Safeguards:** Camera frames reside exclusively in volatile RAM buffer during landmark extraction (~30–66 ms) and are immediately dropped. No frame is ever persisted to local disk or transmitted across network interfaces. No Supabase Storage bucket exists.
- **Biometrics Policy:** No raw landmark coordinates or trajectories are retained in the database; only aggregated exercise metrics (exercise type, rep count, duration, accuracy, form flags) are synced.
- **Open Item (Under-18 Users):** Section 9 of the DPDP Act 2023 mandates verifiable parental consent for processing data of children (under 18 years). Because Fit Odyssey targets college and university students (many aged 17–19), the team has flagged verifiable parental consent as an **Open Item** for policy review prior to commercial production. For the hackathon MVP, users verify that they are at least 18 years old during onboarding consent.

---

## 8. Fixed Gamification & Heritage Formulae

- **Heritage Distance:** Calculated server-side inside `submit_workout`:
  $$\text{km} = (\text{reps} \times 0.05) + (\text{active\_minutes} \times 0.1) + 0.5\text{ (per completed workout)}$$
- **XP Calculation:**
  $$\text{XP} = 50\text{ (base)} + (\text{reps} \times 2)$$
  *(For Plank, hold time is converted: $5\text{ seconds} = 1\text{ rep equivalent}$.)*
  - 7-Day Streak Bonus: $+150\text{ XP}$
  - 30-Day Streak Bonus: $+500\text{ XP}$
  - Heritage Checkpoint Unlock Bonus: $+75\text{ XP}$
- All constants reside in the `app_config` table for central governance.
