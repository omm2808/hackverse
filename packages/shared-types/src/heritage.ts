export interface HeritageCheckpoint {
  id: string;
  journeyId: string;
  name: string;
  description: string;
  distanceFromStartKm: number;
  latitude: number;
  longitude: number;
  imageUrl?: string;
  unlockOrder: number;
}

export interface HeritageJourney {
  id: string;
  name: string;
  description: string;
  totalDistanceKm: number;
  coverImageUrl?: string;
  isActive: boolean;
  checkpoints: HeritageCheckpoint[];
}

export interface UserJourneyProgress {
  id: string;
  userId: string;
  journeyId: string;
  distanceCoveredKm: number;
  completedCheckpointsCount: number;
  isCompleted: boolean;
  updatedAt: string;
}
