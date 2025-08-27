import { HealthCheckResponse } from '@shared/types';

export interface HealthServiceInterface {
  getHealthStatus(): HealthCheckResponse;
  getLivenessStatus(): HealthCheckResponse;
  getReadinessStatus(): HealthCheckResponse;
  getStartupStatus(): HealthCheckResponse;
}
