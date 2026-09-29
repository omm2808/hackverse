# Fit Odyssey — Database Design & Schema Strategy

## Incremental Schema Plan
In accordance with Phase 1 guidance, database models are created incrementally as their feature phases are developed, rather than dumping all 20+ tables up front:

1. **Phase 2 & 3 (Auth & Core User)**: `User`, `Profile`, `PrivacyPreference`
2. **Phase 6 (Workouts)**: `WorkoutSession`, `Exercise`, `ExerciseResult`, `WorkoutMetric`
3. **Phase 7 (Progress & Streaks)**: `Streak`, `UserGoal`, `ProgressSnapshot`
4. **Phase 8 (Heritage & Challenges)**: `HeritageJourney`, `HeritageCheckpoint`, `UserJourneyProgress`, `Challenge`, `ChallengeProgress`
5. **Phase 9 (Gamification & Leaderboard)**: `XPTransaction`, `Badge`, `UserBadge`, `Leaderboard`, `LeaderboardEntry`
6. **Phase 11 (Security/Audit)**: `AuditLog`

## Data Rules
- Primary keys: UUIDv4
- Foreign key cascading rules strictly enforced
- Zero camera video or image storage in database
- Sensitive auth secrets managed by Supabase Auth; backend stores user references and app state
