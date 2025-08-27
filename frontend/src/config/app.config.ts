export interface FrontendConfig {
  api: {
    baseUrl: string;
    timeout: number;
  };
  app: {
    name: string;
    version: string;
    environment: string;
  };
  features: {
    healthCheckInterval: number;
  };
}

export const getFrontendConfig = (): FrontendConfig => ({
  api: {
    baseUrl: import.meta.env.VITE_API_BASE_URL || 'http://localhost:4000',
    timeout: parseInt(import.meta.env.VITE_API_TIMEOUT || '10000', 10),
  },
  app: {
    name: import.meta.env.VITE_APP_NAME || 'TRCS2',
    version: import.meta.env.VITE_APP_VERSION || '1.0.0',
    environment: import.meta.env.MODE || 'development',
  },
  features: {
    healthCheckInterval: parseInt(import.meta.env.VITE_HEALTH_CHECK_INTERVAL || '30000', 10),
  },
});