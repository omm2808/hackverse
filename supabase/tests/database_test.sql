-- Fit Odyssey — Database Security & RLS pgTAP Test Suite
BEGIN;
SELECT plan(10);

-- 1. Check schemas and extensions
SELECT has_extension('pgcrypto', 'Extension pgcrypto should be installed');

-- 2. Verify all core tables exist
SELECT has_table('public', 'profiles', 'Table profiles exists');
SELECT has_table('public', 'workouts', 'Table workouts exists');
SELECT has_table('public', 'xp_events', 'Table xp_events exists');
SELECT has_table('public', 'streaks', 'Table streaks exists');
SELECT has_table('public', 'goals', 'Table goals exists');
SELECT has_table('public', 'heritage_journeys', 'Table heritage_journeys exists');
SELECT has_table('public', 'heritage_checkpoints', 'Table heritage_checkpoints exists');
SELECT has_table('public', 'trek_progress', 'Table trek_progress exists');
SELECT has_table('public', 'app_config', 'Table app_config exists');

SELECT * FROM finish();
ROLLBACK;
