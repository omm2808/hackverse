# Fit Odyssey — Security Architecture

> **Security Baseline:** Zero-Trust Client Architecture, Row Level Security (RLS) on all tables, Server-Side Gamification Authority, and Complete Exclusion of the Service-Role Key from Client Bundles.

---

## 1. Authentication & Session Management

- **Supabase Auth Core:** User authentication is powered natively by Supabase Auth with mandatory email verification and encrypted password hashing (bcrypt/Argon2).
- **Session Tokens:**
  - Standard JSON Web Tokens (JWT) issued with short-lived access lifespans (default 1 hour) and secure refresh tokens.
  - On Flutter (mobile), session tokens and refresh tokens are encrypted at rest using `flutter_secure_storage` (Android Keystore / iOS Keychain).
  - Web client (read-only dashboard) retains session state strictly via standard secure browser storage.
- **Password Reset:** Managed via time-limited, cryptographically random OTPs / magic links sent via Supabase email services.

---

## 2. Server-Side Authority & Write Immutability

Clients are considered untrusted environments. Direct database manipulation is prevented by database-level constraints:

1. **Zero Client Direct Mutations:**
   - Clients CANNOT directly `INSERT`, `UPDATE`, or `DELETE` rows in `workouts`, `xp_events`, `streaks`, `trek_progress`, `user_checkpoints`, `goals`, `monthly_snapshots`, or `workout_rejections`.
   - Any client-side SQL query attempting `supabase.from('workouts').insert(...)` fails immediately with an RLS policy violation.
2. **Single Transactional Write Gateway:**
   - All workout validation, metric storage, XP calculations, streak evaluation, and checkpoint milestone unlocks must pass through the `submit_workout` stored procedure.
3. **Identity Derivation:**
   - Stored procedures NEVER accept a caller-supplied `user_id`. Identity is derived solely from `auth.uid()`, which is extracted by the PostgreSQL engine from the cryptographically verified JWT.

---

## 3. `SECURITY DEFINER` Implementation Rules

PostgreSQL functions executing with `SECURITY DEFINER` run with the privileges of the database owner. To prevent privilege escalation attacks:

1. **Pinned `search_path`:**
   Every function explicitly declares:
   ```sql
   SET search_path = public, pg_temp;
   ```
   This prevents malicious search-path hijacking attacks where users create shadow tables in temporary schemas.
2. **Execution Permissions:**
   Execution rights are revoked from public roles and granted only to verified users:
   ```sql
   REVOKE EXECUTE ON FUNCTION public.submit_workout FROM public, anon;
   GRANT EXECUTE ON FUNCTION public.submit_workout FROM authenticated;
   ```
3. **Explicit Parameter Validation:**
   Parameters are checked for nullability, numeric ranges, and strict regex or enumeration match before executing business logic.

---

## 4. Anti-Cheat Engine (`submit_workout`)

Inside the `submit_workout` procedure, incoming workout payloads are evaluated against biological feasibility limits before any state change occurs:

| Anti-Cheat Check | Feasibility Threshold | Action on Violation |
|---|---|---|
| **Maximum Rep Rate** | $> 60\text{ reps/minute}$ (Squat / Push-up) | Workout rejected; logged to `workout_rejections`. |
| **Plank Hold Feasibility** | Active hold duration $>$ Total session duration | Workout rejected; logged to `workout_rejections`. |
| **Minimum Rep Time** | $< 1.0\text{ second}$ per completed repetition | Workout rejected; logged to `workout_rejections`. |
| **Daily Session Velocity** | $> 20\text{ completed sessions}$ within 24 hours | Workout rejected; logged to `workout_rejections`. |
| **Form Accuracy Range** | Score $< 0.00$ or $> 100.00$ | Database constraint check failure. |

When an anti-cheat rule triggers:
- The workout is not recorded in `workouts`.
- No XP, streak progress, or heritage distance is credited.
- The event is logged to `workout_rejections` with the caller's `user_id`, failure reason, and submitted JSON payload for offline analysis.
- Clients have ZERO read or write access to `workout_rejections`.

---

## 5. Service-Role Key Lockdown Policy

The Supabase `service_role` key grants administrative bypass over all Row Level Security policies.

### Absolute Rules:
1. **Never in Mobile or Web Code:** The `service_role` key must **NEVER** be compiled into the Flutter mobile application, the React web dashboard, or committed to git.
2. **Anon Key Only:** Client applications (`mobile/` and `web/`) are provisioned exclusively with the public `anon` key.
3. **Restricted to Server Edge Functions:** The only component permitted to utilize the `service_role` key is the server-side Deno Edge Function `delete-account`.
4. **Automated CI Enforcement:**
   A continuous integration guard check executes before any merge:
   ```bash
   # CI Gate: Must return 0 matches
   grep -rn "service_role" mobile/ web/ && exit 1 || echo "Service role key check passed."
   ```

---

## 6. Rate Limiting & Denial-of-Service Defense

- **Client-Side Throttling:** The mobile `SyncManager` enforces exponential backoff on retry (starting at 2s, doubling to 30s) during network disruptions.
- **Database Rate Bounds:** Stored procedures limit high-frequency submissions per user via transaction timestamp tracking.
- **Edge Function Rate Limiting:** The `delete-account` Edge Function requires a valid bearer JWT and rejects multiple concurrent deletion attempts from the same identity.
