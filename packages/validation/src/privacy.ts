import { z } from 'zod';

export const updatePrivacySchema = z.object({
  cameraDataLocalOnly: z.boolean().optional(),
  shareLocation: z.boolean().optional(),
  showOnLeaderboard: z.boolean().optional(),
  allowAggregateAnalytics: z.boolean().optional(),
});

export type UpdatePrivacyInput = z.infer<typeof updatePrivacySchema>;
