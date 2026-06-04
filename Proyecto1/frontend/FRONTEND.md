# FRONTEND — Invernadero IoT

Dashboard React + Vite + TailwindCSS. Polling cada 15s al backend, controles manuales y sección ARM64.

---

## Arranque

```bash
cd Proyecto1/frontend
npm install
echo "VITE_API_BASE_URL=http://localhost:8080" > .env.local
npm run dev
```

- Dashboard: `http://localhost:5173`
- Build de producción: `npm run build` (genera `dist/`, pero está en `.gitignore`)

Variables de entorno (en `.env.local`):
```env
VITE_API_BASE_URL=http://localhost:8080
```

---

## Stack

- **React 18** + **Vite 6** + **TypeScript**
- **TailwindCSS 3.4** — estilos
- **lucide-react 0.477** — iconos
- Sin estado global (Redux/Zustand). Cada componente hace su propio fetch.

---

## Estructura

```
frontend/src/
├── App.tsx           # Dashboard principal
├── main.tsx          # Entry point React
├── types.ts          # Tipos TS (SystemStatus, SensorReading, ARM64Result, ...)
├── index.css         # Tailwind + globals
└── lib/
    └── api.ts        # Cliente API REST
```

---

## Componentes principales (en `App.tsx`)

| Sección | Qué hace |
|---|---|
| **Header** | Título + `StatusPill` (estado del sistema) + botones "Sembrar" y "Borrar y sembrar" |
| **MetricCard** × 6 | Temperatura, humedad aire, suelo área 1/2, luz, gas |
| **Gráficos** | Histórico de sensores (línea/barras) y eventos |
| **Controles** | Toggle riego, luces, ventilador, alarma; switch modo auto/manual |
| **ARM64 Results** | Tabla con resultados de los 5 módulos (datos mock por ahora) |
| **Historial** | Tabla paginada de lecturas/comandos/eventos recientes |

### `StatusPill`
Indicador visual del `overall_state`: `NORMAL` (verde), `ADVERTENCIA` (amarillo), `EMERGENCIA` (rojo), `RIEGO_ACTIVO` (azul).

### `MetricCard`
- Valor actual + unidad + sparkline de últimas N lecturas
- Color de fondo según umbrales (rojo si fuera de rango)

---

## Cliente API (`src/lib/api.ts`)

```typescript
const API = import.meta.env.VITE_API_BASE_URL + '/api';

export async function getDashboard()  { return fetch(`${API}/dashboard`).then(r => r.json()); }
export async function getStatus()     { return fetch(`${API}/status`).then(r => r.json()); }
export async function getHistory(q?)  { return fetch(`${API}/sensors/history?${qs(q)}`).then(r => r.json()); }
export async function setMode(mode)   { return fetch(`${API}/control/mode`, { method: 'POST', body: JSON.stringify({ mode }) }); }
// ... irrigation, lights, fan, alarm
export async function seedDatabase(clear = false) {
  return fetch(`${API}/seed`, { method: 'POST', body: JSON.stringify({ clear }) });
}
```

**Importante:** `createReading()` inyecta `source: 'web'` automáticamente para que el backend lo filtre (anti-loop).

---

## Polling

- `useEffect` con `setInterval(getDashboard, 15000)` en `App.tsx`.
- 15s equilibra "fluido" vs "no saturar la Pi". Si se quiere más rápido, ajustar a 5-10s.

```typescript
useEffect(() => {
  const tick = () => getDashboard().then(setData);
  tick();
  const id = setInterval(tick, 15000);
  return () => clearInterval(id);
}, []);
```

---

## Buenas prácticas

- **No clickear "Borrar y sembrar" durante pruebas** — wipea las 6 colecciones (necesario solo para reset completo).
- Si publicas a MQTT desde MQTTX, usa `source: mqttx_<inicial>` (NO `web`).
- El dashboard refleja el flujo MQTT en ≤15s (latencia del polling).
- En Raspberry Pi, buildar con `npm run build` y servir con `nginx` o `serve` (no usar `vite dev` en producción).

---

## Despliegue en Raspberry Pi 3B+

Para no saturar la Pi:
- Buildar con `npm run build` y servir archivos estáticos (no Vite dev).
- Usar `serve -s dist -l 5173` o `nginx` con `proxy_pass` al backend.
- Evitar HMR y watchers en producción.
- El backend ya hace polling interno a Mongo, no necesita WebSockets.

```bash
# En la Pi
cd Proyecto1/frontend
npm install --production=false   # solo para build
npm run build
npx serve -s dist -l 5173
```
