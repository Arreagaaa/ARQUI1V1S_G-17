import { useEffect, useState, type ReactNode } from 'react';
import {
  Activity,
  AlertTriangle,
  Cloud,
  Droplets,
  Radio,
  Rocket,
  Wifi,
  Wind,
  LineChart,
  Cpu,
  RefreshCw,
  Sun,
} from 'lucide-react';
import {
  createEvent,
  createReading,
  controlActuator,
  getDashboard,
  getHealth,
  getARM64Results,
  generateMockARM64Results,
  seedDatabase,
  controlMode,
  controlIrrigation,
  controlLights,
  controlFan,
  controlAlarm,
} from './lib/api';
import type { ActuatorLog, CommandItem, EventItem, SensorReading, SystemStatus, ARM64Result } from './types';

type DashboardState = {
  status: SystemStatus | null;
  recent_readings: SensorReading[];
  recent_events: EventItem[];
  recent_commands: CommandItem[];
  recent_logs: ActuatorLog[];
  mongodb: boolean;
  apiStatus: string;
  arm64_results: Record<string, ARM64Result> | null;
};

type ActionState = {
  area?: string;
  actuator: string;
  state: string;
};

type ReadingState = {
  area: string;
  sensor_type: string;
  value: string;
  unit: string;
  status: string;
};

type EventState = {
  event_type: string;
  severity: string;
  message: string;
  area: string;
};

const metricLabels: Array<{ key: keyof SystemStatus; label: string; unit: string }> = [
  { key: 'temperature', label: 'Temperatura', unit: '°C' },
  { key: 'humidity', label: 'Humedad', unit: '%' },
  { key: 'soil_1', label: 'Suelo área 1', unit: '%' },
  { key: 'soil_2', label: 'Suelo área 2', unit: '%' },
  { key: 'light', label: 'Luz', unit: '%' },
  { key: 'gas', label: 'Gas', unit: 'ppm' },
];

const inputClass =
  'w-full rounded-2xl border border-white/10 bg-slate-950/60 px-4 py-3 text-sm text-white outline-none transition placeholder:text-slate-500 focus:border-emerald-300/40 focus:ring-2 focus:ring-emerald-400/20';

export default function App() {
  const [dashboard, setDashboard] = useState<DashboardState>({
    status: null,
    recent_readings: [],
    recent_events: [],
    recent_commands: [],
    recent_logs: [],
    mongodb: false,
    apiStatus: 'Cargando...',
    arm64_results: null,
  });
  const [mqttStatus, setMqttStatus] = useState<{ enabled: boolean; connected: boolean }>({
    enabled: false,
    connected: false,
  });
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState('');
  const [activeTab, setActiveTab] = useState<string>('temperature');

  const [reading, setReading] = useState<ReadingState>({
    area: 'area_1',
    sensor_type: 'temperature',
    value: '25',
    unit: '°C',
    status: 'normal',
  });
  const [eventForm, setEventForm] = useState<EventState>({
    event_type: 'status_change',
    severity: 'info',
    message: '',
    area: 'area_1',
  });

  useEffect(() => {
    let active = true;

    async function load() {
      try {
        const [health, data, arm64] = await Promise.all([getHealth(), getDashboard(), getARM64Results()]);
        if (!active) return;
        setDashboard({
          status: data.status,
          recent_readings: data.recent_readings,
          recent_events: data.recent_events,
          recent_commands: data.recent_commands,
          recent_logs: data.recent_logs,
          mongodb: health.mongodb,
          apiStatus: health.status,
          arm64_results: arm64,
        });
        setMqttStatus({
          enabled: health.mqtt_enabled,
          connected: health.mqtt_connected,
        });
      } catch {
        if (!active) return;
        setDashboard((current) => ({ ...current, apiStatus: 'Sin conexión' }));
      }
    }

    void load();
    const interval = window.setInterval(() => void load(), 15000);
    return () => {
      active = false;
      window.clearInterval(interval);
    };
  }, []);

  const status = dashboard.status;

  async function refresh() {
    try {
      const [health, data, arm64] = await Promise.all([getHealth(), getDashboard(), getARM64Results()]);
      setDashboard({
        status: data.status,
        recent_readings: data.recent_readings,
        recent_events: data.recent_events,
        recent_commands: data.recent_commands,
        recent_logs: data.recent_logs,
        mongodb: health.mongodb,
        apiStatus: health.status,
        arm64_results: arm64,
      });
      setMqttStatus({
        enabled: health.mqtt_enabled,
        connected: health.mqtt_connected,
      });
    } catch {
      setDashboard((current) => ({ ...current, apiStatus: 'Sin conexión' }));
    }
  }

  async function runAction(nextAction: ActionState) {
    const key = `${nextAction.actuator}-${nextAction.state}-${nextAction.area || ''}`;
    setBusy(key);
    setNotice('');
    try {
      if (nextAction.actuator === 'mode') {
        await controlMode(nextAction.state as 'auto' | 'manual');
      } else if (nextAction.actuator === 'pump') {
        await controlIrrigation(nextAction.state as 'on' | 'off', nextAction.area);
      } else if (nextAction.actuator === 'lights') {
        await controlLights(nextAction.state as 'on' | 'off', nextAction.area);
      } else if (nextAction.actuator === 'fan') {
        await controlFan(nextAction.state as 'on' | 'off', nextAction.area);
      } else if (nextAction.actuator === 'buzzer') {
        await controlAlarm(nextAction.state as 'on' | 'off' | 'mute', nextAction.area);
      } else {
        await controlActuator(nextAction.actuator, nextAction.state, nextAction.area || undefined);
      }
      setNotice(`Acción enviada: ${nextAction.actuator} -> ${nextAction.state} ${nextAction.area ? `(${nextAction.area})` : ''}`);
      await refresh();
    } catch {
      setNotice('No se pudo enviar la acción.');
    } finally {
      setBusy(null);
    }
  }

  async function handleSeedDatabase() {
    setBusy('seed');
    setNotice('');
    try {
      const res = await seedDatabase();
      setNotice(`Base de datos sembrada con éxito.`);
      await refresh();
    } catch {
      setNotice('Error al sembrar la base de datos.');
    } finally {
      setBusy(null);
    }
  }

  async function submitReading() {
    setBusy('reading');
    setNotice('');
    try {
      await createReading({
        area: reading.area,
        sensor_type: reading.sensor_type,
        value: Number(reading.value),
        unit: reading.unit,
        status: reading.status,
      });
      setNotice('Lectura guardada en MongoDB.');
      await refresh();
    } catch {
      setNotice('No se pudo guardar la lectura.');
    } finally {
      setBusy(null);
    }
  }

  async function submitEvent() {
    setBusy('event');
    setNotice('');
    try {
      await createEvent({
        event_type: eventForm.event_type,
        message: eventForm.message,
        severity: eventForm.severity,
        area: eventForm.area,
      });
      setNotice('Evento registrado.');
      await refresh();
    } catch {
      setNotice('No se pudo registrar el evento.');
    } finally {
      setBusy(null);
    }
  }

  async function handleGenerateMockARM64() {
    setBusy('arm64-mock');
    setNotice('');
    try {
      await generateMockARM64Results();
      setNotice('Resultados de análisis ARM64 de prueba generados en la base de datos.');
      await refresh();
    } catch {
      setNotice('Error al generar los resultados de análisis ARM64.');
    } finally {
      setBusy(null);
    }
  }

  // Map sensor select option to pre-populate units
  const handleSensorTypeChange = (type: string) => {
    let unit = '';
    let val = '0';
    if (type === 'temperature') { unit = '°C'; val = '25'; }
    else if (type === 'humidity') { unit = '%'; val = '60'; }
    else if (type.startsWith('soil_')) { unit = '%'; val = '45'; }
    else if (type === 'light') { unit = '%'; val = '50'; }
    else if (type === 'gas') { unit = 'ppm'; val = '120'; }
    
    setReading(curr => ({ ...curr, sensor_type: type, unit, value: val }));
  };

  const quickActions = [
    { label: 'Modo automático', actuator: 'mode', state: 'auto' },
    { label: 'Modo manual', actuator: 'mode', state: 'manual' },
    { label: 'Bomba Área 1 ON', actuator: 'pump', state: 'on', area: 'area_1' },
    { label: 'Bomba Área 1 OFF', actuator: 'pump', state: 'off', area: 'area_1' },
    { label: 'Bomba Área 2 ON', actuator: 'pump', state: 'on', area: 'area_2' },
    { label: 'Bomba Área 2 OFF', actuator: 'pump', state: 'off', area: 'area_2' },
    { label: 'Ventilación ON', actuator: 'fan', state: 'on' },
    { label: 'Ventilación OFF', actuator: 'fan', state: 'off' },
    { label: 'Luces ON', actuator: 'lights', state: 'on' },
    { label: 'Luces OFF', actuator: 'lights', state: 'off' },
    { label: 'Silenciar buzzer', actuator: 'buzzer', state: 'mute' },
    { label: 'Activar buzzer', actuator: 'buzzer', state: 'on' },
  ];

  return (
    <main className="min-h-screen bg-[var(--bg)] text-slate-100 pb-12">
      <div className="absolute inset-0 bg-dashboard-grid bg-[size:24px_24px] opacity-35" />
      <div className="absolute inset-x-0 top-0 h-72 bg-[radial-gradient(circle_at_top,_rgba(16,185,129,0.22),_transparent_60%)]" />

      <section className="relative mx-auto flex min-h-screen w-full max-w-7xl flex-col gap-6 px-4 py-6 sm:px-6 lg:px-8">
        <header className="rounded-3xl border border-white/10 bg-slate-950/70 p-5 sm:p-6 shadow-glow backdrop-blur">
          <div className="flex flex-col gap-5 xl:flex-row xl:items-end xl:justify-between">
            <div className="min-w-0">
              <p className="text-xs sm:text-sm uppercase tracking-[0.3em] text-emerald-300/90">Invernadero Inteligente IoT</p>
              <h1 className="mt-2 text-2xl sm:text-3xl lg:text-4xl font-semibold tracking-tight text-white">
                Panel de control y monitoreo inteligente
              </h1>
              <p className="mt-3 max-w-2xl text-sm leading-6 text-slate-300">
                Dashboard web para controlar la maqueta, registrar históricos en MongoDB Compass/Atlas y auditar los módulos ARM64.
              </p>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-center xl:flex-nowrap">
              <button
                type="button"
                onClick={() => void handleSeedDatabase()}
                disabled={busy !== null}
                className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-2xl bg-emerald-400 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-300 disabled:cursor-not-allowed disabled:opacity-60"
              >
                <RefreshCw className={`h-4 w-4 ${busy === 'seed' ? 'animate-spin' : ''}`} />
                <span>Inicializar DB</span>
              </button>
              <div className="grid grid-cols-3 gap-2 sm:gap-3 w-full sm:w-auto sm:flex">
                <StatusPill icon={<Wifi className="h-4 w-4" />} label="API" value={dashboard.apiStatus} />
                <StatusPill icon={<Cloud className="h-4 w-4" />} label="MongoDB" value={dashboard.mongodb ? 'Activo' : 'Pendiente'} />
                <StatusPill
                  icon={<Radio className="h-4 w-4" />}
                  label="MQTT"
                  value={!mqttStatus.enabled ? 'Off' : mqttStatus.connected ? 'OK' : 'Sync'}
                />
              </div>
            </div>
          </div>
          {notice ? (
            <div className="mt-5 flex items-center justify-between gap-3 rounded-2xl border border-emerald-400/20 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-200">
              <span className="break-words">{notice}</span>
              <button onClick={() => setNotice('')} className="shrink-0 text-emerald-400 hover:text-emerald-200">✕</button>
            </div>
          ) : null}
        </header>

        {/* Métricas en Tiempo Real */}
        <section className="grid grid-cols-2 gap-3 sm:gap-4 md:grid-cols-3 xl:grid-cols-6">
          {metricLabels.map((metric) => (
            <MetricCard
              key={metric.key}
              label={metric.label}
              value={status ? status[metric.key] as number : 0}
              unit={metric.unit}
              active={activeTab === metric.key}
              onClick={() => setActiveTab(metric.key as string)}
            />
          ))}
        </section>

        {/* Gráfico Histórico */}
        <section className="rounded-3xl border border-white/10 bg-slate-950/70 p-5 sm:p-6 backdrop-blur">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between mb-4">
            <div>
              <h2 className="text-lg sm:text-xl font-semibold text-white flex items-center gap-2">
                <LineChart className="h-5 w-5 text-emerald-400 shrink-0" />
                <span>Histórico de Sensor</span>
              </h2>
              <p className="mt-1 text-xs text-slate-400">
                Visualización en tiempo real de los datos almacenados en MongoDB.
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              {metricLabels.map((tab) => (
                <button
                  key={tab.key}
                  onClick={() => setActiveTab(tab.key as string)}
                  className={`px-2.5 sm:px-3 py-1.5 rounded-xl text-[11px] sm:text-xs font-semibold transition ${
                    activeTab === tab.key
                      ? 'bg-emerald-400 text-slate-950 shadow-glow'
                      : 'border border-white/10 bg-white/5 text-slate-300 hover:bg-white/10'
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </div>
          </div>
          <div className="pt-4 border-t border-white/5">
            <SensorChart
              readings={dashboard.recent_readings}
              metricKey={activeTab}
              label={metricLabels.find((m) => m.key === activeTab)?.label || activeTab}
              unit={metricLabels.find((m) => m.key === activeTab)?.unit || ''}
            />
          </div>
        </section>

        {/* Estado Operativo, Acciones y Logs */}
        <section className="grid gap-6 xl:grid-cols-[1.25fr_0.75fr]">
          <article className="space-y-6 rounded-3xl border border-white/10 bg-slate-950/70 p-5 sm:p-6 backdrop-blur">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="text-lg sm:text-xl font-semibold text-white">Estado operativo actual</h2>
                <p className="mt-1 text-xs sm:text-sm text-slate-400">Resumen del modo, actuadores y estado del sistema.</p>
              </div>
              <div className={`self-start sm:self-auto rounded-full px-3 py-1 text-xs font-medium ${stateBadge(status?.overall_state)}`}>
                {status?.overall_state ?? 'sin datos'}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3 sm:gap-4 md:grid-cols-3 xl:grid-cols-5">
              <ToggleCard title="Modo" value={status?.mode ?? 'auto'} icon={<Activity className="h-4 w-4" />} />
              <ToggleCard title="Bomba de Riego" value={boolLabel(status?.pump_active)} icon={<Droplets className="h-4 w-4" />} />
              <ToggleCard title="Ventilación" value={boolLabel(status?.fan_active)} icon={<Wind className="h-4 w-4" />} />
              <ToggleCard title="Iluminación" value={boolLabel(status?.lights_active)} icon={<Sun className="h-4 w-4" />} />
              <ToggleCard title="Alarma Sonora" value={boolLabel(status?.buzzer_active)} icon={<AlertTriangle className="h-4 w-4" />} />
            </div>

            <section className="grid gap-4 lg:grid-cols-2">
              <Panel title="Acciones rápidas (Control manual)">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 max-h-[320px] overflow-y-auto pr-1 scrollbar-thin">
                  {quickActions.map((item) => {
                    const key = `${item.actuator}-${item.state}-${item.area || ''}`;
                    const isBusy = busy === key;
                    return (
                      <button
                        key={key}
                        type="button"
                        onClick={() => void runAction(item)}
                        disabled={busy !== null}
                        className="rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-left text-xs font-medium text-white transition hover:-translate-y-0.5 hover:border-emerald-300/30 hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-60"
                      >
                        <span className="flex items-start gap-2">
                          <Rocket className="h-3.5 w-3.5 mt-0.5 text-emerald-300 shrink-0" />
                          <span className="leading-snug break-words">{isBusy ? 'Enviando...' : item.label}</span>
                        </span>
                      </button>
                    );
                  })}
                </div>
              </Panel>

              <Panel title="Registro manual de lectura">
                <div className="grid gap-2 text-xs">
                  <Field label="Área">
                    <select
                      value={reading.area}
                      onChange={(event) => setReading((current) => ({ ...current, area: event.target.value }))}
                      className={inputClass}
                    >
                      <option value="area_1">Área 1</option>
                      <option value="area_2">Área 2</option>
                      <option value="control">Centro de control</option>
                    </select>
                  </Field>
                  <Field label="Sensor">
                    <select
                      value={reading.sensor_type}
                      onChange={(event) => handleSensorTypeChange(event.target.value)}
                      className={inputClass}
                    >
                      <option value="temperature">Temperatura</option>
                      <option value="humidity">Humedad Ambiente</option>
                      <option value="soil_1">Suelo Área 1</option>
                      <option value="soil_2">Suelo Área 2</option>
                      <option value="light">Iluminación (LDR)</option>
                      <option value="gas">Detección de Gas (MQ)</option>
                    </select>
                  </Field>
                  <div className="grid grid-cols-2 gap-2">
                    <Field label="Valor">
                      <input
                        value={reading.value}
                        onChange={(event) => setReading((current) => ({ ...current, value: event.target.value }))}
                        className={inputClass}
                        type="number"
                        step="0.1"
                      />
                    </Field>
                    <Field label="Unidad">
                      <input
                        value={reading.unit}
                        onChange={(event) => setReading((current) => ({ ...current, unit: event.target.value }))}
                        className={inputClass}
                      />
                    </Field>
                  </div>
                  <div className="flex items-end mt-2">
                    <button
                      type="button"
                      onClick={() => void submitReading()}
                      disabled={busy !== null}
                      className="w-full rounded-2xl bg-emerald-400 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-300 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      {busy === 'reading' ? 'Guardando...' : 'Guardar lectura'}
                    </button>
                  </div>
                </div>
              </Panel>
            </section>

            <section className="border-t border-white/5 pt-4">
              <Panel title="Registrar evento manual">
                <div className="grid gap-3 sm:grid-cols-2">
                  <Field label="Tipo de Evento">
                    <input
                      value={eventForm.event_type}
                      onChange={(event) => setEventForm((current) => ({ ...current, event_type: event.target.value }))}
                      className={inputClass}
                      placeholder="status_change"
                    />
                  </Field>
                  <Field label="Severidad">
                    <select
                      value={eventForm.severity}
                      onChange={(event) => setEventForm((current) => ({ ...current, severity: event.target.value }))}
                      className={inputClass}
                    >
                      <option value="info">info</option>
                      <option value="warning">warning</option>
                      <option value="critical">critical</option>
                    </select>
                  </Field>
                  <div className="sm:col-span-2 grid gap-3 sm:grid-cols-2">
                    <Field label="Área Relacionada">
                      <input
                        value={eventForm.area}
                        onChange={(event) => setEventForm((current) => ({ ...current, area: event.target.value }))}
                        className={inputClass}
                        placeholder="area_1"
                      />
                    </Field>
                    <Field label="Mensaje de Alerta">
                      <input
                        value={eventForm.message}
                        onChange={(event) => setEventForm((current) => ({ ...current, message: event.target.value }))}
                        className={inputClass}
                        placeholder="Alerta de sensor activada"
                      />
                    </Field>
                  </div>
                  <div className="sm:col-span-2 flex items-end">
                    <button
                      type="button"
                      onClick={() => void submitEvent()}
                      disabled={busy !== null}
                      className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-semibold text-white transition hover:border-emerald-300/30 hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      {busy === 'event' ? 'Registrando...' : 'Registrar evento'}
                    </button>
                  </div>
                </div>
              </Panel>
            </section>
          </article>

          {/* Historiales y Timelines */}
          <aside className="space-y-6">
            <Panel title="Lecturas Recientes">
              <Timeline items={dashboard.recent_readings.slice(0, 8).map((item) => `${item.area} · ${item.sensor_type} · ${item.value}${item.unit ?? ''}`)} emptyText="No hay lecturas registradas." />
            </Panel>

            <Panel title="Comandos Recientes">
              <Timeline items={dashboard.recent_commands.map((item) => `${item.target} · ${item.command}`)} emptyText="Sin comandos registrados." />
            </Panel>

            <Panel title="Eventos y Logs del Invernadero">
              <Timeline
                items={[
                  ...dashboard.recent_events.map((item) => `[${(item.severity ?? 'info').toUpperCase()}] ${item.message}`),
                  ...dashboard.recent_logs.map((item) => `[LOG] Actuador: ${item.actuator} -> ${item.action}`),
                ]}
                emptyText="No hay eventos ni logs."
              />
            </Panel>
          </aside>
        </section>

        {/* Sección Análisis ARM64 */}
        <ARM64ResultsSection
          results={dashboard.arm64_results}
          onGenerateMock={() => void handleGenerateMockARM64()}
          loading={busy === 'arm64-mock'}
        />

        {/* Nota MQTT */}
        <footer className="rounded-3xl border border-emerald-400/15 bg-emerald-500/10 p-5 sm:p-6 backdrop-blur">
          <h2 className="text-base sm:text-lg font-semibold text-white flex items-center gap-2">
            <RefreshCw className="h-5 w-5 text-emerald-400 animate-spin-slow shrink-0" />
            <span>Fase Pre-ARM y Pre-Maqueta Completada</span>
          </h2>
          <p className="mt-2 text-sm leading-6 text-emerald-50/80">
            Toda la arquitectura web está lista. El backend tiene implementada la lógica de automatización y umbrales para simular las lecturas y activar el estado global de MongoDB. Cuando se conecte la Raspberry Pi por MQTT, el sistema operará automáticamente. El contrato MQTT ha quedado documentado.
          </p>
        </footer>
      </section>
    </main>
  );
}

function StatusPill({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <div className="flex flex-1 min-w-[100px] items-center gap-2.5 rounded-2xl border border-white/10 bg-white/5 px-3 sm:px-3.5 py-2.5 text-sm">
      <div className="shrink-0 rounded-lg bg-emerald-400/15 p-1.5 text-emerald-200">{icon}</div>
      <div className="min-w-0 leading-tight">
        <p className="text-[9px] sm:text-[10px] uppercase tracking-[0.12em] sm:tracking-[0.14em] text-slate-400 whitespace-nowrap">{label}</p>
        <p className="font-semibold text-white text-xs sm:text-sm whitespace-nowrap">{value}</p>
      </div>
    </div>
  );
}

function MetricCard({ label, value, unit, active, onClick }: { label: string; value: number; unit: string; active: boolean; onClick: () => void }) {
  return (
    <article
      onClick={onClick}
      className={`rounded-2xl sm:rounded-3xl border p-4 sm:p-5 cursor-pointer shadow-glow backdrop-blur transition-all duration-300 ${
        active
          ? 'border-emerald-400/50 bg-emerald-500/10'
          : 'border-white/10 bg-slate-950/70 hover:border-emerald-400/30'
      }`}
    >
      <p className="text-[10px] sm:text-xs uppercase tracking-[0.18em] sm:tracking-[0.22em] text-slate-400">{label}</p>
      <p className="mt-3 sm:mt-4 text-2xl sm:text-3xl font-semibold text-white break-words">
        {value !== undefined ? (typeof value === 'number' ? value.toFixed(1).replace('.0', '') : value) : '0'}
        <span className="ml-1 text-xs sm:text-sm font-medium text-slate-400">{unit}</span>
      </p>
    </article>
  );
}

function ToggleCard({ title, value, icon }: { title: string; value: string; icon: ReactNode }) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-3 sm:p-4 flex flex-col items-center text-center gap-2">
      <span className="rounded-lg bg-emerald-400/15 p-1.5 text-emerald-300">{icon}</span>
      <div className="min-w-0 w-full">
        <p className="text-[9px] sm:text-[10px] uppercase tracking-[0.16em] sm:tracking-[0.2em] text-slate-400 leading-tight break-words">{title}</p>
        <p className="mt-1 text-xs sm:text-sm font-semibold text-white break-words leading-tight">{value}</p>
      </div>
    </div>
  );
}

function Panel({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="rounded-2xl sm:rounded-3xl border border-white/10 bg-white/5 p-4 sm:p-5">
      <h3 className="text-xs sm:text-sm font-semibold uppercase tracking-[0.2em] sm:tracking-[0.24em] text-emerald-200/90">{title}</h3>
      <div className="mt-4">{children}</div>
    </section>
  );
}

function Timeline({ items, emptyText }: { items: string[]; emptyText: string }) {
  if (items.length === 0) {
    return <p className="rounded-2xl border border-dashed border-white/10 px-4 py-5 text-sm text-slate-400">{emptyText}</p>;
  }

  return (
    <ul className="space-y-2 text-[11px] sm:text-xs text-slate-200">
      {items.slice(0, 6).map((item, index) => (
        <li key={`${item}-${index}`} className="rounded-2xl border border-white/10 bg-white/5 px-3 py-2 leading-relaxed break-words">
          {item}
        </li>
      ))}
    </ul>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="block text-sm text-slate-300">
      <span className="block text-[10px] sm:text-xs font-semibold uppercase tracking-[0.18em] sm:tracking-[0.22em] text-emerald-300/80 mb-1.5">
        {label}
      </span>
      {children}
    </label>
  );
}

function boolLabel(value?: boolean) {
  return value ? 'Activo' : 'Inactivo';
}

function stateBadge(state?: string) {
  switch (state?.toUpperCase()) {
    case 'EMERGENCIA':
      return 'bg-red-500/15 text-red-200 ring-1 ring-red-400/30 font-bold';
    case 'ADVERTENCIA':
      return 'bg-amber-500/15 text-amber-200 ring-1 ring-amber-400/30 font-bold';
    case 'RIEGO_ACTIVO':
      return 'bg-cyan-500/15 text-cyan-200 ring-1 ring-cyan-400/30 font-bold';
    case 'MODO_MANUAL':
      return 'bg-purple-500/15 text-purple-200 ring-1 ring-purple-400/30 font-bold';
    default:
      return 'bg-emerald-500/15 text-emerald-200 ring-1 ring-emerald-400/30 font-bold';
  }
}

const getChartDataForMetric = (metricKey: string, readings: SensorReading[]) => {
  const typeMatches: Record<string, string[]> = {
    temperature: ['temperature', 'temperatura'],
    humidity: ['humidity', 'humedad', 'humedad_ambiente'],
    soil_1: ['soil_1', 'humidity_soil_1', 'humedad_suelo_area1'],
    soil_2: ['soil_2', 'humidity_soil_2', 'humedad_suelo_area2'],
    light: ['light', 'luz'],
    gas: ['gas']
  };

  const matches = typeMatches[metricKey] || [metricKey];
  let filtered = readings.filter(r => 
    matches.some(m => r.sensor_type.toLowerCase().includes(m))
  );

  if (metricKey === 'soil_1') {
    filtered = readings.filter(r => 
      matches.some(m => r.sensor_type.toLowerCase().includes(m)) && r.area === 'area_1'
    );
  } else if (metricKey === 'soil_2') {
    filtered = readings.filter(r => 
      matches.some(m => r.sensor_type.toLowerCase().includes(m)) && r.area === 'area_2'
    );
  }
  
  return [...filtered].reverse();
};

function SensorChart({ readings, metricKey, label, unit }: { readings: SensorReading[], metricKey: string, label: string, unit: string }) {
  const data = getChartDataForMetric(metricKey, readings);
  
  if (data.length === 0) {
    return (
      <div className="flex h-48 items-center justify-center rounded-3xl border border-dashed border-white/10 bg-slate-950/40 p-4">
        <p className="text-xs text-slate-400 text-center">Sin lecturas históricas para {label}. Inserta datos en el panel de registro manual.</p>
      </div>
    );
  }

  const width = 600;
  const height = 150;
  const paddingLeft = 40;
  const paddingRight = 20;
  const paddingTop = 15;
  const paddingBottom = 25;

  const minVal = 0;
  let maxVal = Math.max(...data.map(d => d.value), 10);
  if (['humidity', 'soil_1', 'soil_2', 'light'].includes(metricKey)) {
    maxVal = 100;
  } else if (metricKey === 'temperature') {
    maxVal = Math.max(maxVal, 40);
  } else if (metricKey === 'gas') {
    maxVal = Math.max(maxVal, 200);
  }

  const getX = (index: number) => {
    if (data.length <= 1) return paddingLeft + (width - paddingLeft - paddingRight) / 2;
    return paddingLeft + (index / (data.length - 1)) * (width - paddingLeft - paddingRight);
  };

  const getY = (val: number) => {
    const scale = (height - paddingTop - paddingBottom) / (maxVal - minVal);
    return height - paddingBottom - (val - minVal) * scale;
  };

  const points = data.map((d, i) => `${getX(i)},${getY(d.value)}`);
  const pathD = points.length > 0 ? `M ${points.join(' L ')}` : '';
  const areaD = points.length > 0 
    ? `${pathD} L ${getX(data.length - 1)},${height - paddingBottom} L ${getX(0)},${height - paddingBottom} Z` 
    : '';

  const colors: Record<string, { stroke: string, fill: string }> = {
    temperature: { stroke: 'stroke-rose-400', fill: 'url(#gradient-temp)' },
    humidity: { stroke: 'stroke-cyan-400', fill: 'url(#gradient-humidity)' },
    soil_1: { stroke: 'stroke-emerald-400', fill: 'url(#gradient-soil)' },
    soil_2: { stroke: 'stroke-teal-400', fill: 'url(#gradient-soil2)' },
    light: { stroke: 'stroke-amber-400', fill: 'url(#gradient-light)' },
    gas: { stroke: 'stroke-purple-400', fill: 'url(#gradient-gas)' },
  };

  const chartColor = colors[metricKey] || { stroke: 'stroke-emerald-400', fill: 'url(#gradient-soil)' };

  return (
    <div className="w-full">
      <div className="w-full" style={{ aspectRatio: '600 / 160' }}>
        <svg
          viewBox={`0 0 ${width} ${height}`}
          preserveAspectRatio="xMidYMid meet"
          className="w-full h-full overflow-visible"
        >
          <defs>
            <linearGradient id="gradient-temp" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#fb7185" stopOpacity="0.25"/>
              <stop offset="100%" stopColor="#fb7185" stopOpacity="0.0"/>
            </linearGradient>
            <linearGradient id="gradient-humidity" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#22d3ee" stopOpacity="0.25"/>
              <stop offset="100%" stopColor="#22d3ee" stopOpacity="0.0"/>
            </linearGradient>
            <linearGradient id="gradient-soil" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#34d399" stopOpacity="0.25"/>
              <stop offset="100%" stopColor="#34d399" stopOpacity="0.0"/>
            </linearGradient>
            <linearGradient id="gradient-soil2" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#2dd4bf" stopOpacity="0.25"/>
              <stop offset="100%" stopColor="#2dd4bf" stopOpacity="0.0"/>
            </linearGradient>
            <linearGradient id="gradient-light" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#fbbf24" stopOpacity="0.25"/>
              <stop offset="100%" stopColor="#fbbf24" stopOpacity="0.0"/>
            </linearGradient>
            <linearGradient id="gradient-gas" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#c084fc" stopOpacity="0.25"/>
              <stop offset="100%" stopColor="#c084fc" stopOpacity="0.0"/>
            </linearGradient>
          </defs>

          {/* Y Axis Grid */}
          {[0, 0.5, 1].map((ratio, i) => {
            const val = minVal + ratio * (maxVal - minVal);
            const y = getY(val);
            return (
              <g key={i} className="opacity-15">
                <line x1={paddingLeft} y1={y} x2={width - paddingRight} y2={y} stroke="white" strokeWidth="1" strokeDasharray="3 3" />
                <text x={paddingLeft - 8} y={y + 3} textAnchor="end" fill="white" className="text-[9px] font-mono">{val.toFixed(0)}{unit}</text>
              </g>
            );
          })}

          {/* X Axis labels */}
          {data.map((d, i) => {
            if (data.length > 5 && i % Math.floor(data.length / 4) !== 0 && i !== data.length - 1) return null;
            const timeStr = d.recorded_at ? new Date(d.recorded_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }) : '';
            const x = getX(i);
            return (
              <g key={i} className="opacity-25">
                <line x1={x} y1={height - paddingBottom} x2={x} y2={height - paddingBottom + 3} stroke="white" strokeWidth="1" />
                <text x={x} y={height - paddingBottom + 13} textAnchor="middle" fill="white" className="text-[8px] font-mono">{timeStr}</text>
              </g>
            );
          })}

          {/* Filled Area */}
          <path d={areaD} fill={chartColor.fill} />

          {/* Line Path */}
          <path d={pathD} fill="none" className={`${chartColor.stroke}`} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />

          {/* Point Dots */}
          {data.map((d, i) => (
            <g key={i} className="group cursor-pointer">
              <circle cx={getX(i)} cy={getY(d.value)} r="3" className={`${chartColor.stroke} fill-slate-950`} strokeWidth="1.5" />
              <circle cx={getX(i)} cy={getY(d.value)} r="6" className={`${chartColor.stroke} opacity-0 hover:opacity-15`} strokeWidth="3" />
              <title>{`${d.value}${unit} a las ${d.recorded_at ? new Date(d.recorded_at).toLocaleTimeString() : ''}`}</title>
            </g>
          ))}
        </svg>
      </div>
    </div>
  );
}

function ARM64ResultsSection({
  results,
  onGenerateMock,
  loading
}: {
  results: Record<string, ARM64Result> | null;
  onGenerateMock: () => void;
  loading: boolean;
}) {
  const modulesList = [
    {
      key: 'WEIGHTED_MEAN',
      title: 'Media ponderada',
      responsable: 'Integrante 1',
      file: 'modulo_1_media.s',
      outputFile: 'resultado_media.txt',
      formula: 'MEDIA = Σ(X_i * W_i) / ΣW_i',
      fields: [
        { label: 'Suma de lecturas (SUM_X)', key: 'SUM_X' },
        { label: 'Suma de pesos (WEIGHT_SUM)', key: 'WEIGHT_SUM' },
        { label: 'Media ponderada (WEIGHTED_MEAN)', key: 'WEIGHTED_MEAN', highlight: true }
      ]
    },
    {
      key: 'VARIANCE',
      title: 'Varianza y Desv. Estándar',
      responsable: 'Integrante 2',
      file: 'modulo_2_varianza.s',
      outputFile: 'resultado_varianza.txt',
      formula: 'VAR = Σ(X - MEDIA)²/N',
      fields: [
        { label: 'Media (MEAN)', key: 'MEAN' },
        { label: 'Varianza (VARIANCE)', key: 'VARIANCE', highlight: true },
        { label: 'Desviación estándar (STD_DEV)', key: 'STD_DEV', highlight: true }
      ]
    },
    {
      key: 'ANOMALY_DETECTION',
      title: 'Detección de anomalías',
      responsable: 'Integrante 3',
      file: 'modulo_3_anomalias.s',
      outputFile: 'resultado_anomalias.txt',
      formula: 'Z = (X - MEDIA)/DESV',
      fields: [
        { label: 'Media (MEAN)', key: 'MEAN' },
        { label: 'Desviación estándar (STD_DEV)', key: 'STD_DEV' },
        { label: 'Anomalías (ANOMALIES)', key: 'ANOMALIES', highlight: true },
        { label: 'Riesgo (SYSTEM_RISK)', key: 'SYSTEM_RISK', badge: true }
      ]
    },
    {
      key: 'PREDICTION',
      title: 'Predicción lineal simple',
      responsable: 'Integrante 4',
      file: 'modulo_4_prediccion.s',
      outputFile: 'resultado_prediccion.txt',
      formula: 'PRED = XF + (XF - XI)/(N-1)',
      fields: [
        { label: 'Val Inicial (INITIAL_VALUE)', key: 'INITIAL_VALUE' },
        { label: 'Val Final (FINAL_VALUE)', key: 'FINAL_VALUE' },
        { label: 'Dif (TOTAL_DIFF)', key: 'TOTAL_DIFF' },
        { label: 'Cambio (AVG_CHANGE)', key: 'AVG_CHANGE' },
        { label: 'Predicción (NEXT_VALUE)', key: 'NEXT_VALUE', highlight: true }
      ]
    },
    {
      key: 'ADVANCED_TREND',
      title: 'Tendencia avanzada',
      responsable: 'Integrante 5',
      file: 'modulo_5_tendencia.s',
      outputFile: 'resultado_tendencia.txt',
      formula: 'DIF_ACUM = Σ(X_i - X_(i-1))',
      fields: [
        { label: 'Incrementos (INCREMENTS)', key: 'INCREMENTS' },
        { label: 'Decrementos (DECREMENTS)', key: 'DECREMENTS' },
        { label: 'Racha subida (MAX_UP_STREAK)', key: 'MAX_UP_STREAK' },
        { label: 'Dif Acum (ACCUM_DIFF)', key: 'ACCUM_DIFF' },
        { label: 'Tendencia (TREND)', key: 'TREND', badge: true }
      ]
    }
  ];

  const hasData = results && Object.keys(results).length > 0;

  return (
    <article className="space-y-6 rounded-2xl sm:rounded-3xl border border-white/10 bg-slate-950/70 p-5 sm:p-6 backdrop-blur">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-lg sm:text-xl font-semibold text-white flex items-center gap-2">
            <Cpu className="h-5 w-5 text-emerald-400 shrink-0" />
            <span>Análisis Estadístico ARM64</span>
          </h2>
          <p className="mt-1 text-xs text-slate-400">
            Resultados calculados en ensamblador AArch64 ejecutados localmente en la Raspberry Pi 3.
          </p>
        </div>
        <button
          type="button"
          onClick={onGenerateMock}
          disabled={loading}
          className="w-full sm:w-auto inline-flex items-center justify-center rounded-2xl bg-emerald-400 px-4 py-2 text-xs font-semibold text-slate-950 transition hover:bg-emerald-300 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {loading ? 'Generando...' : 'Generar datos de prueba ARM64'}
        </button>
      </div>

      {!hasData ? (
        <div className="flex flex-col items-center justify-center py-10 px-4 rounded-2xl border border-dashed border-white/10 bg-slate-950/30">
          <p className="text-xs text-slate-400 text-center max-w-sm">
            Ningún análisis ARM64 ha sido reportado en MongoDB. Presiona el botón superior para poblar la colección y previsualizar la interfaz.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5 gap-4">
          {modulesList.map((mod) => {
            const modData = results?.[mod.key];
            return (
              <div
                key={mod.key}
                className="rounded-2xl border border-white/10 bg-white/4 p-4 flex flex-col justify-between"
              >
                <div>
                  <h3 className="text-xs font-bold text-emerald-300 min-h-[32px]">
                    {mod.title}
                  </h3>
                  <div className="mt-1 text-[9px] text-slate-400 flex flex-col gap-0.5 leading-none">
                    <span>{mod.responsable}</span>
                    <span>Arch: {mod.file}</span>
                    <span>Salida: {mod.outputFile}</span>
                  </div>
                  <div className="mt-2 rounded bg-slate-950/60 p-1.5 text-[8px] font-mono text-slate-300 overflow-x-auto whitespace-nowrap scrollbar-thin">
                    {mod.formula}
                  </div>

                  <div className="mt-4 space-y-2">
                    {modData ? (
                      mod.fields.map((f) => {
                        const val = modData.results?.[f.key];
                        return (
                          <div key={f.key} className="flex items-center justify-between text-[10px] border-b border-white/5 pb-1">
                            <span className="text-slate-400">{f.label.split(' (')[0]}</span>
                            {f.badge ? (
                              <span className={`px-1.5 py-0.5 rounded text-[8px] font-bold ${
                                val === 'HIGH' || val === 'DOWN' ? 'bg-red-500/20 text-red-300' :
                                val === 'MEDIUM' ? 'bg-amber-500/20 text-amber-300' :
                                val === 'NORMAL' || val === 'UP' ? 'bg-emerald-500/20 text-emerald-300' :
                                'bg-slate-500/20 text-slate-300'
                              }`}>
                                {val ?? 'N/A'}
                              </span>
                            ) : (
                              <span className={`font-mono font-medium ${f.highlight ? 'text-emerald-400 font-bold' : 'text-slate-200'}`}>
                                {val !== undefined ? (typeof val === 'number' ? val.toFixed(1).replace('.0', '') : val) : 'N/A'}
                              </span>
                            )}
                          </div>
                        );
                      })
                    ) : (
                      <div className="text-center py-4 text-[10px] text-slate-500">
                        Esperando ejecución...
                      </div>
                    )}
                  </div>
                </div>
                {modData && (
                  <div className="mt-4 pt-2 border-t border-white/5 text-[8px] text-slate-500 flex justify-between items-center leading-none">
                    <span>Origen: {modData.source}</span>
                    <span>
                      {modData.created_at
                        ? new Date(modData.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                        : ''}
                    </span>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </article>
  );
}
