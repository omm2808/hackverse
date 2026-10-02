# Fit Odyssey — Database & RPC Reference

> **Document Type:** Backend API & Interface Specification  
> **Architecture:** Pure Supabase (PostgreSQL RLS, RPC Stored Procedures, One Edge Function)  
> **Notice:** There are NO traditional REST API endpoints (e.g. Express/NestJS). All client-server communication occurs directly via the Supabase Client SDK over HTTPS utilizing PostgreSQL Row Level Security (RLS), Remote Procedure Calls (RPC), and one authenticated Edge Function.

---

## 1. Table Access & Permission Matrix

Clients communicate with PostgreSQL tables directly via Supabase Auth session JWTs. Direct table mutation privileges are strictly locked down to enforce server-side authority.

| Table Name | Client SELECT Privilege | Client INSERT Privilege | Client UPDATE Privilege | Client DELETE Privilege | Authority & Write Path |
|---|---|---|---|---|---|
| `profiles` | Own row (`auth.uid() = id`) or via leaderboard RPC | ❌ Forbidden (Created via Auth trigger) | ✅ Own row (non-sensitive profile fields) | ❌ Forbidden (Only via `delete-account`) | Client updates display name, college, hostel, language, consent, visibility. |
| `workouts` | Own rows (`auth.uid() = user_id`) | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | **Written ONLY via `submit_workout()` RPC.** |
| `xp_events` | Own rows (`auth.uid() = user_id`) | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | **Written ONLY via `submit_workout()` RPC.** |
| `streaks` | Own row (`auth.uid() = user_id`) | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | **Managed ONLY via `submit_workout()` RPC.** |
| `goals` | Own rows (`auth.uid() = user_id`) | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | **Managed ONLY via `submit_workout()` RPC.** |
| `heritage_journeys`| Public / Authenticated (Read-only) | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | Seeded via `seed.sql`. |
| `heritage_checkpoints`| Public / Authenticated (Read-only) | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | Seeded via `seed.sql`. |
| `trek_progress` | Own row (`auth.uid() = user_id`) | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | **Updated ONLY via `submit_workout()` RPC.** |
| `user_checkpoints` | Own rows (`auth.uid() = user_id`) | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | **Inserted ONLY via `submit_workout()` RPC.** |
| `monthly_snapshots`| Own rows (`auth.uid() = user_id`) | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | **Snapshotted via `pg_cron` (`close_month`).** |
| `workout_rejections`| ❌ Zero Client Access | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | **Written ONLY by server anti-cheat logic.** |
| `app_config` | Authenticated (Read-only) | ❌ Forbidden | ❌ Forbidden | ❌ Forbidden | Maintained by system migrations/seeds. |

---

## 2. Remote Procedure Calls (RPC Reference)

All stored procedures are written in PL/pgSQL, executed as `SECURITY DEFINER` with fixed `SET search_path = public, pg_temp;`, and authenticate callers strictly through `auth.uid()`.

---

### 2.1. `submit_workout`

Submits a completed workout from the client offline queue. Performs validation, anti-cheat analysis, idempotent insertion, XP calculation, streak incrementation, heritage progress advancement, and adaptive goal calibration inside **one single atomic transaction**.

```sql
submit_workout(
  p_id uuid,
  p_exercise text,
  p_reps int,
  p_duration_sec int,
  p_form_accuracy numeric,
  p_form_flags jsonb,
  p_started_at timestamptz
) RETURNS jsonb
```

#### Parameters:
- `p_id` (`uuid`, required): Client-generated UUID representing the local workout session (ensures network retry idempotency).
- `p_exercise` (`text`, required): One of `'squat'`, `'pushup'`, `'plank'`.
- `p_reps` (`int`, required): Count of validated repetitions (for `'plank'`, duration in seconds).
- `p_duration_sec` (`int`, required): Total elapsed active workout time in seconds.
- `p_form_accuracy` (`numeric`, required): Average biomechanical form score (0.00 to 100.00).
- `p_form_flags` (`jsonb`, required): Summary dictionary of form violations (e.g. `{"knee_valgus": 2, "torso_lean": 1}`).
- `p_started_at` (`timestamptz`, required): Timestamp when the workout started.

#### Anti-Cheat Rules (Evaluated in Procedure):
1. **Rep Rate Check:** Implausible rep rate ($> 60\text{ reps/minute}$ for squats and pushups, or $> 1.0\text{ sec/sec}$ for plank) triggers rejection.
2. **Duration Sane Minimum:** Workouts claiming $> 0$ reps in $< 5\text{ seconds}$ total duration are rejected.
3. **Daily Cap:** Max 20 submitted workouts per 24-hour rolling window per user.
4. *When rejected:* An entry is inserted into `workout_rejections(user_id, reason, payload)` and the transaction raises an exception or returns `{ "status": "rejected", "reason": "<string>" }`.

#### Idempotency Behavior:
If a row already exists in `workouts` with primary key `p_id`, the function bypasses insertion and returns the previously computed gamification results for that workout ID.

#### Output Response (`jsonb`):
```json
{
  "status": "success",
  "workout_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "xp_earned": 90,
  "km_gained": 1.25,
  "unlocked_checkpoints": [
    {
      "checkpoint_id": "dhauli_shanti_stupa",
      "name_en": "Dhauli Shanti Stupa",
      "name_or": "ଧଉଳି ଶାନ୍ତି ସ୍ତୂପ",
      "bonus_xp": 75
    }
  ],
  "new_streak": 5,
  "goal_changed": true,
  "new_weekly_goal_reps": 165
}
```

#### Errors:
- `401 Unauthorized`: Caller is not authenticated (`auth.uid() IS NULL`).
- `400 Invalid Arguments`: Invalid exercise type, negative reps, or duration out of bounds.
- `422 Anti-Cheat Violation`: Workout failed rate-limit or biological plausibility checks.

---

### 2.2. `leaderboard`

Fetches ranked leaderboard standings for a designated period and institutional scope.

```sql
leaderboard(
  p_period text,      -- 'weekly' | 'monthly'
  p_scope text,       -- 'global' | 'college' | 'hostel'
  p_scope_value text, -- e.g. 'CET Bhubaneswar' or NULL for global
  p_limit int         -- default 50
) RETURNS TABLE (
  rank bigint,
  display_name text,
  college text,
  hostel text,
  xp bigint
)
```

#### Privacy Masking:
- Users with `leaderboard_visibility = 'anonymous'` have their `display_name` returned as `"Athlete #NNNN"` (using the last 4 characters of their user UUID).
- Users with `leaderboard_visibility = 'hidden'` are completely excluded from the query results.
- **Security Guarantee:** The raw `user_id` of other athletes is **never** included in the returned table.

---

### 2.3. `my_rank`

Retrieves the caller's specific rank, total XP, and percentile within the designated scope and period.

```sql
my_rank(
  p_period text,      -- 'weekly' | 'monthly'
  p_scope text,       -- 'global' | 'college' | 'hostel'
  p_scope_value text  -- e.g. 'CET Bhubaneswar' or NULL for global
) RETURNS TABLE (
  rank bigint,
  xp bigint,
  total_participants bigint
)
```

#### Output:
Returns a single row indicating the caller's rank among all active participants in that scope.

---

### 2.4. `monthly_summary`

Compiles comprehensive athletic metrics for a given calendar month for the calling user.

```sql
monthly_summary(
  p_month date -- First day of target month, e.g. '2026-09-01'
) RETURNS jsonb
```

#### Output Response (`jsonb`):
```json
{
  "month": "2026-09-01",
  "total_workouts": 24,
  "total_reps": {
    "squat": 380,
    "pushup": 290,
    "plank_sec": 1200
  },
  "active_minutes": 215,
  "total_xp": 2450,
  "km_travelled": 32.4,
  "average_form_accuracy": 91.5,
  "form_flags": {
    "knee_valgus": 8,
    "torso_lean": 3,
    "sagging_hips": 5
  },
  "best_streak": 14,
  "daily_activity": {
    "2026-09-01": 25,
    "2026-09-02": 30
  },
  "trend_vs_previous_month": {
    "reps_diff_pct": 12.5,
    "xp_diff_pct": 15.2
  }
}
```

---

### 2.5. `export_monthly_report`

Generates structured JSON data for a specific calendar month, structured specifically for client-side CSV parsing.

```sql
export_monthly_report(
  p_month date
) RETURNS jsonb
```

#### Output:
An array of individual workout records containing date, exercise, reps, duration, form accuracy, and XP generated during that month.

---

### 2.6. `export_my_data`

Fulfills compliance with the Indian **DPDP Act 2023** (Right to Access and Portability).

```sql
export_my_data() RETURNS jsonb
```

#### Output Response (`jsonb`):
Full hierarchical JSON package containing:
- Profile details and consent timestamp
- Complete historical workout log
- XP events ledger
- Current and longest streak records
- Heritage trek progress and unlocked checkpoints
- Goal adjustment history

---

### 2.7. `delete_workout_history`

Allows the user to reset their fitness progress without deleting their identity or login credentials.

```sql
delete_workout_history() RETURNS void
```

#### Behavior:
- Deletes all rows in `workouts` for `auth.uid()`.
- Deletes all rows in `xp_events` for `auth.uid()`.
- Resets `streaks` to `current = 0, longest = 0, last_date = NULL`.
- Resets `trek_progress` to `km = 0.0`.
- Deletes all rows in `user_checkpoints` for `auth.uid()`.
- Resets `profiles.xp_total` to `0`.

---

## 3. Supabase Edge Function Reference

There is **exactly ONE** Edge Function in the architecture.

### `delete-account`

Completely purges a user's account from Supabase Auth and the database, fulfilling the DPDP Act 2023 Right to Erasure.

- **Route:** `POST /functions/v1/delete-account`
- **Authentication:** `Authorization: Bearer <USER_SESSION_JWT>`
- **Runtime:** Deno / TypeScript (Supabase Edge runtime)
- **Privilege Model:** Executes on the server using `SUPABASE_SERVICE_ROLE_KEY`.

#### Execution Workflow:
1. Validates the caller's JWT using Supabase Auth client to extract verified `user_id = auth.uid()`.
2. Rejects request with `401 Unauthorized` if JWT is missing, invalid, or expired.
3. Invokes `supabaseAdmin.auth.admin.deleteUser(user_id)`.
4. PostgreSQL foreign key constraints with `ON DELETE CASCADE` automatically and atomically purge:
   - `profiles`
   - `workouts`
   - `xp_events`
   - `streaks`
   - `goals`
   - `trek_progress`
   - `user_checkpoints`
   - `monthly_snapshots`
5. Returns `200 OK` with `{ "success": true, "message": "Account and all associated records permanently purged." }`.
6. **Idempotency & Error Handling:** If the user is already deleted, returns `404 User Not Found` or `200 OK`. If deletion fails partway, returns `500 Internal Server Error` with diagnostic message (without leaking server credentials).
