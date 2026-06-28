import { useEffect, useRef, useState, type ReactNode } from 'react';
import {
  Activity,
  AlertTriangle,
  Cloud,
  Droplets,
  Lock,
  LogOut,
  Radio,
  Rocket,
  Wifi,
  Wind,
  LineChart,
  Cpu,
  RefreshCw,
  Sun,
  Settings2,
} from 'lucide-react';
import {
  controlActuator,
  getDashboard,
  getHealth,
  getARM64Results,
  generateMockARM64Results,
  generateARM64CSV,
  triggerARM64Run,
  seedDatabase,
  controlMode,
  controlIrrigation,
  controlLights,
  controlFan,
  controlAlarm,
  getARM64ColumnConfig,
  setARM64ColumnConfig,
  runHistoricalAnalysis,
  baseUrl,
} from './lib/api';
import { mqttClient, BASE_TOPIC } from './lib/mqttClient';
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
  const arm64PollRef = useRef<number | null>(null);
  const [activeTab, setActiveTab] = useState<string>('temperature');

  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [authUser, setAuthUser] = useState('');
  const [pumpArea, setPumpArea] = useState<string>('area_1');

  const [histForm, setHistForm] = useState({
    file: 'lecturas.csv',
    start_line: '1',
    end_line: '30',
    column: '1',
    ideal_value: '55',
    module: 'RMSE',
  });

  useEffect(() => {
    let active = true;

    // Conectar MQTT para tiempo real
    mqttClient.connect();

    mqttClient.onConnect(() => {
      if (!active) return;
      setMqttStatus({ enabled: true, connected: true });
    });

    mqttClient.onDisconnect(() => {
      if (!active) return;
      setMqttStatus({ enabled: true, connected: false });
    });

    // Suscribir a topics de sensores y estado global
    mqttClient.subscribe('sensores/#', (topic, payload) => {
      if (!active) return;
      setDashboard((prev) => ({
        ...prev,
        recent_readings: [
          { sensor_type: payload.sensor_type as string, value: payload.value as number, unit: payload.unit as string, area: payload.area as string, recorded_at: payload.timestamp as string },
          ...prev.recent_readings,
        ].slice(0, 30),
      }));
    });

    mqttClient.subscribe('estado/global', (_topic, payload) => {
      if (!active) return;
      setDashboard((prev) => ({
        ...prev,
        status: {
          mode: payload.mode as string,
          overall_state: payload.overall_state as string,
          irrigation_state: payload.irrigation_state as string || 'RIEGO_OFF',
          ventilation_state: payload.ventilation_state as string || 'VENTILACION_OFF',
          gas_state: payload.gas_state as string || 'GAS_NORMAL',
          temperature: payload.temperature as number,
          humidity: payload.humidity as number,
          soil_1: payload.soil_1 as number,
          soil_2: payload.soil_2 as number,
          light: payload.light as number,
          gas: payload.gas as number,
          pump_active: payload.pump_active as boolean,
          fan_active: payload.fan_active as boolean,
          lights_active: payload.lights_active as boolean,
          buzzer_active: payload.buzzer_active as boolean,
          updated_at: payload.timestamp as string,
        },
      }));
    });

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
      if (arm64PollRef.current) window.clearInterval(arm64PollRef.current);
      mqttClient.disconnect();
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
      // Publicar comando vía MQTT también
      mqttClient.publish('control/remoto', {
        command: `set_${nextAction.actuator}`,
        target: nextAction.actuator,
        source: 'dashboard',
        payload: { state: nextAction.state, area: nextAction.area },
        timestamp: new Date().toISOString(),
      });

      // Los cambios de modo también se publican en control/manual (topic dedicado)
      if (nextAction.actuator === 'mode') {
        mqttClient.publish('control/manual', {
          command: `set_${nextAction.actuator}`,
          target: nextAction.actuator,
          source: 'dashboard',
          payload: { state: nextAction.state, area: nextAction.area },
          timestamp: new Date().toISOString(),
        });
      }

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

  async function handleSeedDatabase(force: boolean = false) {
    setBusy('seed');
    setNotice('');
    try {
      const res = await seedDatabase(force);
      setNotice(res.message);
      await refresh();
    } catch {
      setNotice('Error al sembrar la base de datos.');
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

  async function handlePrepareARM64Data() {
    setBusy('arm64-prep');
    setNotice('');
    try {
      const res = await generateARM64CSV();
      setNotice(res.message);
    } catch {
      setNotice('Error al preparar datos ARM64.');
    } finally {
      setBusy(null);
    }
  }

  async function handleRunARM64() {
    setBusy('arm64-run');
    setNotice('');
    if (arm64PollRef.current) window.clearInterval(arm64PollRef.current);
    try {
      const res = await triggerARM64Run();
      setNotice(res.message);
      let count = 0;
      arm64PollRef.current = window.setInterval(async () => {
        count++;
        await refresh();
        if (count >= 20) {
          if (arm64PollRef.current) window.clearInterval(arm64PollRef.current);
          arm64PollRef.current = null;
          setBusy(null);
          setNotice('Análisis ARM64 finalizado. Refresca la página para confirmar todos los resultados.');
        }
      }, 3000);
    } catch {
      setNotice('Error al ejecutar análisis ARM64 en la Pi.');
      setBusy(null);
    }
  }

  async function handleRunHistoricalAnalysis() {
    setBusy('hist-analysis');
    setNotice('');
    try {
      const res = await runHistoricalAnalysis({
        file: histForm.file,
        start_line: Number(histForm.start_line),
        end_line: Number(histForm.end_line),
        column: Number(histForm.column),
        ideal_value: Number(histForm.ideal_value),
        module: histForm.module,
      });
      setNotice(res.message);
    } catch {
      setNotice('Error al enviar solicitud de análisis histórico.');
    } finally {
      setBusy(null);
    }
  }

  const quickActions = [
    { label: 'Modo automático', actuator: 'mode', state: 'auto' },
    { label: 'Modo manual', actuator: 'mode', state: 'manual' },
    { label: `Riego ${pumpArea === 'area_1' ? 'Área 1' : 'Área 2'} ON`, actuator: 'pump', state: 'on', area: pumpArea },
    { label: `Riego ${pumpArea === 'area_1' ? 'Área 1' : 'Área 2'} OFF`, actuator: 'pump', state: 'off', area: pumpArea },
    { label: 'Apagar bomba (sin área)', actuator: 'pump', state: 'off' },
    { label: 'Ventilación ON', actuator: 'fan', state: 'on' },
    { label: 'Ventilación OFF', actuator: 'fan', state: 'off' },
    { label: 'Luces ON', actuator: 'lights', state: 'on' },
    { label: 'Luces OFF', actuator: 'lights', state: 'off' },
    { label: 'Silenciar buzzer', actuator: 'buzzer', state: 'mute' },
    { label: 'Activar buzzer', actuator: 'buzzer', state: 'on' },
  ];

  if (!isAuthenticated) {
    return <LoginPage onLogin={(user) => { setIsAuthenticated(true); setAuthUser(user); }} />;
  }

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
                onClick={() => void handleSeedDatabase(false)}
                disabled={busy !== null}
                title="Sembrar colecciones vacías (no destruye comandos del usuario)"
                className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-2xl bg-emerald-400 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-300 disabled:cursor-not-allowed disabled:opacity-60"
              >
                <RefreshCw className={`h-4 w-4 ${busy === 'seed' ? 'animate-spin' : ''}`} />
                <span>Sembrar BD</span>
              </button>
              <button
                type="button"
                onClick={() => {
                  if (window.confirm('Borrar TODOS los datos (incluidos comandos y logs de MQTTX) y re-sembrar? Esta acción NO se puede deshacer.')) {
                    void handleSeedDatabase(true);
                  }
                }}
                disabled={busy !== null}
                title="Borrar todas las colecciones y re-sembrar (DESTRUCTIVO)"
                className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-2xl border border-rose-400/60 bg-rose-500/10 px-4 py-3 text-sm font-semibold text-rose-200 transition hover:bg-rose-500/20 disabled:cursor-not-allowed disabled:opacity-60"
              >
                <RefreshCw className={`h-4 w-4 ${busy === 'seed-clear' ? 'animate-spin' : ''}`} />
                <span>Borrar y sembrar</span>
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
              <button
                type="button"
                onClick={() => { setIsAuthenticated(false); setAuthUser(''); }}
                className="w-full sm:w-auto inline-flex items-center justify-center gap-2 rounded-2xl border border-rose-400/60 bg-rose-500/10 px-4 py-3 text-sm font-semibold text-rose-200 transition hover:bg-rose-500/20"
              >
                <LogOut className="h-4 w-4" />
                <span className="hidden sm:inline">Salir</span>
              </button>
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
                  className={`px-2.5 sm:px-3 py-1.5 rounded-xl text-[11px] sm:text-xs font-semibold transition ${activeTab === tab.key
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

        {/* Estado Operativo y Acciones */}
        <section className="rounded-3xl border border-white/10 bg-slate-950/70 p-5 sm:p-6 backdrop-blur">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 className="text-lg sm:text-xl font-semibold text-white">Estado operativo actual</h2>
              <p className="mt-1 text-xs sm:text-sm text-slate-400">Resumen del modo, actuadores y estado del sistema.</p>
            </div>
            <div className={`self-start sm:self-auto rounded-full px-3 py-1 text-xs font-medium ${stateBadge(status?.overall_state)}`}>
              {status?.overall_state ?? 'sin datos'}
            </div>
          </div>

          <div className="mt-6 grid grid-cols-2 gap-3 sm:gap-4 md:grid-cols-3 xl:grid-cols-5">
            <ToggleCard title="Modo" value={status?.mode ?? 'auto'} icon={<Activity className="h-4 w-4" />} />
            <ToggleCard title="Bomba de Riego (1 compartida)" value={boolLabel(status?.pump_active)} icon={<Droplets className="h-4 w-4" />} />
            <ToggleCard title="Ventilación" value={boolLabel(status?.fan_active)} icon={<Wind className="h-4 w-4" />} />
            <ToggleCard title="Iluminación" value={boolLabel(status?.lights_active)} icon={<Sun className="h-4 w-4" />} />
            <ToggleCard title="Alarma Sonora" value={boolLabel(status?.buzzer_active)} icon={<AlertTriangle className="h-4 w-4" />} />
          </div>
          <div className="mt-4 grid grid-cols-3 gap-2 text-xs">
            <div className="rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-center">
              <span className="text-[9px] uppercase tracking-wider text-slate-400">Riego</span>
              <p className="mt-1 font-semibold text-white">{status?.irrigation_state ?? '—'}</p>
            </div>
            <div className="rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-center">
              <span className="text-[9px] uppercase tracking-wider text-slate-400">Ventilación</span>
              <p className="mt-1 font-semibold text-white">{status?.ventilation_state ?? '—'}</p>
            </div>
            <div className="rounded-2xl border border-white/10 bg-white/5 px-3 py-2 text-center">
              <span className="text-[9px] uppercase tracking-wider text-slate-400">Gas</span>
              <p className="mt-1 font-semibold text-white">{status?.gas_state ?? '—'}</p>
            </div>
          </div>

          <div className="mt-6">
            <Panel title="Acciones rápidas (Control manual)">
              <div className="mb-3 flex items-center gap-2 text-xs">
                <span className="text-slate-400">Área riego:</span>
                <select
                  value={pumpArea}
                  onChange={(e) => setPumpArea(e.target.value)}
                  className="rounded-xl border border-white/10 bg-slate-950/60 px-3 py-1.5 text-white outline-none focus:border-emerald-300/40"
                >
                  <option value="area_1">Área 1</option>
                  <option value="area_2">Área 2</option>
                </select>
                <span className="text-slate-500">(1 bomba compartida)</span>
              </div>
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
          </div>
        </section>

        {/* Motor ARM64 - Decisiones en Vivo */}
        <section className="rounded-3xl border border-white/10 bg-slate-950/70 p-5 sm:p-6 backdrop-blur">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 className="text-lg sm:text-xl font-semibold text-white flex items-center gap-2">
                <Activity className="h-5 w-5 text-emerald-400 shrink-0" />
                <span>Motor ARM64 - Decisiones en Vivo</span>
              </h2>
              <p className="mt-1 text-xs text-slate-400">
                Ultima decisión generada por el motor ARM64 en ensamblador AArch64.
              </p>
            </div>
          </div>

          {dashboard.arm64_results?.LIVE_ENGINE ? (
            (() => {
              const m = dashboard.arm64_results!.LIVE_ENGINE.results;
              const action = (m?.ACTION as string) || '';
              const risk = (m?.RISK as string) || 'LOW';
              const riskColor =
                risk === 'CRITICAL' ? 'bg-red-500/20 text-red-300 border-red-400/30' :
                risk === 'HIGH' ? 'bg-rose-500/20 text-rose-300 border-rose-400/30' :
                risk === 'MEDIUM' ? 'bg-amber-500/20 text-amber-300 border-amber-400/30' :
                'bg-emerald-500/20 text-emerald-300 border-emerald-400/30';
              const actionColor = (a: string) => {
                switch (a) {
                  case 'ALARM_ON': return 'bg-red-500/20 text-red-300 border-red-400/30';
                  case 'GAS_WARNING': return 'bg-amber-500/20 text-amber-300 border-amber-400/30';
                  case 'RIEGO_1_ON':
                  case 'RIEGO_2_ON': return 'bg-sky-500/20 text-sky-300 border-sky-400/30';
                  case 'LIGHT_ON': return 'bg-yellow-500/20 text-yellow-300 border-yellow-400/30';
                  case 'FAN_ON': return 'bg-slate-500/20 text-slate-300 border-slate-400/30';
                  case 'LED_GREEN': return 'bg-emerald-500/20 text-emerald-300 border-emerald-400/30';
                  case 'LED_YELLOW': return 'bg-amber-400/20 text-amber-200 border-amber-400/30';
                  default: return riskColor;
                }
              };
              return (
                <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7 gap-3 mt-4">
                  <div className={`rounded-2xl border ${actionColor(action)} p-3 col-span-2 sm:col-span-1`}>
                    <p className="text-[9px] uppercase tracking-wider opacity-70">ACCION</p>
                    <p className="mt-1 text-lg font-bold">{action || '—'}</p>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-3">
                    <p className="text-[9px] uppercase tracking-wider text-slate-400">TARGET</p>
                    <p className="mt-1 text-sm font-semibold text-white">{m?.TARGET ?? '—'}</p>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-3">
                    <p className="text-[9px] uppercase tracking-wider text-slate-400">RIESGO</p>
                    <p className={`mt-1 text-sm font-bold ${risk === 'CRITICAL' ? 'text-red-300' : risk === 'HIGH' ? 'text-rose-300' : risk === 'MEDIUM' ? 'text-amber-300' : 'text-emerald-300'}`}>{risk}</p>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-3 col-span-2 sm:col-span-1">
                    <p className="text-[9px] uppercase tracking-wider text-slate-400">RAZON</p>
                    <p className="mt-1 text-xs font-semibold text-white break-words">{m?.REASON ?? '—'}</p>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-3">
                    <p className="text-[9px] uppercase tracking-wider text-slate-400">VALOR</p>
                    <p className="mt-1 text-sm font-semibold text-white">{m?.VALUE ?? '—'}</p>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-3">
                    <p className="text-[9px] uppercase tracking-wider text-slate-400">INDICADOR</p>
                    <p className="mt-1 text-sm font-semibold text-white">{m?.INDICATOR ?? '—'}</p>
                  </div>
                  <div className="rounded-2xl border border-white/10 bg-white/5 p-3">
                    <p className="text-[9px] uppercase tracking-wider text-slate-400">STATUS</p>
                    <p className={`mt-1 text-sm font-bold ${m?.STATUS === 'OK' ? 'text-emerald-400' : 'text-red-400'}`}>{m?.STATUS ?? '—'}</p>
                  </div>
                </div>
              );
            })()
          ) : (
            <div className="mt-4 flex flex-col items-center justify-center py-6 px-4 rounded-2xl border border-dashed border-white/10 bg-slate-950/30">
              <p className="text-xs text-slate-400 text-center max-w-sm">
                El motor ARM64 aun no ha generado decisiones. Envia lecturas desde la Raspberry Pi para ver los resultados en vivo.
              </p>
            </div>
          )}
        </section>

        {/* Sección Análisis ARM64 */}
        <ARM64ResultsSection
          results={dashboard.arm64_results}
          onGenerateMock={() => void handleGenerateMockARM64()}
          onPrepareData={() => void handlePrepareARM64Data()}
          onRunAnalysis={() => void handleRunARM64()}
          loading={busy === 'arm64-mock'}
          preparing={busy === 'arm64-prep'}
          running={busy === 'arm64-run'}
          backendUrl={baseUrl}
        />

        {/* Analizador Historico */}
        <section className="rounded-3xl border border-white/10 bg-slate-950/70 p-5 sm:p-6 backdrop-blur">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 className="text-lg sm:text-xl font-semibold text-white flex items-center gap-2">
                <LineChart className="h-5 w-5 text-emerald-400 shrink-0" />
                <span>Analizador Historico ARM64</span>
              </h2>
              <p className="mt-1 text-xs text-slate-400">
                Configura el analisis historico: archivo, rango de lineas y columna del sensor.
              </p>
            </div>
          </div>

          <div className="mt-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-3">
            <Field label="Archivo CSV">
              <input
                value={histForm.file}
                onChange={(e) => setHistForm(p => ({ ...p, file: e.target.value }))}
                className={inputClass}
                placeholder="lecturas.csv"
              />
            </Field>
            <Field label="Linea Inicial">
              <input
                type="number"
                min="1"
                value={histForm.start_line}
                onChange={(e) => setHistForm(p => ({ ...p, start_line: e.target.value }))}
                className={inputClass}
              />
            </Field>
            <Field label="Linea Final">
              <input
                type="number"
                min="1"
                value={histForm.end_line}
                onChange={(e) => setHistForm(p => ({ ...p, end_line: e.target.value }))}
                className={inputClass}
              />
            </Field>
            <Field label="Columna">
              <select
                value={histForm.column}
                onChange={(e) => setHistForm(p => ({ ...p, column: e.target.value }))}
                className={inputClass}
              >
                {COLUMN_OPTIONS.map(opt => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </Field>
            <Field label="Valor Ideal (RMSE)">
              <input
                type="number"
                value={histForm.ideal_value}
                onChange={(e) => setHistForm(p => ({ ...p, ideal_value: e.target.value }))}
                className={inputClass}
              />
            </Field>
            <Field label="Modulo">
              <select
                value={histForm.module}
                onChange={(e) => setHistForm(p => ({ ...p, module: e.target.value }))}
                className={inputClass}
              >
                <option value="RMSE">RMSE</option>
                <option value="WEIGHTED_MEAN">Media Ponderada</option>
                <option value="VARIANCE">Varianza</option>
                <option value="ANOMALY_DETECTION">Anomalias</option>
                <option value="PREDICTION">Prediccion</option>
                <option value="ADVANCED_TREND">Tendencia</option>
                <option value="LINEAR_REGRESSION">Regresion Lineal (F2)</option>
                <option value="PREDICTION_LINEAR">Prediccion Lineal (F2)</option>
                <option value="ERROR_INTEGRAL">Error Integral (F2)</option>
                <option value="LOCAL_DERIVATIVE">Derivada Local (F2)</option>
              </select>
            </Field>
          </div>

          <div className="mt-4 flex justify-end">
            <button
              type="button"
              onClick={() => void handleRunHistoricalAnalysis()}
              disabled={busy !== null}
              className="inline-flex items-center justify-center gap-2 rounded-2xl bg-emerald-400 px-5 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-300 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {busy === 'hist-analysis' ? (
                <><RefreshCw className="h-4 w-4 animate-spin" /> Enviando...</>
              ) : (
                <><Rocket className="h-4 w-4" /> Ejecutar Analisis</>
              )}
            </button>
          </div>
        </section>

        {/* Historiales */}
        <section className="grid gap-6 md:grid-cols-3">
          <Panel title="Lecturas Recientes">
            {dashboard.recent_readings.length === 0 ? (
              <p className="rounded-2xl border border-dashed border-white/10 px-4 py-5 text-sm text-slate-400">No hay lecturas registradas.</p>
            ) : (
              <ul className="space-y-2 text-[11px] sm:text-xs text-slate-200">
                {dashboard.recent_readings.slice(0, 6).map((item, i) => (
                  <li key={i} className="rounded-2xl border border-white/10 bg-white/5 px-3 py-2 leading-relaxed break-words flex items-center gap-2">
                    <SensorIcon type={item.sensor_type} />
                    <span className="text-slate-400 min-w-[80px]">{sensorLabel(item.sensor_type)}</span>
                    <span className="font-semibold text-white ml-auto">{item.value}{item.unit ?? ''}</span>
                  </li>
                ))}
              </ul>
            )}
          </Panel>

          <Panel title="Comandos Recientes">
            {dashboard.recent_commands.length === 0 ? (
              <p className="rounded-2xl border border-dashed border-white/10 px-4 py-5 text-sm text-slate-400">Sin comandos registrados.</p>
            ) : (
              <ul className="space-y-2 text-[11px] sm:text-xs text-slate-200">
                {dashboard.recent_commands.slice(0, 6).map((item, i) => (
                  <li key={i} className="rounded-2xl border border-white/10 bg-white/5 px-3 py-2 leading-relaxed break-words flex items-center gap-2">
                    <span className="rounded-lg bg-emerald-400/15 p-1">
                      <Rocket className="h-3 w-3 text-emerald-300" />
                    </span>
                    <span className="text-slate-300">{item.target}</span>
                    <span className="text-slate-500 mx-1">→</span>
                    <span className="font-mono text-xs text-slate-400">{item.command.replace('set_', '')}</span>
                  </li>
                ))}
              </ul>
            )}
          </Panel>

          <Panel title="Eventos y Logs del Invernadero">
            {(dashboard.recent_events.length === 0 && dashboard.recent_logs.length === 0) ? (
              <p className="rounded-2xl border border-dashed border-white/10 px-4 py-5 text-sm text-slate-400">No hay eventos ni logs.</p>
            ) : (
              <ul className="space-y-2 text-[11px] sm:text-xs text-slate-200">
                {[
                  ...dashboard.recent_events.map((item) => ({
                    text: item.message,
                    severity: item.severity ?? 'info',
                    type: 'event' as const,
                  })),
                  ...dashboard.recent_logs.map((item) => ({
                    text: `${item.actuator}: ${item.action}`,
                    severity: 'info',
                    type: 'log' as const,
                  })),
                ].slice(0, 6).map((item, i) => (
                  <li key={i} className={`rounded-2xl border px-3 py-2 leading-relaxed break-words flex items-start gap-2 ${
                    item.severity === 'critical' ? 'border-red-400/20 bg-red-500/10 text-red-200' :
                    item.severity === 'warning' ? 'border-amber-400/20 bg-amber-500/10 text-amber-200' :
                    'border-white/10 bg-white/5 text-slate-200'
                  }`}>
                    <span className={`text-[9px] font-bold uppercase tracking-wider shrink-0 ${
                      item.severity === 'critical' ? 'text-red-400' :
                      item.severity === 'warning' ? 'text-amber-400' :
                      'text-emerald-400'
                    }`}>
                      [{item.severity === 'info' && item.type === 'log' ? 'LOG' : item.severity.toUpperCase()}]
                    </span>
                    <span>{item.text}</span>
                  </li>
                ))}
              </ul>
            )}
          </Panel>
        </section>

        {/* Espaciado final */}
        <div className="h-4" />
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

function classifySoil(value: number): { label: string; color: string } {
  if (value < 30) return { label: 'SECO', color: 'text-rose-400' };
  if (value > 80) return { label: 'SATURADO', color: 'text-cyan-400' };
  return { label: 'NORMAL', color: 'text-emerald-400' };
}

function MetricCard({ label, value, unit, active, onClick }: { label: string; value: number; unit: string; active: boolean; onClick: () => void }) {
  const soilClass = label.includes('Suelo') ? classifySoil(value) : null;
  return (
    <article
      onClick={onClick}
      className={`rounded-2xl sm:rounded-3xl border p-4 sm:p-5 cursor-pointer shadow-glow backdrop-blur transition-all duration-300 ${active
          ? 'border-emerald-400/50 bg-emerald-500/10'
          : 'border-white/10 bg-slate-950/70 hover:border-emerald-400/30'
        }`}
    >
      <p className="text-[10px] sm:text-xs uppercase tracking-[0.18em] sm:tracking-[0.22em] text-slate-400">{label}</p>
      <p className="mt-3 sm:mt-4 text-2xl sm:text-3xl font-semibold text-white break-words">
        {value !== undefined ? (typeof value === 'number' ? value.toFixed(1).replace('.0', '') : value) : '0'}
        <span className="ml-1 text-xs sm:text-sm font-medium text-slate-400">{unit}</span>
      </p>
      {soilClass && (
        <p className={`mt-1 text-[10px] font-bold uppercase ${soilClass.color}`}>{soilClass.label}</p>
      )}
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

function sensorLabel(type: string): string {
  const map: Record<string, string> = {
    temperature: 'Temperatura',
    humidity: 'Humedad',
    humedad_ambiente: 'Humedad',
    soil_1: 'Suelo Área 1',
    humedad_suelo_area1: 'Suelo Área 1',
    soil_2: 'Suelo Área 2',
    humedad_suelo_area2: 'Suelo Área 2',
    light: 'Luz',
    luz: 'Luz',
    gas: 'Gas',
  };
  return map[type.toLowerCase()] || type;
}

function SensorIcon({ type }: { type: string }) {
  const t = type.toLowerCase();
  if (t.includes('humidity') || t.includes('humedad') || t.includes('soil') || t.includes('suelo'))
    return <span className="rounded-lg bg-cyan-400/15 p-1"><Droplets className="h-3 w-3 text-cyan-300" /></span>;
  if (t.includes('light') || t.includes('luz'))
    return <span className="rounded-lg bg-amber-400/15 p-1"><Sun className="h-3 w-3 text-amber-300" /></span>;
  if (t.includes('gas'))
    return <span className="rounded-lg bg-purple-400/15 p-1"><Wind className="h-3 w-3 text-purple-300" /></span>;
  if (t.includes('temp'))
    return <span className="rounded-lg bg-rose-400/15 p-1"><Activity className="h-3 w-3 text-rose-300" /></span>;
  return <span className="rounded-lg bg-slate-400/15 p-1"><Activity className="h-3 w-3 text-slate-300" /></span>;
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
        <p className="text-xs text-slate-400 text-center">Sin lecturas históricas para {label}. Los sensores publican datos cada ~15s via MQTT.</p>
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
              <stop offset="0%" stopColor="#fb7185" stopOpacity="0.25" />
              <stop offset="100%" stopColor="#fb7185" stopOpacity="0.0" />
            </linearGradient>
            <linearGradient id="gradient-humidity" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#22d3ee" stopOpacity="0.25" />
              <stop offset="100%" stopColor="#22d3ee" stopOpacity="0.0" />
            </linearGradient>
            <linearGradient id="gradient-soil" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#34d399" stopOpacity="0.25" />
              <stop offset="100%" stopColor="#34d399" stopOpacity="0.0" />
            </linearGradient>
            <linearGradient id="gradient-soil2" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#2dd4bf" stopOpacity="0.25" />
              <stop offset="100%" stopColor="#2dd4bf" stopOpacity="0.0" />
            </linearGradient>
            <linearGradient id="gradient-light" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#fbbf24" stopOpacity="0.25" />
              <stop offset="100%" stopColor="#fbbf24" stopOpacity="0.0" />
            </linearGradient>
            <linearGradient id="gradient-gas" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#c084fc" stopOpacity="0.25" />
              <stop offset="100%" stopColor="#c084fc" stopOpacity="0.0" />
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

function LoginPage({ onLogin }: { onLogin: (user: string) => void }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (username === 'admin' && password === 'admin123') {
      onLogin(username);
    } else {
      setError('Usuario o contrasena incorrectos');
    }
  }

  return (
    <main className="min-h-screen bg-[var(--bg)] text-slate-100 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-dashboard-grid bg-[size:24px_24px] opacity-35" />
      <div className="absolute inset-x-0 top-0 h-72 bg-[radial-gradient(circle_at_top,_rgba(16,185,129,0.22),_transparent_60%)]" />
      <div className="relative w-full max-w-md rounded-3xl border border-white/10 bg-slate-950/70 p-8 shadow-glow backdrop-blur">
        <div className="flex flex-col items-center text-center mb-8">
          <div className="rounded-2xl bg-emerald-400/15 p-3 mb-4">
            <Lock className="h-6 w-6 text-emerald-300" />
          </div>
          <p className="text-xs uppercase tracking-[0.3em] text-emerald-300/90">Invernadero Inteligente IoT</p>
          <h1 className="mt-2 text-2xl font-semibold tracking-tight text-white">
            Panel de control y monitoreo inteligente
          </h1>
          <p className="mt-2 text-sm text-slate-400">
            Ingrese sus credenciales para acceder al sistema
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-semibold uppercase tracking-[0.18em] text-emerald-300/80 mb-1.5">
              Usuario
            </label>
            <input
              type="text"
              value={username}
              onChange={(e) => { setUsername(e.target.value); setError(''); }}
              className={inputClass}
              placeholder="admin"
            />
          </div>
          <div>
            <label className="block text-xs font-semibold uppercase tracking-[0.18em] text-emerald-300/80 mb-1.5">
              Contrasena
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => { setPassword(e.target.value); setError(''); }}
              className={inputClass}
              placeholder="••••••••"
            />
          </div>

          {error ? (
            <div className="rounded-2xl border border-rose-400/20 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
              {error}
            </div>
          ) : null}

          <button
            type="submit"
            className="w-full rounded-2xl bg-emerald-400 px-4 py-3 text-sm font-semibold text-slate-950 transition hover:bg-emerald-300"
          >
            Iniciar sesion
          </button>
        </form>

        <p className="mt-6 text-[10px] text-center text-slate-500">
          Grupo 17 - Arquitectura de Computadores y Ensambladores 1 USAC
        </p>
      </div>
    </main>
  );
}

const COLUMN_LABELS: Record<number, string> = {
  0: 'ID', 1: 'TEMP', 2: 'HUM_AIRE', 3: 'HUM_SUELO_1',
  4: 'HUM_SUELO_2', 5: 'LUZ', 6: 'GAS',
};

const COLUMN_OPTIONS = Object.entries(COLUMN_LABELS).map(([v, l]) => ({ value: Number(v), label: l }));

const DEFAULT_COLUMNS: Record<number, number> = { 1: 1, 2: 1, 3: 1, 4: 4, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 10: 1 };

function ARM64ResultsSection({
  results,
  onGenerateMock,
  onPrepareData,
  onRunAnalysis,
  loading,
  preparing,
  running,
  backendUrl,
}: {
  results: Record<string, ARM64Result> | null;
  onGenerateMock: () => void;
  onPrepareData: () => void;
  onRunAnalysis: () => void;
  loading: boolean;
  preparing: boolean;
  running: boolean;
  backendUrl: string;
}) {
  const [columnConfig, setColumnConfig] = useState<Record<number, number>>(DEFAULT_COLUMNS);
  const [savingCol, setSavingCol] = useState(false);

  useEffect(() => {
    getARM64ColumnConfig().then(data => {
      if (data.columns) setColumnConfig(data.columns);
    }).catch(() => { });
  }, []);

  const handleColumnChange = (moduleId: number, colIdx: number) => {
    const next = { ...columnConfig, [moduleId]: colIdx };
    setColumnConfig(next);
    setSavingCol(true);
    setARM64ColumnConfig(next).finally(() => setSavingCol(false));
  };

  const modulesList = [
    {
      key: 'RMSE',
      title: 'RMSE vs valor ideal',
      responsable: 'Fase 2',
      file: 'modulo_1_rmse.s',
      outputFile: 'resultado_rmse.txt',
      formula: 'RMSE = sqrt(Σ(Y_i - IDEAL)² / N)',
      fields: [
        { label: 'Columna (COLUMN)', key: 'COLUMN' },
        { label: 'Ventana inicio (WINDOW_START)', key: 'WINDOW_START' },
        { label: 'Ventana fin (WINDOW_END)', key: 'WINDOW_END' },
        { label: 'Cantidad (COUNT)', key: 'COUNT' },
        { label: 'Valor ideal (IDEAL_VALUE)', key: 'IDEAL_VALUE' },
        { label: 'Suma error² (SUM_SQUARED_ERROR)', key: 'SUM_SQUARED_ERROR' },
        { label: 'MSE', key: 'MSE' },
        { label: 'RMSE', key: 'RMSE', highlight: true }
      ]
    },
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
    },
    // --- Modulos historicos Fase 2 (agregados por devs) ---
    {
      key: 'LINEAR_REGRESSION',
      title: 'Regresion Lineal (F2)',
      responsable: 'Integrante 2',
      file: 'modulo_2_regresion/varianza.s',
      outputFile: 'resultado_regresion.txt',
      formula: 'SLOPE = (N*ΣXY - ΣX*ΣY) / (N*ΣX² - (ΣX)²) × 100',
      fields: [
        { label: 'Columna (COLUMN)', key: 'COLUMN' },
        { label: 'Inicio (WINDOW_START)', key: 'WINDOW_START' },
        { label: 'Fin (WINDOW_END)', key: 'WINDOW_END' },
        { label: 'Cantidad (COUNT)', key: 'COUNT' },
        { label: 'Pendiente×100 (SLOPE_X100)', key: 'SLOPE_X100', highlight: true },
        { label: 'Tendencia (TREND)', key: 'TREND', badge: true }
      ]
    },
    {
      key: 'PREDICTION_LINEAR',
      title: 'Prediccion Lineal (F2)',
      responsable: 'Integrante 3',
      file: 'modulo_3_prediccion/predicciones.s',
      outputFile: 'resultado_prediccion.txt',
      formula: 'PRED = SLOPE×(N+K)/100 + INTERCEPT/100',
      fields: [
        { label: 'Columna (COLUMN)', key: 'COLUMN' },
        { label: 'Inicio (WINDOW_START)', key: 'WINDOW_START' },
        { label: 'Fin (WINDOW_END)', key: 'WINDOW_END' },
        { label: 'Cantidad (COUNT)', key: 'COUNT' },
        { label: 'K pasos', key: 'K' },
        { label: 'Pendiente×100 (SLOPE_X100)', key: 'SLOPE_X100' },
        { label: 'Intercepto×100 (INTERCEPT_X100)', key: 'INTERCEPT_X100' },
        { label: 'Valor predecido', key: 'PREDICTED_', dynamic: true, highlight: true }
      ]
    },
    {
      key: 'ERROR_INTEGRAL',
      title: 'Error Integral (F2)',
      responsable: 'Integrante 4',
      file: 'modulo_4_integral_error/integrals.s',
      outputFile: 'resultado_integral.txt',
      formula: '∫|Y-IDEAL| dx ≈ Σ(|Y_i-IDEAL| + |Y_next-IDEAL|)/2',
      fields: [
        { label: 'Columna (COLUMN)', key: 'COLUMN' },
        { label: 'Inicio (WINDOW_START)', key: 'WINDOW_START' },
        { label: 'Fin (WINDOW_END)', key: 'WINDOW_END' },
        { label: 'Cantidad (COUNT)', key: 'COUNT' },
        { label: 'Valor ideal (IDEAL)', key: 'IDEAL' },
        { label: 'Error integral (ERROR_INTEGRAL)', key: 'ERROR_INTEGRAL', highlight: true }
      ]
    },
    {
      key: 'LOCAL_DERIVATIVE',
      title: 'Derivada Local (F2)',
      responsable: 'Integrante 5',
      file: 'modulo_5_derivada_local/derivada.s',
      outputFile: 'resultado_derivada_local.txt',
      formula: 'MAX|SLOPE| en ventana deslizante de 5',
      fields: [
        { label: 'Columna (COLUMN)', key: 'COLUMN' },
        { label: 'Inicio (WINDOW_START)', key: 'WINDOW_START' },
        { label: 'Fin (WINDOW_END)', key: 'WINDOW_END' },
        { label: 'Cantidad (COUNT)', key: 'COUNT' },
        { label: 'Tamano ventana (WINDOW_SIZE)', key: 'WINDOW_SIZE' },
        { label: 'Max pendiente×100 (MAX_LOCAL_SLOPE_X100)', key: 'MAX_LOCAL_SLOPE_X100', highlight: true }
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
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={onPrepareData}
            disabled={preparing}
            className="inline-flex items-center justify-center rounded-2xl bg-emerald-400 px-4 py-2 text-xs font-semibold text-slate-950 transition hover:bg-emerald-300 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {preparing ? 'Generando...' : 'Preparar datos desde MongoDB'}
          </button>
          <button
            type="button"
            onClick={onRunAnalysis}
            disabled={running}
            className="inline-flex items-center justify-center rounded-2xl bg-emerald-400 px-4 py-2 text-xs font-semibold text-slate-950 transition hover:bg-emerald-300 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {running ? 'Ejecutando...' : 'Ejecutar análisis en la Pi'}
          </button>
          <button
            type="button"
            onClick={onGenerateMock}
            disabled={loading}
            className="inline-flex items-center justify-center rounded-2xl border border-white/20 bg-white/5 px-4 py-2 text-xs font-semibold text-slate-300 transition hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {loading ? 'Generando...' : 'Datos de prueba (mock)'}
          </button>
        </div>
      </div>

      {running && (
        <div className="rounded-2xl border border-emerald-400/20 bg-emerald-500/10 p-4">
          <p className="text-xs text-emerald-300 flex items-center gap-2">
            <RefreshCw className="h-3.5 w-3.5 animate-spin" />
            Ejecutando módulos ARM64 en la Raspberry Pi...
          </p>
        </div>
      )}

      <div className="rounded-2xl border border-white/10 bg-white/4 p-4">
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-xs font-semibold text-slate-300 flex items-center gap-1.5">
            <Settings2 className="h-3.5 w-3.5 text-slate-400" />
            Columnas del CSV por módulo
            {savingCol && <span className="text-[9px] text-slate-500 ml-1">guardando...</span>}
          </h3>
        </div>
        <div className="flex flex-wrap gap-2">
          {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((modId) => (
            <div key={modId} className="flex items-center gap-1.5 bg-slate-950/60 rounded-lg px-2.5 py-1.5">
              <span className="text-[10px] text-slate-400 font-medium">M{modId}:</span>
              <select
                value={columnConfig[modId] ?? DEFAULT_COLUMNS[modId]}
                onChange={(e) => handleColumnChange(modId, Number(e.target.value))}
                className="appearance-none bg-slate-800 text-[10px] text-slate-200 rounded border border-white/10 px-1.5 py-0.5
                           focus:outline-none focus:border-emerald-400/50 cursor-pointer hover:bg-slate-700 transition"
              >
                {COLUMN_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>
          ))}
        </div>
      </div>

      {!hasData ? (
        <div className="flex flex-col items-center justify-center py-10 px-4 rounded-2xl border border-dashed border-white/10 bg-slate-950/30">
          <p className="text-xs text-slate-400 text-center max-w-sm">
            Ningún análisis ARM64 ha sido reportado en MongoDB. Prepara los datos desde MongoDB y ejecuta los módulos en la Raspberry Pi para obtener resultados reales.
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
                        const isDynamic = (f as any).dynamic;
                        const val = isDynamic
                          ? Object.entries(modData.results ?? {}).find(([k]) => k.startsWith(f.key))?.[1]
                          : modData.results?.[f.key];
                        return (
                          <div key={f.key} className="flex items-center justify-between text-[10px] border-b border-white/5 pb-1">
                            <span className="text-slate-400">{f.label.split(' (')[0]}</span>
                            {(f as any).badge ? (
                              <span className={`px-1.5 py-0.5 rounded text-[8px] font-bold ${val === 'HIGH' || val === 'DOWN' ? 'bg-red-500/20 text-red-300' :
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
