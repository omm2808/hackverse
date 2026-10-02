# Fit Odyssey — Privacy Architecture & DPDP Act 2023 Compliance

> **Core Philosophy:** Privacy by Design. Camera frames are processed exclusively in volatile device memory and immediately discarded. No video, image, or raw coordinate history is ever recorded or uploaded.

---

## 1. Zero Video Ingestion Principle

1. **Volatile In-Memory Frame Buffer:**
   Camera frames acquired via the mobile camera pipeline are held temporarily in volatile memory buffers for the ~33–66 ms required for on-device landmark inference by ML Kit. Once 33 3D coordinates are extracted, the raw image buffer is immediately released by the operating system garbage collector.
2. **Zero Storage Buckets:**
   No Supabase Storage bucket exists. The application has zero infrastructure provisioned for storing visual files.
3. **No Network or Disk API Imports in Engine:**
   The pose estimation engine (`mobile/lib/features/workout/engine/`) is a pure-Dart module strictly prohibited from importing network libraries (`dart:io`, `http`, `supabase_flutter`) or file-writing APIs.
4. **Automated Static Guard Check:**
   A dedicated unit test / static analysis rule verifies that the camera and pose engine modules never import file-writing or network transmission packages:
   ```dart
   // mobile/test/privacy/privacy_guard_test.dart
   // Ensures zero disk-write or network-transmission imports in engine
   ```

---

## 2. Indian DPDP Act 2023 Alignment

Fit Odyssey complies with the principles of the **Digital Personal Data Protection (DPDP) Act, 2023 (India)**:

- **Lawful Purpose & Notice (Section 5):** Clear, itemized notice presented before onboarding regarding the purpose of camera analysis and profile storage.
- **Explicit Consent (Section 6):** Camera access is requested only after an affirmative "I Agree" user consent action.
- **Data Minimization:** Only high-level aggregated metrics (`reps`, `duration_sec`, `form_accuracy`, `form_flags`) are retained. Raw landmark coordinates and skeleton trajectory vectors are never saved.
- **Right to Access & Portability (Section 11):** Users can export their entire historical record as structured JSON via the `export_my_data()` procedure.
- **Right to Correction & Erasure (Section 12):** Users can wipe their workout history via `delete_workout_history()` or completely eradicate their account via the `delete-account` Edge Function.
- **No Third-Party Trackers:** Zero third-party analytics SDKs, advertising IDs, social trackers, or location sensors are bundled.

### Open Item: Under-18 Parental Consent
> **DPDP Act Section 9 Requirement:** Verifiable parental consent must be obtained prior to processing personal data of individuals under 18 years of age.  
> **MVP Resolution & Team Action Item:** For the hackathon MVP, users affirm during onboarding consent that they are at least 18 years of age. Integrating a verifiable parental consent mechanism (via SMS/email guardian OTP) is flagged as an **Open Item** for legal and product review prior to public play store release.

---

## 3. Data Inventory & Retention Schedule

| Data Field / Entity | Category | Purpose | Retention Period | Deletable by User? |
|---|---|---|---|---|
| `auth.users.email` | Account Identity | Authentication, password reset, account recovery | Until account deletion | Yes (via Delete Account) |
| `profiles.display_name` | Profile | Campus leaderboards and personalized greeting | Until account deletion | Yes (Self-service edit / delete) |
| `profiles.college`, `hostel` | Profile | Campus and hostel leaderboard grouping | Until account deletion | Yes (Self-service edit / delete) |
| `profiles.language` | Preference | App interface localization (`en` or `or`) | Until account deletion | Yes |
| `profiles.consent_*` | Legal Compliance | Proof of DPDP Act consent acceptance | Until account deletion | Yes |
| `workouts` (exercise, reps, duration) | Workout Metric | Tracking physical activity, XP, and streaks | Until wiped or account deleted | Yes (via Delete History or Delete Account) |
| `workouts.form_accuracy` | Quality Metric | Feedback and progress tracking | Until wiped or account deleted | Yes |
| `workouts.form_flags` | Quality Metric | Identifying injury risks (knee valgus, etc.) | Until wiped or account deleted | Yes |
| `xp_events` | Gamification | Weekly/monthly leaderboard scoring | Until wiped or account deleted | Yes |
| `streaks` | Gamification | Habit formation and consistency tracking | Until wiped or account deleted | Yes |
| `trek_progress` | Gamification | Odisha heritage milestone progress | Until wiped or account deleted | Yes |
| **Camera Frames / Video** | Sensory Feed | Real-time pose landmark extraction | **0 ms (Never persisted)** | **N/A (Not stored)** |
| **Raw 33 Landmark Coords**| Biometrics | Joint angle calculation | **0 ms (Discarded after rep)** | **N/A (Not stored)** |
| **Location / GPS Data** | Telemetry | **NOT COLLECTED** | **N/A** | **N/A** |

---

## 4. User Consent & Privacy Workflows

```
                        FIRST-RUN CONSENT WORKFLOW
                                    │
                                    ▼
                     ┌───────────────────────────────┐
                     │     Privacy Consent Modal     │
                     │  • Clear DPDP Notice          │
                     │  • Explains On-Device Camera  │
                     │  • Zero Video Upload Guarantee│
                     │  • Under-18 Affirmation       │
                     └──────────────┬────────────────┘
                                    │
                                    ▼
                             [ User Clicks ]
                           "I Agree & Continue"
                                    │
                                    ▼
                     ┌───────────────────────────────┐
                     │ Server Records Consent        │
                     │ • consent_version = '1.0'     │
                     │ • consent_accepted_at = now() │
                     └──────────────┬────────────────┘
                                    │
                                    ▼
                     ┌───────────────────────────────┐
                     │ OS Camera Permission Dialog   │
                     │ "Allow Fit Odyssey to use     │
                     │ camera for pose tracking?"    │
                     └───────────────────────────────┘
```

### Privacy Settings Screen Controls
The mobile app provides a dedicated Privacy Settings screen equipped with:
1. **Leaderboard Visibility Selector:**
   - `Public`: Displays full display name and college/hostel.
   - `Anonymous`: Masks name as `"Athlete #NNNN"` (using last 4 digits of UUID); college is preserved.
   - `Hidden`: Completely excludes user from all public leaderboard views.
2. **Export My Data:** Calls `export_my_data()`, compiles all database records into formatted JSON, and offers immediate local download or share.
3. **Delete Workout History:** Calls `delete_workout_history()`, clearing all logged workouts and resetting XP and streaks while keeping login credentials intact.
4. **Delete Account:** Triggers the Supabase Edge Function `delete-account` using the session JWT. Deletes `auth.users` entry, cascading to wipe 100% of user data.
