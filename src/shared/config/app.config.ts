import { DEFAULT_PORT } from '../constants';

export interface AppConfig {
  port: number;
  environment: string;
  cors: {
    origin: string[];
    credentials: boolean;
  };
  api: {
    prefix: string;
    version: string;
  };
}

export const getAppConfig = (): AppConfig => ({
  port: parseInt(process.env['PORT'] ?? DEFAULT_PORT.toString(), 10),
  environment: process.env['NODE_ENV'] ?? 'development',
  cors: {
    origin:
      process.env['CORS_ORIGINS'] !== null && process.env['CORS_ORIGINS'] !== undefined
        ? process.env['CORS_ORIGINS'].split(',')
        : ['http://localhost:3000'],
    credentials: true,
  },
  api: {
    prefix: process.env['API_PREFIX'] ?? '',
    version: process.env['API_VERSION'] ?? 'v1',
  },
});
