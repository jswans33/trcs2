import { Test } from '@nestjs/testing';

import { AppModule } from './app.module';
import { HealthModule } from './health/health.module';

describe('AppModule', () => {
  it('should compile the module', async () => {
    const module = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    expect(module).toBeDefined();
  });

  it('should import HealthModule', () => {
    const imports = Reflect.getMetadata('imports', AppModule) as (typeof HealthModule)[];
    expect(imports).toContain(HealthModule);
  });
});
