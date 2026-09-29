# Fit Odyssey — Privacy Architecture

## Privacy by Design (Core Architectural Tenet)

Fit Odyssey is designed from the ground up so that users can work out in the privacy of their homes or dorm rooms without fear of invasive video recording or cloud surveillance.

---

### 1. Dual On-Device Edge AI Isolation
- **Layer 1 (MediaPipe Pose Estimation)** executes locally in native memory on the smartphone's edge hardware (CPU/GPU/NPU delegates).
- **Layer 2 (Custom Exercise Classifier)** executes locally on lightweight landmark vectors (16–64 floats).
- **Zero Video Upload:** The camera frame buffer exists solely in volatile memory for the duration of the frame processing cycle (~33 ms) and is discarded immediately.
- **No Backend Video Ingestion API:** The NestJS API does not possess any endpoint, file storage bucket, or route capable of receiving raw camera frames or video streams.

---

### 2. Metrics-Only Backend Synchronization
When a workout session completes or syncs, only aggregated mathematical and gamification metrics are transmitted:
- Session start and end timestamps.
- Exercise identifier (`SQUAT`, `PUSHUP`, `PLANK`).
- Validated repetition count and hold durations.
- Average form accuracy percentage (e.g. `92%`).
- No raw landmark sequences or coordinate histories are retained on the server.

---

### 3. Location Privacy
- Location access is strictly optional and used solely to calibrate virtual distance along the virtual Odisha Heritage map (Lingaraj to Konark).
- Users can disable location permissions at any time without degrading camera workout functionality.

---

### 4. User Data Sovereignty & GDPR/DPDP Compliance
- **Right to Export:** `GET /users/me/data-export` returns all historical workout sessions and account records in structured JSON.
- **Right to Workout Purge:** `DELETE /users/me/data` wipes all workout session records while preserving authentication credentials.
- **Right to Erasure (Account Deletion):** `DELETE /users/me` permanently deletes the user identity, profile, workout records, streak logs, and leaderboard entries via cascading database deletion.

---

### 5. Administrative Audit Logging
- System administrators (`SUPER_ADMIN` and `COLLEGE_ADMIN`) can only view aggregated group/college statistics.
- Under no circumstances can any administrator inspect individual biometric camera feeds, as such feeds are never stored.
- Administrative interventions are permanently logged to the `AuditLog` table.
