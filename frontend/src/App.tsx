import { useState, useEffect } from 'react'
import { HealthCheckResponse } from '@shared/types'
import { HealthStatus } from '@shared/enums'
import { healthApi } from './api/health'
import { getFrontendConfig } from './config'
import './App.css'

function App() {
  const [healthData, setHealthData] = useState<HealthCheckResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const config = getFrontendConfig()

  useEffect(() => {
    const fetchHealthData = async () => {
      try {
        setLoading(true)
        const health = await healthApi.getHealth()
        setHealthData(health)
        setError(null)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to fetch health data')
      } finally {
        setLoading(false)
      }
    }

    fetchHealthData()
    const interval = setInterval(fetchHealthData, config.features.healthCheckInterval)

    return () => clearInterval(interval)
  }, [config.features.healthCheckInterval])

  const getStatusColor = (status: HealthStatus): string => {
    switch (status) {
      case HealthStatus.HEALTHY:
        return '#4ade80'
      case HealthStatus.DEGRADED:
        return '#facc15'
      case HealthStatus.UNHEALTHY:
        return '#f87171'
      default:
        return '#9ca3af'
    }
  }

  return (
    <div className="app">
      <h1>{config.app.name} Health Dashboard</h1>
      <div className="app-info">
        Environment: {config.app.environment} | Version: {config.app.version}
      </div>
      
      {loading && <div className="loading">Loading health data...</div>}
      
      {error && <div className="error">Error: {error}</div>}
      
      {healthData && (
        <div className="health-card">
          <div className="status" style={{ color: getStatusColor(healthData.status) }}>
            Status: {healthData.status.toUpperCase()}
          </div>
          <div className="timestamp">
            Last Updated: {new Date(healthData.timestamp).toLocaleString()}
          </div>
          <div className="uptime">
            Uptime: {Math.floor(healthData.uptime / 1000)}s
          </div>
          
          {healthData.details?.memory && (
            <div className="details">
              <h3>Memory Usage</h3>
              <div>Heap Used: {healthData.details.memory.heapUsedMB} MB</div>
              <div>Heap Total: {healthData.details.memory.heapTotalMB} MB</div>
              <div>Heap Usage: {healthData.details.memory.heapPercentage}%</div>
            </div>
          )}
          
          {healthData.details?.system && (
            <div className="details">
              <h3>System Info</h3>
              <div>Platform: {healthData.details.system.platform}</div>
              <div>CPUs: {healthData.details.system.cpus}</div>
              <div>Total Memory: {healthData.details.system.totalMemoryMB} MB</div>
              <div>Free Memory: {healthData.details.system.freeMemoryMB} MB</div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export default App
