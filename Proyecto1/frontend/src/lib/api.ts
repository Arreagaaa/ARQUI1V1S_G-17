import type { ActuatorLog, CommandItem, EventItem, SensorReading, SystemStatus, ARM64Result } from '../types';

const baseUrl = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000';

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${baseUrl}${path}`, init);
  if (!response.ok) {
    throw new Error(`Request failed: ${response.status}`);
  }
  return response.json() as Promise<T>;
}

export async function getDashboard() {
  return request<{
    status: SystemStatus;
    recent_readings: SensorReading[];
    recent_events: EventItem[];
    recent_commands: CommandItem[];
    recent_logs: ActuatorLog[];
  }>("/api/dashboard");
}

export async function getHealth() {
  return request<{ status: string; mongodb: boolean; mqtt_enabled: boolean; mqtt_connected: boolean; timestamp: string }>("/api/health");
}

export async function createCommand(payload: CommandItem) {
  return request<unknown>("/api/commands", {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
}

export async function createReading(payload: SensorReading) {
  return request<unknown>("/api/readings", {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ ...payload, source: 'web' }),
  });
}

export async function createEvent(payload: EventItem) {
  return request<unknown>("/api/events", {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
}

export async function controlActuator(actuator: string, state: string, area?: string) {
  const params = new URLSearchParams({ state });
  if (area) params.set('area', area);
  return request<unknown>(`/api/control/${encodeURIComponent(actuator)}?${params.toString()}`, {
    method: 'POST',
  });
}

export async function getARM64Results() {
  return request<Record<string, ARM64Result>>("/api/arm64-results/latest");
}

export async function generateMockARM64Results() {
  return request<unknown>("/api/arm64-results/mock", {
    method: 'POST',
  });
}

export async function seedDatabase() {
  return request<{ status: string; message: string; details: Record<string, number> }>("/api/seed", {
    method: 'POST',
  });
}

export async function controlIrrigation(state: 'on' | 'off', area?: string) {
  return request<unknown>("/api/control/irrigation", {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ state, area, source: 'web' }),
  });
}

export async function controlLights(state: 'on' | 'off', area?: string) {
  return request<unknown>("/api/control/lights", {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ state, area, source: 'web' }),
  });
}

export async function controlFan(state: 'on' | 'off', area?: string) {
  return request<unknown>("/api/control/fan", {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ state, area, source: 'web' }),
  });
}

export async function controlAlarm(state: 'on' | 'off' | 'mute', area?: string) {
  return request<unknown>("/api/control/alarm", {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ state, area, source: 'web' }),
  });
}

export async function controlMode(mode: 'auto' | 'manual') {
  return request<unknown>("/api/control/mode", {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ mode, source: 'web' }),
  });
}


