-- Fit Odyssey — Initial Database Migration
-- Version: 20260930000000_init_schema.sql

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. App Configuration Table
CREATE TABLE IF NOT EXISTS public.app_config (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  description text
);

-- 2. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL,
  college text NOT NULL,
  hostel text,
  language text NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'or')),
  weekly_goal_reps int NOT NULL DEFAULT 150,
  xp_total bigint NOT NULL DEFAULT 0,
  leaderboard_visibility text NOT NULL DEFAULT 'public' 
    CHECK (leaderboard_visibility IN ('public', 'anonymous', 'hidden')),
  consent_version text,
  consent_accepted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 3. Workouts Table (metrics only; zero raw video/landmarks)
CREATE TABLE IF NOT EXISTS public.workouts (
  id uuid PRIMARY KEY, -- Client-generated UUID for offline idempotency
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  exercise text NOT NULL CHECK (exercise IN ('squat', 'pushup', 'plank')),
  reps int NOT NULL CHECK (reps >= 0),
  duration_sec int NOT NULL CHECK (duration_sec >= 0),
  form_accuracy numeric(5, 2) NOT NULL CHECK (form_accuracy >= 0 AND form_accuracy <= 100),
  form_flags jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 4. XP Events Table
CREATE TABLE IF NOT EXISTS public.xp_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount int NOT NULL CHECK (amount > 0),
  source text NOT NULL CHECK (source IN ('workout', 'streak_bonus_7', 'streak_bonus_30', 'checkpoint_unlock')),
  source_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 5. Streaks Table
CREATE TABLE IF NOT EXISTS public.streaks (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  current int NOT NULL DEFAULT 0 CHECK (current >= 0),
  longest int NOT NULL DEFAULT 0 CHECK (longest >= 0),
  last_date date
);

-- 6. Adaptive Goals Table
CREATE TABLE IF NOT EXISTS public.goals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  weekly_goal_reps int NOT NULL CHECK (weekly_goal_reps >= 50),
  previous_goal int NOT NULL,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 7. Heritage Journeys & Checkpoints
CREATE TABLE IF NOT EXISTS public.heritage_journeys (
  id text PRIMARY KEY,
  name_en text NOT NULL,
  name_or text NOT NULL,
  desc_en text NOT NULL,
  desc_or text NOT NULL,
  total_km numeric(6, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.heritage_checkpoints (
  id text PRIMARY KEY,
  journey_id text NOT NULL REFERENCES public.heritage_journeys(id) ON DELETE CASCADE,
  name_en text NOT NULL,
  name_or text NOT NULL,
  desc_en text NOT NULL,
  desc_or text NOT NULL,
  km numeric(6, 2) NOT NULL,
  unlock_order int NOT NULL,
  bonus_xp int NOT NULL DEFAULT 75
);

-- 8. Trek Progress & User Checkpoints
CREATE TABLE IF NOT EXISTS public.trek_progress (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  journey_id text NOT NULL REFERENCES public.heritage_journeys(id) ON DELETE CASCADE,
  km numeric(6, 2) NOT NULL DEFAULT 0.0 CHECK (km >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, journey_id)
);

CREATE TABLE IF NOT EXISTS public.user_checkpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  checkpoint_id text NOT NULL REFERENCES public.heritage_checkpoints(id) ON DELETE CASCADE,
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_user_checkpoint UNIQUE (user_id, checkpoint_id)
);

-- 9. Monthly Snapshots Table
CREATE TABLE IF NOT EXISTS public.monthly_snapshots (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  month date NOT NULL,
  data jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, month)
);

-- 10. Workout Rejections Table (Anti-cheat audit; NO client access)
CREATE TABLE IF NOT EXISTS public.workout_rejections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reason text NOT NULL,
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_workouts_user_started ON public.workouts (user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_xp_events_user_created ON public.xp_events (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_college_xp ON public.profiles (college, xp_total DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_hostel_xp ON public.profiles (hostel, xp_total DESC);
CREATE INDEX IF NOT EXISTS idx_checkpoints_journey_order ON public.heritage_checkpoints (journey_id, unlock_order ASC);

-- Enable Row Level Security (RLS) on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xp_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.heritage_journeys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.heritage_checkpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trek_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_checkpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_rejections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- profiles
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT TO authenticated USING (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE TO authenticated USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- workouts: read own rows only; direct client insert/update/delete forbidden
CREATE POLICY "workouts_select_own" ON public.workouts
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- xp_events: read own rows only; direct client insert/update/delete forbidden
CREATE POLICY "xp_events_select_own" ON public.xp_events
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- streaks: read own row only
CREATE POLICY "streaks_select_own" ON public.streaks
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- goals: read own rows only
CREATE POLICY "goals_select_own" ON public.goals
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- heritage catalog: public read
CREATE POLICY "heritage_journeys_select" ON public.heritage_journeys
  FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "heritage_checkpoints_select" ON public.heritage_checkpoints
  FOR SELECT TO authenticated, anon USING (true);

-- trek progress & user checkpoints: read own rows only
CREATE POLICY "trek_progress_select_own" ON public.trek_progress
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "user_checkpoints_select_own" ON public.user_checkpoints
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- monthly snapshots: read own rows only
CREATE POLICY "monthly_snapshots_select_own" ON public.monthly_snapshots
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- app_config: public read
CREATE POLICY "app_config_select" ON public.app_config
  FOR SELECT TO authenticated, anon USING (true);

-- Trigger: Automatically provision profile and streak row on user sign-up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, college, language)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'Athlete'),
    COALESCE(NEW.raw_user_meta_data->>'college', 'Odisha Campus'),
    COALESCE(NEW.raw_user_meta_data->>'language', 'en')
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.streaks (user_id, current, longest)
  VALUES (NEW.id, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.trek_progress (user_id, journey_id, km)
  VALUES (NEW.id, 'odisha_golden_triangle', 0.0)
  ON CONFLICT (user_id, journey_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
