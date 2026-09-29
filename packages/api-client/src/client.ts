import { ApiResponse, UserProfile, WorkoutSession, ProgressSummary } from '@fit-odyssey/shared-types';

export interface ApiClientConfig {
  baseUrl: string;
  getAuthToken?: () => Promise<string | null> | string | null;
}

export class FitOdysseyApiClient {
  private baseUrl: string;
  private getAuthToken?: () => Promise<string | null> | string | null;

  constructor(config: ApiClientConfig) {
    this.baseUrl = config.baseUrl.replace(/\/$/, '');
    this.getAuthToken = config.getAuthToken;
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<ApiResponse<T>> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...((options.headers as Record<string, string>) || {}),
    };

    if (this.getAuthToken) {
      const token = await this.getAuthToken();
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }
    }

    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const errorBody = await response.json().catch(() => ({}));
      throw new Error(errorBody.message || `Request failed with status ${response.status}`);
    }

    return response.json();
  }

  // Baseline API endpoint skeletons
  async getProfile(): Promise<ApiResponse<UserProfile>> {
    return this.request<UserProfile>('/users/me');
  }

  async getWorkouts(): Promise<ApiResponse<WorkoutSession[]>> {
    return this.request<WorkoutSession[]>('/workouts');
  }

  async getProgress(): Promise<ApiResponse<ProgressSummary>> {
    return this.request<ProgressSummary>('/progress');
  }
}
