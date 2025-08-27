import * as os from 'os';

import { Injectable } from '@nestjs/common';

import { BYTES_PER_MB, HEAP_THRESHOLD_PERCENT, PERCENTAGE } from '../shared/constants';
import { HealthStatus } from '../shared/enums';
import { HealthCheckResponse } from '../shared/types';

import { HealthServiceInterface } from './health.interface';

@Injectable()
export class HealthService implements HealthServiceInterface {
  private readonly startTime: Date = new Date();

  getHealthStatus(): HealthCheckResponse {
    return {
      status: HealthStatus.HEALTHY,
      timestamp: new Date().toISOString(),
      uptime: this.getUptimeMs(),
    };
  }

  getLivenessStatus(): HealthCheckResponse {
    // Liveness: Is the process alive and not deadlocked?
    return {
      status: HealthStatus.HEALTHY,
      timestamp: new Date().toISOString(),
      uptime: this.getUptimeMs(),
    };
  }

  getReadinessStatus(): HealthCheckResponse {
    // Readiness: Can we handle requests? Check memory pressure
    const memoryUsage = process.memoryUsage();
    const heapUsedMB = Math.round(memoryUsage.heapUsed / BYTES_PER_MB);
    const heapTotalMB = Math.round(memoryUsage.heapTotal / BYTES_PER_MB);
    const heapPercentage = Math.round((memoryUsage.heapUsed / memoryUsage.heapTotal) * PERCENTAGE);

    // Consider unhealthy if heap usage is over threshold
    const isHealthy = heapPercentage < HEAP_THRESHOLD_PERCENT;
    return {
      status: isHealthy ? HealthStatus.HEALTHY : HealthStatus.DEGRADED,
      timestamp: new Date().toISOString(),
      uptime: this.getUptimeMs(),
      details: {
        memory: {
          heapUsedMB,
          heapTotalMB,
          heapPercentage,
        },
      },
    };
  }

  getStartupStatus(): HealthCheckResponse {
    // Startup: Initial health check during startup
    // In production, this would check database connections, external services, etc.
    const systemInfo = {
      platform: os.platform(),
      cpus: os.cpus().length,
      totalMemoryMB: Math.round(os.totalmem() / BYTES_PER_MB),
      freeMemoryMB: Math.round(os.freemem() / BYTES_PER_MB),
    };

    return {
      status: HealthStatus.HEALTHY,
      timestamp: new Date().toISOString(),
      uptime: this.getUptimeMs(),
      details: {
        system: systemInfo,
      },
    };
  }

  private getUptimeMs(): number {
    return Date.now() - this.startTime.getTime();
  }
}
