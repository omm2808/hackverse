export type UserRole = 'USER' | 'COLLEGE_ADMIN' | 'SUPER_ADMIN';

export interface UserSummary {
  id: string;
  email: string;
  role: UserRole;
  createdAt: string;
}

export interface UserProfile {
  id: string;
  userId: string;
  displayName: string;
  avatarUrl?: string | null;
  collegeName?: string | null;
  totalXP: number;
  level: number;
  currentStreak: number;
  createdAt: string;
  updatedAt: string;
}
