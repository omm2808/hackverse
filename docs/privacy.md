# Fit Odyssey — Privacy Architecture

## Privacy by Design (Core Tenant)
1. **Local Pose Computation**: Pose estimation runs locally on the user's mobile device via MediaPipe. Only lightweight mathematical metrics (reps, durations, joint angles) are transmitted upon workout submission.
2. **Location Privacy**: Location data is strictly opt-in and used solely for mapping virtual heritage milestones, never shared without explicit consent.
3. **Data Deletion Rights**: Complete account deletion (`DELETE /users/me`) and workout history purging (`DELETE /users/me/data`) are natively supported.
4. **Auditability**: Administrative access is logged in the `AuditLog` table.
