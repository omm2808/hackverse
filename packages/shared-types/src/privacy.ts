export interface PrivacyPreference {
  id: string;
  userId: string;
  cameraDataLocalOnly: boolean;
  shareLocation: boolean;
  showOnLeaderboard: boolean;
  allowAggregateAnalytics: boolean;
  updatedAt: string;
}
