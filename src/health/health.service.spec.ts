import { Test, TestingModule } from '@nestjs/testing';

import { ZERO } from '@shared/constants';
import { HealthStatus } from '@shared/enums';

import { HealthService } from './health.service';

describe('HealthService', () => {
  let service: HealthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [HealthService],
    }).compile();

    service = module.get<HealthService>(HealthService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getHealthStatus', () => {
    it('should return healthy status', () => {
      const result = service.getHealthStatus();

      expect(result.status).toBe(HealthStatus.HEALTHY);
      expect(result.timestamp).toBeDefined();
      expect(result.uptime).toBeGreaterThanOrEqual(ZERO);
    });
  });

  describe('getLivenessStatus', () => {
    it('should return healthy liveness status', () => {
      const result = service.getLivenessStatus();

      expect(result.status).toBe(HealthStatus.HEALTHY);
      expect(result.timestamp).toBeDefined();
      expect(result.uptime).toBeGreaterThanOrEqual(ZERO);
    });
  });

  describe('getReadinessStatus', () => {
    it('should return readiness with memory details', () => {
      const result = service.getReadinessStatus();

      expect(result.timestamp).toBeDefined();
      expect(result.uptime).toBeGreaterThanOrEqual(ZERO);
      expect(result.details?.memory).toBeDefined();
    });
  });

  describe('getStartupStatus', () => {
    it('should return startup with system info', () => {
      const result = service.getStartupStatus();

      expect(result.status).toBe(HealthStatus.HEALTHY);
      expect(result.timestamp).toBeDefined();
      expect(result.details?.system).toBeDefined();
    });
  });
});
