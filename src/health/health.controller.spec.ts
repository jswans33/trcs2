import { Test, TestingModule } from '@nestjs/testing';

import { MOCK_UPTIME_MS } from '@shared/constants';
import { HealthStatus } from '@shared/enums';
import { HealthCheckResponse } from '@shared/types';

import { HealthController } from './health.controller';
import { HealthService } from './health.service';

const createMockHealthResponse = (): HealthCheckResponse => ({
  status: HealthStatus.HEALTHY,
  timestamp: new Date().toISOString(),
  uptime: MOCK_UPTIME_MS,
});

const createTestModule = async (mockServiceValue: unknown): Promise<TestingModule> => {
  return Test.createTestingModule({
    controllers: [HealthController],
    providers: [
      {
        provide: HealthService,
        useValue: mockServiceValue,
      },
    ],
  }).compile();
};

describe('HealthController', () => {
  let controller: HealthController;
  let mockHealthResponse: HealthCheckResponse;
  let mockGetHealthStatus: jest.Mock;
  let mockGetLivenessStatus: jest.Mock;
  let mockGetReadinessStatus: jest.Mock;
  let mockGetStartupStatus: jest.Mock;

  beforeEach(async () => {
    mockHealthResponse = createMockHealthResponse();
    mockGetHealthStatus = jest.fn().mockReturnValue(mockHealthResponse);
    mockGetLivenessStatus = jest.fn().mockReturnValue(mockHealthResponse);
    mockGetReadinessStatus = jest.fn().mockReturnValue(mockHealthResponse);
    mockGetStartupStatus = jest.fn().mockReturnValue(mockHealthResponse);

    const mockServiceValue = {
      getHealthStatus: mockGetHealthStatus,
      getLivenessStatus: mockGetLivenessStatus,
      getReadinessStatus: mockGetReadinessStatus,
      getStartupStatus: mockGetStartupStatus,
    };

    const module = await createTestModule(mockServiceValue);
    controller = module.get<HealthController>(HealthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('should return health status', () => {
    const result = controller.getHealth();

    expect(result).toEqual(mockHealthResponse);
    expect(mockGetHealthStatus).toHaveBeenCalled();
  });

  it('should return liveness status', () => {
    const result = controller.getLiveness();

    expect(result).toEqual(mockHealthResponse);
    expect(mockGetLivenessStatus).toHaveBeenCalled();
  });

  it('should return readiness status', () => {
    const result = controller.getReadiness();

    expect(result).toEqual(mockHealthResponse);
    expect(mockGetReadinessStatus).toHaveBeenCalled();
  });

  it('should return startup status', () => {
    const result = controller.getStartup();

    expect(result).toEqual(mockHealthResponse);
    expect(mockGetStartupStatus).toHaveBeenCalled();
  });
});
