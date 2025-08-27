import { Controller, Get } from '@nestjs/common';

import { HealthCheckResponse } from '../shared';

import { HealthService } from './health.service';

@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  getHealth(): HealthCheckResponse {
    return this.healthService.getHealthStatus();
  }
}
