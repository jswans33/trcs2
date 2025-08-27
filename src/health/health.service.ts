import { Injectable } from '@nestjs/common';
import { HealthCheckResponse, HealthStatus } from '../shared';

@Injectable()
export class HealthService {
  private readonly startTime: number = Date.now();

  getHealthStatus(): HealthCheckResponse {
    return {
      status: HealthStatus.HEALTHY,
      timestamp: new Date().toISOString(),
      uptime: Date.now() - this.startTime,
    };
  }
}