import { HealthStatus } from '../enums/health.enum';

export interface HealthCheckResponse {
  status: HealthStatus;
  timestamp: string;
  uptime: number;
  details?: HealthDetails;
}

export interface HealthDetails {
  memory?: MemoryInfo;
  system?: SystemInfo;
  database?: DatabaseInfo;
}

export interface MemoryInfo {
  heapUsedMB: number;
  heapTotalMB: number;
  heapPercentage: number;
}

export interface SystemInfo {
  platform: string;
  cpus: number;
  totalMemoryMB: number;
  freeMemoryMB: number;
}

export interface DatabaseInfo {
  connected: boolean;
  responseTimeMs?: number;
}
