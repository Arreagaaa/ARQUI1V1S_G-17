import { useEffect, useState, type ReactNode } from 'react';
import {
  Activity,
  AlertTriangle,
  Cloud,
  Droplets,
  Gauge,
  Rocket,
  Wifi,
  Wind,
} from 'lucide-react';
import { createEvent, createReading, controlActuator, getDashboard, getHealth } from './lib/api';
import type { ActuatorLog, CommandItem, EventItem, SensorReading, SystemStatus } from './types';

type DashboardState = {
  status: SystemStatus | null;
  recent_readings: SensorReading[];
  recent_events: EventItem[];
  recent_commands: CommandItem[];
  recent_logs: ActuatorLog[];
  mongodb: boolean;
  apiStatus: string;
};

type ActionState = {
  area: string;
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
  { key: 'gas', label: 'Gas', unit: '%' },
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
  });
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState('');
  const [reading, setReading] = useState<ReadingState>({
    area: 'area_1',
    sensor_type: 'humidity_soil',
    value: '0',
    unit: '%',
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
        const [health, data] = await Promise.all([getHealth(), getDashboard()]);
        if (!active) return;
        setDashboard({
          status: data.status,
          recent_readings: data.recent_readings,
          recent_events: data.recent_events,
          recent_commands: data.recent_commands,
          recent_logs: data.recent_logs,
          mongodb: health.mongodb,
          apiStatus: health.status,
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
    const [health, data] = await Promise.all([getHealth(), getDashboard()]);
    setDashboard({
      status: data.status,
      recent_readings: data.recent_readings,
      recent_events: data.recent_events,
      recent_commands: data.recent_commands,
      recent_logs: data.recent_logs,
      mongodb: health.mongodb,
      apiStatus: health.status,
    });
  }

  async function runAction(nextAction: ActionState) {
    setBusy(`${nextAction.actuator}-${nextAction.state}`);
    setNotice('');
    try {
      await controlActuator(nextAction.actuator, nextAction.state, nextAction.area || undefined);
      setNotice(`Acción enviada: ${nextAction.actuator} -> ${nextAction.state}`);
      await refresh();
    } catch {
      setNotice('No se pudo enviar la acción.');
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

  const quickActions = [
    { label: 'Modo auto', actuator: 'mode', state: 'auto' },
    { label: 'Modo manual', actuator: 'mode', state: 'manual' },
    { label: 'Bomba área 1', actuator: 'pump', state: 'on', area: 'area_1' },
    { label: 'Bomba área 2', actuator: 'pump', state: 'on', area: 'area_2' },
    { label: 'Ventilación', actuator: 'fan', state: 'on' },
    { label: 'Luces', actuator: 'lights', state: 'on' },
    { label: 'Silenciar', actuator: 'buzzer', state: 'mute' },
  ];

  return (
    <main className="min-h-screen bg-[var(--bg)] text-slate-100">
      <div className="absolute inset-0 bg-dashboard-grid bg-[size:24px_24px] opacity-35" />
      <div className="absolute inset-x-0 top-0 h-72 bg-[radial-gradient(circle_at_top,_rgba(16,185,129,0.22),_transparent_60%)]" />

      <section className="relative mx-auto flex min-h-screen w-full max-w-7xl flex-col gap-6 px-4 py-6 sm:px-6 lg:px-8">
        <header className="rounded-3xl border border-white/10 bg-slate-950/70 p-6 shadow-glow backdrop-blur">
          <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
            <div>
              <p className="text-sm uppercase tracking-[0.3em] text-emerald-300/90">Invernadero Inteligente IoT</p>
              <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white sm:text-4xl">
                Panel minimalista de control y monitoreo
              </h1>
              <p className="mt-3 max-w-2xl text-sm leading-6 text-slate-300 sm:text-base">
                Dashboard para operar la maqueta, registrar datos de MongoDB y disparar comandos al backend con el
                puente MQTT listo para Raspberry Pi.
              </p>
            </div>
            <div className="grid gap-3 sm:grid-cols-2">
              <StatusPill icon={<Wifi className="h-4 w-4" />} label="API" value={dashboard.apiStatus} />
              <StatusPill icon={<Cloud className="h-4 w-4" />} label="MongoDB" value={dashboard.mongodb ? 'Activo' : 'Pendiente'} />
            </div>
          </div>
          {notice ? <div className="mt-5 rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-slate-200">{notice}</div> : null}
        </header>

        <section className="grid gap-4 md:grid-cols-3 xl:grid-cols-6">
          {metricLabels.map((metric) => (
            <MetricCard
              key={metric.key}
              label={metric.label}
              value={status ? status[metric.key] : 0}
              unit={metric.unit}
            />
          ))}
        </section>

        <section className="grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
          <article className="space-y-6 rounded-3xl border border-white/10 bg-slate-950/70 p-6 backdrop-blur">
            <div className="flex items-center justify-between gap-4">
              <div>
                <h2 className="text-xl font-semibold text-white">Estado operativo</h2>
                <p className="mt-1 text-sm text-slate-400">Resumen de modo, actuadores y estado general.</p>
              </div>
              <div className={`rounded-full px-3 py-1 text-xs font-medium ${stateBadge(status?.overall_state)}`}>
                {status?.overall_state ?? 'sin datos'}
              </div>
            </div>

            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
              <ToggleCard title="Modo" value={status?.mode ?? 'auto'} icon={<Activity className="h-5 w-5" />} />
              <ToggleCard title="Bomba" value={boolLabel(status?.pump_active)} icon={<Droplets className="h-5 w-5" />} />
              <ToggleCard title="Ventilación" value={boolLabel(status?.fan_active)} icon={<Wind className="h-5 w-5" />} />
              <ToggleCard title="Alarmas" value={boolLabel(status?.buzzer_active)} icon={<AlertTriangle className="h-5 w-5" />} />
            </div>

            <section className="grid gap-4 lg:grid-cols-2">
              <Panel title="Acciones rápidas">
                <div className="grid gap-3 sm:grid-cols-2">
                  {quickActions.map((item) => (
                    <button
                      key={item.label}
                      type="button"
                      onClick={() => void runAction(item)}
                      disabled={busy === `${item.actuator}-${item.state}`}
                      className="rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-left text-sm font-medium text-white transition hover:-translate-y-0.5 hover:border-emerald-300/30 hover:bg-white/8 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      <span className="flex items-center gap-3">
                        <Rocket className="h-4 w-4 text-emerald-200" />
                        {busy === `${item.actuator}-${item.state}` ? 'Enviando...' : item.label}
                      </span>
                    </button>
                  ))}
                </div>
              </Panel>

              <Panel title="Registro manual">
                <div className="grid gap-3 sm:grid-cols-2">
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
                    <input
                      value={reading.sensor_type}
                      onChange={(event) => setReading((current) => ({ ...current, sensor_type: event.target.value }))}
                      className={inputClass}
                    />
                  </Field>
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
                  <Field label="Estado">
                    <input
                      value={reading.status}
                      onChange={(event) => setReading((current) => ({ ...current, status: event.target.value }))}
                      className={inputClass}
                    />
                  </Field>
                  <div className="flex items-end">
                    <button
                      type="button"
                      onClick={() => void submitReading()}
                      disabled={busy === 'reading'}
                      className="w-full rounded-2xl bg-emerald-400 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-300 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      {busy === 'reading' ? 'Guardando...' : 'Guardar lectura'}
                    </button>
                  </div>
                </div>
              </Panel>

              <Panel title="Evento manual">
                <div className="grid gap-3 sm:grid-cols-2">
                  <Field label="Tipo">
                    <input
                      value={eventForm.event_type}
                      onChange={(event) => setEventForm((current) => ({ ...current, event_type: event.target.value }))}
                      className={inputClass}
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
                  <Field label="Área">
                    <input
                      value={eventForm.area}
                      onChange={(event) => setEventForm((current) => ({ ...current, area: event.target.value }))}
                      className={inputClass}
                    />
                  </Field>
                  <Field label="Mensaje">
                    <input
                      value={eventForm.message}
                      onChange={(event) => setEventForm((current) => ({ ...current, message: event.target.value }))}
                      className={inputClass}
                    />
                  </Field>
                  <div className="sm:col-span-2 flex items-end">
                    <button
                      type="button"
                      onClick={() => void submitEvent()}
                      disabled={busy === 'event'}
                      className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-semibold text-white transition hover:border-emerald-300/30 hover:bg-white/8 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      {busy === 'event' ? 'Registrando...' : 'Registrar evento'}
                    </button>
                  </div>
                </div>
              </Panel>
            </section>
          </article>

          <aside className="space-y-6">
            <Panel title="Lecturas recientes">
              <Timeline items={dashboard.recent_readings.map((item) => `${item.area} · ${item.sensor_type} · ${item.value}${item.unit ?? ''}`)} emptyText="No hay lecturas todavía." />
            </Panel>

            <Panel title="Comandos recientes">
              <Timeline items={dashboard.recent_commands.map((item) => `${item.target} · ${item.command}`)} emptyText="Sin comandos registrados." />
            </Panel>

            <Panel title="Eventos y logs">
              <Timeline
                items={[
                  ...dashboard.recent_events.map((item) => `${item.event_type} · ${item.message}`),
                  ...dashboard.recent_logs.map((item) => `${item.actuator} · ${item.action}`),
                ]}
                emptyText="No hay eventos ni logs."
              />
            </Panel>

            <div className="rounded-3xl border border-emerald-400/15 bg-emerald-500/10 p-6 backdrop-blur">
              <h2 className="text-lg font-semibold text-white">MQTT y MongoDB</h2>
              <p className="mt-2 text-sm leading-6 text-emerald-50/80">
                Cada acción se guarda en MongoDB y el backend publica comandos por MQTT usando el tópico base definido
                en `.env`.
              </p>
            </div>
          </aside>
        </section>
      </section>
    </main>
  );
}

function StatusPill({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <div className="flex min-w-[180px] items-center gap-3 rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm">
      <div className="rounded-xl bg-emerald-400/15 p-2 text-emerald-200">{icon}</div>
      <div>
        <p className="text-xs uppercase tracking-[0.22em] text-slate-400">{label}</p>
        <p className="font-medium text-white">{value}</p>
      </div>
    </div>
  );
}

function MetricCard({ label, value, unit }: { label: string; value: number; unit: string }) {
  return (
    <article className="rounded-3xl border border-white/10 bg-slate-950/70 p-5 shadow-glow backdrop-blur">
      <p className="text-xs uppercase tracking-[0.22em] text-slate-400">{label}</p>
      <p className="mt-4 text-3xl font-semibold text-white">
        {value}
        <span className="ml-1 text-sm font-medium text-slate-400">{unit}</span>
      </p>
    </article>
  );
}

function ToggleCard({ title, value, icon }: { title: string; value: string; icon: ReactNode }) {
  return (
    <div className="rounded-3xl border border-white/10 bg-white/4 p-4">
      <div className="flex items-center gap-3 text-slate-300">
        <span className="rounded-xl bg-emerald-400/15 p-2 text-emerald-200">{icon}</span>
        <div>
          <p className="text-xs uppercase tracking-[0.22em] text-slate-400">{title}</p>
          <p className="mt-1 text-base font-medium text-white">{value}</p>
        </div>
      </div>
    </div>
  );
}

function Panel({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="rounded-3xl border border-white/10 bg-white/4 p-5">
      <h3 className="text-sm font-semibold uppercase tracking-[0.24em] text-emerald-200/90">{title}</h3>
      <div className="mt-4">{children}</div>
    </section>
  );
}

function Timeline({ items, emptyText }: { items: string[]; emptyText: string }) {
  if (items.length === 0) {
    return <p className="rounded-2xl border border-dashed border-white/10 px-4 py-5 text-sm text-slate-400">{emptyText}</p>;
  }

  return (
    <ul className="space-y-3 text-sm text-slate-200">
      {items.slice(0, 6).map((item, index) => (
        <li key={`${item}-${index}`} className="rounded-2xl border border-white/8 bg-white/3 px-4 py-3">
          {item}
        </li>
      ))}
    </ul>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="space-y-2 text-sm text-slate-300">
      <span className="flex items-center gap-2 text-xs uppercase tracking-[0.22em] text-slate-400">
        <Gauge className="h-3.5 w-3.5 text-emerald-200" />
        {label}
      </span>
      {children}
    </label>
  );
}

function boolLabel(value?: boolean) {
  return value ? 'activo' : 'inactivo';
}

function stateBadge(state?: string) {
  switch (state) {
    case 'emergency':
      return 'bg-red-500/15 text-red-200 ring-1 ring-red-400/30';
    case 'warning':
      return 'bg-amber-500/15 text-amber-200 ring-1 ring-amber-400/30';
    default:
      return 'bg-emerald-500/15 text-emerald-200 ring-1 ring-emerald-400/30';
  }
}
