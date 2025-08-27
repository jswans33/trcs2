import { HealthStatus } from '../enums/health.enum';

export interface HealthCheckResponse {
  status: HealthStatus;
  timestamp: string;
  uptime: number;
}