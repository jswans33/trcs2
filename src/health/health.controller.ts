import { Controller, Get } from '@nestjs/common';
import { HealthService } from './health.service';
import { HealthCheckResponse } from '../shared';

@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  getHealth(): HealthCheckResponse {
    return this.healthService.getHealthStatus();
  }
}