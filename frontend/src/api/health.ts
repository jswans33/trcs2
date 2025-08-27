import { HealthCheckResponse } from '@shared/types'
import { getFrontendConfig } from '../config'

const config = getFrontendConfig()

const fetchWithTimeout = async (url: string): Promise<Response> => {
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), config.api.timeout)
  
  try {
    const response = await fetch(url, { signal: controller.signal })
    clearTimeout(timeoutId)
    return response
  } catch (error) {
    clearTimeout(timeoutId)
    throw error
  }
}

export const healthApi = {
  getHealth: async (): Promise<HealthCheckResponse> => {
    const response = await fetchWithTimeout(`${config.api.baseUrl}/health`)
    if (!response.ok) {
      throw new Error(`Health check failed: ${response.status}`)
    }
    return response.json()
  },

  getLiveness: async (): Promise<HealthCheckResponse> => {
    const response = await fetchWithTimeout(`${config.api.baseUrl}/health/live`)
    if (!response.ok) {
      throw new Error(`Liveness check failed: ${response.status}`)
    }
    return response.json()
  },

  getReadiness: async (): Promise<HealthCheckResponse> => {
    const response = await fetchWithTimeout(`${config.api.baseUrl}/health/ready`)
    if (!response.ok) {
      throw new Error(`Readiness check failed: ${response.status}`)
    }
    return response.json()
  },

  getStartup: async (): Promise<HealthCheckResponse> => {
    const response = await fetchWithTimeout(`${config.api.baseUrl}/health/startup`)
    if (!response.ok) {
      throw new Error(`Startup check failed: ${response.status}`)
    }
    return response.json()
  },
}