# Fit Odyssey — API Reference

> **Base URL:** `http://localhost:3001` (Dev) / `https://api.fitodyssey.app` (Prod)  
> **API Version:** v1

## Authentication Endpoints (`/auth`)
- `POST /auth/register` — Register a new user account via Supabase Auth
- `POST /auth/login` — Sign in and receive session tokens
- `POST /auth/logout` — Revoke active session tokens
- `POST /auth/refresh` — Refresh expired access token

## User Endpoints (`/users`)
- `GET /users/me` — Fetch authenticated user profile
- `PATCH /users/me` — Update user profile details
- `GET /users/me/privacy` — Retrieve current privacy settings
- `PATCH /users/me/privacy` — Update privacy configurations
- `DELETE /users/me` — Account and data deletion (GDPR/privacy-by-design)

## Workout Endpoints (`/workouts`)
- `POST /workouts` — Initialize or sync a workout session
- `GET /workouts` — Retrieve user workout history
- `GET /workouts/:id` — Retrieve workout session breakdown
- `POST /workouts/:id/complete` — Conclude workout, trigger server XP & achievements

## Gamification Endpoints
- `GET /heritage/journeys` — List available Odisha heritage routes
- `GET /challenges` — List active community/college challenges
- `GET /leaderboards/global` — Query global XP leaderboards
- `GET /badges` — Query available badges catalog

*Full API specification with schemas will be expanded in Phase 2 & 3.*
