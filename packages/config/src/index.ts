export const APP_CONFIG = {
  NAME: 'Fit Odyssey',
  TAGLINE: "Your smartphone becomes your AI fitness coach, while your activity becomes a journey through Odisha's heritage.",
  VERSION: '1.0.0',
} as const;

export const DEFAULT_PORTS = {
  API: 3001,
  WEB: 3000,
  MOBILE: 8081,
} as const;

export const EXERCISE_KEYS = {
  SQUAT: 'SQUAT',
  PUSHUP: 'PUSHUP',
  PLANK: 'PLANK',
} as const;

export const XP_RULES = {
  WORKOUT_COMPLETION_BASE: 50,
  XP_PER_REP: 2,
  CHECKPOINT_REACHED: 75,
  STREAK_7_DAYS: 150,
  STREAK_30_DAYS: 500,
  CHALLENGE_DEFAULT: 200,
} as const;

export const HERITAGE_RULES = {
  DISTANCE_PER_REP_KM: 0.05,
  DISTANCE_PER_ACTIVE_MINUTE_KM: 0.1,
  DISTANCE_PER_WORKOUT_BONUS_KM: 0.5,
} as const;
