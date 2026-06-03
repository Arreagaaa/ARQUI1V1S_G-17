export type SensorReading = {
  area: string;
  sensor_type: string;
  value: number;
  unit?: string;
  status?: string;
  recorded_at?: string;
};

export type EventItem = {
  event_type: string;
  message: string;
  severity?: string;
  area?: string;
  created_at?: string;
};

export type CommandItem = {
  command: string;
  target: string;
  source?: string;
  payload?: Record<string, unknown>;
  created_at?: string;
};

export type ActuatorLog = {
  actuator: string;
  action: string;
  source?: string;
  area?: string;
  payload?: Record<string, unknown>;
  created_at?: string;
};

export type SystemStatus = {
  mode: string;
  overall_state: string;
  temperature: number;
  humidity: number;
  soil_1: number;
  soil_2: number;
  light: number;
  gas: number;
  pump_active: boolean;
  fan_active: boolean;
  lights_active: boolean;
  buzzer_active: boolean;
  updated_at?: string;
};

export type CommandPayload = {
  command: string;
  target: string;
  source: string;
  payload: Record<string, unknown>;
};

export type ARM64Result = {
  _id?: string;
  module: string;
  total_values: number;
  results: Record<string, number | string>;
  source: string;
  created_at?: string;
};


