export interface AdaptiveGoalDecision {
  previousTarget: number;
  newTarget: number;
  adjustmentPercentage: number;
  reason: string;
}

export function computeAdaptiveGoal(
  previousTarget: number,
  completionRatePercent: number
): AdaptiveGoalDecision {
  if (completionRatePercent >= 90) {
    const increment = Math.max(1, Math.round(previousTarget * 0.1));
    const newTarget = previousTarget + increment;
    return {
      previousTarget,
      newTarget,
      adjustmentPercentage: 10,
      reason: `Increased target from ${previousTarget} to ${newTarget} (+10%) because you exceeded 90% completion consistently.`,
    };
  } else if (completionRatePercent < 60) {
    const decrement = Math.max(1, Math.round(previousTarget * 0.1));
    const newTarget = Math.max(5, previousTarget - decrement);
    return {
      previousTarget,
      newTarget,
      adjustmentPercentage: -10,
      reason: `Target temporarily eased to ${newTarget} to build steady momentum and form consistency.`,
    };
  }

  return {
    previousTarget,
    newTarget: previousTarget,
    adjustmentPercentage: 0,
    reason: `Target maintained at ${previousTarget} to reinforce form and endurance.`,
  };
}
