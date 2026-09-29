export type XPSource = 'WORKOUT' | 'CHALLENGE' | 'HERITAGE' | 'STREAK' | 'BADGE';

export interface XPTransaction {
  id: string;
  userId: string;
  amount: number;
  source: XPSource;
  sourceId: string;
  description: string;
  createdAt: string;
}

export interface Badge {
  id: string;
  key: string;
  name: string;
  description: string;
  iconUrl?: string;
  category: string;
}

export interface UserBadge {
  id: string;
  userId: string;
  badgeId: string;
  badge: Badge;
  earnedAt: string;
}

export type ChallengeType = 'WORKOUT_COUNT' | 'REP_COUNT' | 'STREAK' | 'DISTANCE' | 'WEEKLY_GOAL';

export interface Challenge {
  id: string;
  title: string;
  description: string;
  type: ChallengeType;
  targetValue: number;
  xpReward: number;
  startDate: string;
  endDate: string;
  isActive: boolean;
}

export interface ChallengeProgress {
  id: string;
  userId: string;
  challengeId: string;
  currentValue: number;
  isCompleted: boolean;
  completedAt?: string | null;
}

export interface LeaderboardEntry {
  rank: number;
  userId: string;
  displayName: string;
  avatarUrl?: string | null;
  collegeName?: string | null;
  totalXP: number;
  level: number;
  streak: number;
}
