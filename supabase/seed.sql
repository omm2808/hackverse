-- Fit Odyssey — Seed Data Skeleton
-- Populates initial heritage journey, checkpoints, and app configuration constants

-- 1. App Configuration Constants
INSERT INTO public.app_config (key, value, description) VALUES
  ('xp_rules', '{
    "base_workout": 50,
    "per_rep": 2,
    "plank_seconds_per_rep": 5,
    "streak_bonus_7": 150,
    "streak_bonus_30": 500,
    "checkpoint_bonus": 75
  }'::jsonb, 'Server-authoritative XP computation values'),
  ('km_rules', '{
    "per_rep": 0.05,
    "per_active_minute": 0.10,
    "per_completed_workout": 0.50
  }'::jsonb, 'Distance generation formula rates for virtual trek'),
  ('anti_cheat', '{
    "max_reps_per_minute": 60,
    "min_workout_duration_sec": 5,
    "max_daily_workouts": 20
  }'::jsonb, 'Biological sanity bounds evaluated in submit_workout'),
  ('pose_engine', '{
    "ema_alpha": 0.6,
    "min_visibility": 0.6,
    "squat_standing_angle": 150.0,
    "squat_bottom_angle": 100.0,
    "pushup_high_angle": 150.0,
    "pushup_bottom_angle": 95.0,
    "plank_min_angle": 155.0,
    "plank_max_angle": 185.0
  }'::jsonb, 'Biomechanical baseline thresholds')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 2. Heritage Journey: Odisha Golden Triangle
INSERT INTO public.heritage_journeys (id, name_en, name_or, desc_en, desc_or, total_km) VALUES
  ('odisha_golden_triangle', 
   'Odisha Golden Triangle Trek', 
   'ଓଡ଼ିଶା ସ୍ୱର୍ଣ୍ଣ ତ୍ରିଭୁଜ ଯାତ୍ରା',
   'A virtual 65 km cultural trek across Odisha sacred landmarks from Lingaraj to the Sun Temple.',
   'ଲିଙ୍ଗରାଜ ମନ୍ଦିରରୁ କୋଣାର୍କ ସୂର୍ଯ୍ୟ ମନ୍ଦିର ପର୍ଯ୍ୟନ୍ତ ଏକ ୬୫ କିଲୋମିଟରର ପବିତ୍ର ଯାତ୍ରା।',
   65.0)
ON CONFLICT (id) DO UPDATE SET 
  name_en = EXCLUDED.name_en,
  name_or = EXCLUDED.name_or,
  total_km = EXCLUDED.total_km;

-- 3. Heritage Checkpoints along the Route
INSERT INTO public.heritage_checkpoints (id, journey_id, name_en, name_or, desc_en, desc_or, km, unlock_order, bonus_xp) VALUES
  ('lingaraj_temple', 'odisha_golden_triangle',
   'Lingaraj Temple', 'ଲିଙ୍ଗରାଜ ମନ୍ଦିର',
   'Ancient 11th-century temple representing the pinnacle of Kalinga architecture.',
   'ଏକାଦଶ ଶତାବ୍ଦୀର ପ୍ରାଚୀନ ମନ୍ଦିର, କଳିଙ୍ଗ ସ୍ଥାପତ୍ୟ କଳାର ଅନନ୍ୟ ନିଦର୍ଶନ।',
   0.0, 1, 75),
  ('dhauli_shanti_stupa', 'odisha_golden_triangle',
   'Dhauli Shanti Stupa', 'ଧଉଳି ଶାନ୍ତି ସ୍ତୂପ',
   'Historic peace pagoda marking Emperor Ashoka transformation following the Kalinga War.',
   'କଳିଙ୍ଗ ଯୁଦ୍ଧ ପରେ ସମ୍ରାଟ ଅଶୋକଙ୍କ ହୃଦୟ ପରିବର୍ତ୍ତନର ପ୍ରତୀକ ଶାନ୍ତି ସ୍ତୂପ।',
   8.0, 2, 75),
  ('udayagiri_caves', 'odisha_golden_triangle',
   'Udayagiri Caves', 'ଉଦୟଗିରି ଗୁମ୍ଫା',
   'Ancient rock-cut sanctuaries and inscriptions of King Kharavela dating to 2nd century BCE.',
   'ଖାରବେଳଙ୍କ ସମୟର ପ୍ରାଚୀନ ଶିଳାଲେଖ ଓ ଐତିହାସିକ ଜୈନ ଗୁମ୍ଫା।',
   14.0, 3, 75),
  ('pipili_village', 'odisha_golden_triangle',
   'Pipili Craft Village', 'ପିପିଲି ଚାନ୍ଦୁଆ ଗ୍ରାମ',
   'World-renowned center of vibrant applique handicrafts and traditional Jagannath canopies.',
   'ଚାନ୍ଦୁଆ ଶିଳ୍ପ ଓ ପାରମ୍ପରିକ ହସ୍ତକଳାର ବିଶ୍ୱପ୍ରସିଦ୍ଧ କେନ୍ଦ୍ର।',
   28.0, 4, 75),
  ('konark_sun_temple', 'odisha_golden_triangle',
   'Konark Sun Temple', 'କୋଣାର୍କ ସୂର୍ଯ୍ୟ ମନ୍ଦିର',
   'UNESCO World Heritage 13th-century chariot temple dedicated to Surya the Sun God.',
   'ତ୍ରୟୋଦଶ ଶତାବ୍ଦୀର ବିଶ୍ୱ ଐତିହ୍ୟ ସୂର୍ଯ୍ୟ ରଥ ମନ୍ଦିର।',
   65.0, 5, 75)
ON CONFLICT (id) DO UPDATE SET 
  name_en = EXCLUDED.name_en,
  name_or = EXCLUDED.name_or,
  km = EXCLUDED.km,
  bonus_xp = EXCLUDED.bonus_xp;
