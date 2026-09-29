import { NormalizedLandmarks, Point3D } from './types';

export class LandmarkSmoother {
  private previousLandmarks: NormalizedLandmarks | null = null;
  private alpha: number;

  /**
   * @param alpha Smoothing factor between 0 (max smoothing) and 1 (no smoothing). Default 0.6.
   */
  constructor(alpha = 0.6) {
    this.alpha = alpha;
  }

  smooth(current: NormalizedLandmarks): NormalizedLandmarks {
    if (!this.previousLandmarks || this.previousLandmarks.length !== current.length) {
      this.previousLandmarks = current.map((p) => ({ ...p }));
      return current;
    }

    const smoothed: NormalizedLandmarks = current.map((p, idx) => {
      const prev = this.previousLandmarks![idx] as Point3D;
      return {
        x: this.alpha * p.x + (1 - this.alpha) * prev.x,
        y: this.alpha * p.y + (1 - this.alpha) * prev.y,
        z: this.alpha * p.z + (1 - this.alpha) * prev.z,
        visibility: p.visibility,
      };
    });

    this.previousLandmarks = smoothed;
    return smoothed;
  }

  reset(): void {
    this.previousLandmarks = null;
  }
}
