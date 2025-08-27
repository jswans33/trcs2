import { Controller, Get } from '@nestjs/common';

import { HealthCheckResponse } from '../shared';

import { HealthService } from './health.service';

@Controller('health')
export class HealthController {
  /* istanbul ignore next */
  constructor(private readonly healthService: HealthService) {}

  @Get()
  getHealth(): HealthCheckResponse {
    return this.healthService.getHealthStatus();
  }

  @Get('live')
  getLiveness(): HealthCheckResponse {
    return this.healthService.getLivenessStatus();
  }

  @Get('ready')
  getReadiness(): HealthCheckResponse {
    return this.healthService.getReadinessStatus();
  }

  @Get('startup')
  getStartup(): HealthCheckResponse {
    return this.healthService.getStartupStatus();
  }
}
