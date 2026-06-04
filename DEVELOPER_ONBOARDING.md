# DEVELOPER ONBOARDING — Invernadero IoT Grupo 17

> **Para quién:** developer nuevo asignado al proyecto. Asumimos que nunca vio el código.
> **Tiempo estimado:** 30-45 minutos (incluye instalación de requisitos).
> **Objetivo:** que levantes el sistema completo, ejecutes todas las pruebas, y confirmes que todo funciona end-to-end. Al terminar, le decís al equipo "OK, todo joya".

---

## PARTE 1 — Requisitos y clonar el repo

### 1.1 Requisitos por plataforma

#### Windows 10/11
| Herramienta | Versión mínima | Cómo verificar | Link |
|---|---|---|---|
| Python | 3.10+ (recomendado 3.13) | `python --version` | https://www.python.org/downloads/ |
| Node.js | 18+ con npm | `node --version` y `npm --version` | https://nodejs.org/ |
| MongoDB Community | 6.0+ corriendo en `:27017` | `tasklist \| findstr mongod` | https://www.mongodb.com/try/download/community |
| MongoDB Compass (GUI) | última | abrir la app | https://www.mongodb.com/try/download/compass |
| Git | 2.30+ | `git --version` | https://git-scm.com/ |
| Navegador | Chrome/Edge/Firefox | — | — |

> **PowerShell:** usar `;` para encadenar comandos (NO `&&`).

#### Linux (Ubuntu/Debian) / Raspberry Pi OS
```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv nodejs npm mongodb-org git
# Iniciar MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod
```

#### macOS
```bash
brew install python@3.13 node mongodb-community git
brew services start mongodb-community
```

### 1.2 Clonar el repo

```bash
git clone <URL-del-repo>
cd ARQUI1V1S_G-17
```

> Si te clonan una rama específica: `git clone -b <rama> <URL>`. Para ver la estructura: `ls -la` (Linux/macOS) o `dir` (Windows).

### 1.3 Estructura que tenés que ver

```
ARQUI1V1S_G-17/
├── README.md
├── DEVELOPER_ONBOARDING.md      ← este archivo
├── start.bat                    ← doble click para arrancar todo (Windows)
└── Proyecto1/
    ├── ESTADO.md                ← cómo vamos, qué falta
    ├── .env.example
    ├── backend/
    │   ├── BACKEND.md           ← documentación técnica del backend
    │   ├── app/
    │   ├── simulador.py         ← simula la Raspberry Pi
    │   ├── test_regresion.py    ← 45 tests automatizados
    │   └── test_mqttx_simulator.py
    ├── frontend/
    │   ├── FRONTEND.md
    │   └── src/
    ├── raspberry/               ← código para la Pi (futuro, sin hardware aún)
    └── arm64/
        └── lecturas.csv         ← 30 lecturas para módulos ARM64
```

---

## PARTE 2 — Arrancar el sistema

### 2.1 Windows: doble click en `start.bat`

1. Asegurate que **MongoDB está corriendo** (abrí Compass y conectate a `mongodb://localhost:27017`).
2. Doble click en `start.bat` (raíz del repo).
3. Se abren **dos ventanas**:
   - **Backend** — corre en `http://127.0.0.1:8080`. NO la cierres.
   - **Frontend** — corre en `http://localhost:5173`. NO la cierres.

> ⚠️ **NO usar `uvicorn --reload`** — rompe la conexión MQTT singleton.

### 2.2 Manual (Linux/macOS o si querés ver logs en una terminal)

**Terminal 1 — Backend:**
```bash
cd Proyecto1/backend
python3 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp ../.env.example .env
python -m uvicorn app.main:app --host 127.0.0.1 --port 8080
```

**Terminal 2 — Frontend:**
```bash
cd Proyecto1/frontend
npm install
echo "VITE_API_BASE_URL=http://localhost:8080" > .env.local
npm run dev
```

### 2.3 Verificar que arrancó

Abrí en el navegador:
- `http://127.0.0.1:8080/api/health` → debe responder JSON con `"mongodb": true` y `"mqtt_connected": true`.
- `http://localhost:5173` → debe verse el dashboard con métricas.
- `http://127.0.0.1:8080/docs` → Swagger interactivo de los endpoints.

Si `/api/health` da `mongodb: false` → MongoDB no está corriendo. Abrí Compass primero.
Si da `mqtt_connected: false` → puede ser que el broker `broker.emqx.io` esté saturado. Esperá 30s o hacé `POST /api/mqtt/reconnect` (en Swagger o `curl -X POST http://127.0.0.1:8080/api/mqtt/reconnect`).

---

## PARTE 3 — Tests que TENÉS que hacer (en orden)

> **Importante:** dejá el backend y frontend levantados durante todas las pruebas.

### TEST 1 — Backend health y Mongo conectado
**Objetivo:** confirmar que el backend responde y MongoDB funciona.

```bash
# Windows PowerShell
(Invoke-WebRequest http://127.0.0.1:8080/api/health).Content
```

**Esperado:** JSON con `mongodb: true, mqtt_connected: true, mqtt_subscriptions: [4 entries]`.

❌ Si `mongodb: false` → arrancá MongoDB Compass y volvé a probar.

---

### TEST 2 — Simulador de la Raspberry Pi (sin hardware)
**Objetivo:** validar el flujo MQTT sensor → backend → Mongo.

**Terminal 3 (nueva):**
```bash
cd Proyecto1/backend
python simulador.py --once      # publica 6 lecturas y sale
```

**Esperado en consola:** `Modo --once: publicadas 6 lecturas. Saliendo.`

**Verificá en MongoDB Compass:**
- Conectá a `mongodb://localhost:27017` → DB `invernadero_iot` → colección `sensor_readings`.
- Debe haber 6 documentos nuevos con `source: raspi-sim-01` y `sensor_type` en {temperature, humidity, soil_1, soil_2, light, gas}.

❌ Si no aparecen → abrí la ventana del backend, debe haber líneas `MQTT IN topic=grupo17/invernadero/sensores/...`. Si NO aparecen, hay un problema de red o broker caído.

**Variantes del simulador** (probalas todas, son escenarios del enunciado):
```bash
python simulador.py                  # cada 5s, valores normales
python simulador.py --once           # una vez y sale
python simulador.py --scenario emergencia        # gas=200ppm → EMERGENCIA
python simulador.py --scenario seco_area1        # suelo1<30% → RIEGO_ACTIVO
python simulador.py --scenario saturado_area2    # suelo2>80% → advertencia
python simulador.py --scenario poca_luz          # luz<20% → luces ON
python simulador.py --interval 2                 # más rápido para pruebas visuales
```

---

### TEST 3 — Suite automatizada de regresión (45 tests)
**Objetivo:** validar que TODOS los endpoints, reglas y filtros funcionan.

**Terminal 3:**
```bash
cd Proyecto1/backend
python test_regresion.py
```

**Esperado al final:** `RESUMEN: 45 OK, 0 FAIL` y `REGRESION EXITOSA — sistema validado al 100%`.

Las 7 secciones cubiertas:
1. REST API (18 endpoints)
2. Control endpoints (irrigation, lights, fan, alarm, mode)
3. MongoDB 6 colecciones
4. MQTT subscriber (enabled, connected, suscripciones, reconnect)
5. Flujo MQTT E2E (publish → persistencia)
6. Reglas automáticas (gas > 150 → ventilador + alarma + evento)
7. Filtro anti-loop (`source=api` NO se persiste)

❌ Si falla alguno → pegale el error al equipo. **NO seguir adelante con tests fallando.**

---

### TEST 4 — Test del simulador MQTTX (12 mensajes, simula cualquier persona)
**Objetivo:** simular lo que hace un developer cuando abre MQTTX Web.

**Terminal 3:**
```bash
cd Proyecto1/backend
python test_mqttx_simulator.py
```

**Esperado:** `Mensajes enviados: 12, publicados OK: 12` y resúmenes de cada escenario (sensores, controles, apagado, emergencia).

**Verificá en MongoDB Compass:**
- Colección `commands` → debe haber nuevos documentos con `source: mqttx_simulator`.
- Colección `events` → debe haber al menos un evento `emergency` (gas=200ppm dispara la regla).

---

### TEST 5 — Dashboard web (polling cada 15s)
**Objetivo:** validar que la UI refleja el estado.

1. Abrí `http://localhost:5173` en el navegador.
2. Esperá 15-20 segundos. Las métricas deben actualizarse (polling).
3. **Probar el modo manual:** botón "Modo" → cambiar a "manual". El indicador debe pasar a amarillo/naranja.
4. **Probar controles:** en modo manual, toggle luces / bomba / ventilador / alarma. Cada cambio debe reflejarse en ≤15s.
5. **NO clickear "Borrar y sembrar"** durante las pruebas — borra todas las 6 colecciones. Solo el botón verde "Sembrar BD" es no destructivo.

❌ Si el dashboard no actualiza → abrí la consola del navegador (F12), buscá errores de red. Verificá que `VITE_API_BASE_URL` apunta a `http://localhost:8080`.

---

### TEST 6 — MQTTX Web oficial (cualquier persona con navegador puede participar)
**Objetivo:** confirmar que CUALQUIER developer con un navegador puede monitorear y controlar el sistema. El test "estrella" es publicar `gas=400` desde MQTTX y ver el dashboard pasar a **EMERGENCIA ROJA** en ≤15s.

#### Paso 0: parar el simulador (CRÍTICO para ver el cambio limpio)

El simulador publica cada 5s y **pisa** el estado de EMERGENCIA antes de que se vea en pantalla.
- Si lo corriste vos mismo: andá a la terminal donde corre y hacé **Ctrl+C**.
- Si no lo estás corriendo: salteá este paso.
- Esperá **20 segundos** para que el sistema se asiente.

> El simulador usa `source: raspi-sim-01`. En Compass, filtrá `sensor_readings` por ese source y verificá que no haya docs nuevos después de los 20s.

#### Paso 1: abrir MQTTX Web

Andá a **https://mqttx.app/web** en Chrome/Edge (Firefox también sirve).

#### Paso 2: crear la conexión (WSS+SSL OBLIGATORIO)

> MQTTX Web **ya no acepta conexiones sin SSL**. Usá `wss://` con SSL/TLS activado, puerto 8084.

Click en el `+` (New Connection) y llená EXACTAMENTE así:

| Campo | Valor |
|---|---|
| Name | `Invernadero G17 Dev` |
| Client ID | `mqttx_dev_<tu-inicial>_v1` (ej. `mqttx_dev_jp_v1`) — **único** |
| Host | `broker.emqx.io` |
| Port | `8084` |
| Protocol | `wss://` |
| Path | `/mqtt` |
| Username | (vacío) |
| Password | (vacío) |
| **SSL/TLS** | **ACTIVADO** ✅ (toggle azul) |
| Clean Session | ✅ |
| Keep Alive | `60` |

Click **Connect**. **Punto verde arriba** = conectado.

#### Paso 3: suscribirse para ver el tráfico

Click **+ New Subscription**:
- Topic: `grupo17/invernadero/#`
- QoS: `0`
- Confirm

Si el simulador estuviera activo, verías mensajes cada 5s. Como lo paraste, está vacío (bien).

#### Paso 4: test dramático — publicar `gas=400` → EMERGENCIA ROJA

Este es el test más visible: el dashboard pasa de `NORMAL/ADVERTENCIA` (verde/amarillo) a **`EMERGENCIA` (rojo)** y la alarma se activa.

En el panel **Publish** (a la derecha):

- **Topic:** `grupo17/invernadero/sensores/gas`
- **QoS:** `1`
- **Payload** (copiá y pegá literal):
  ```json
  {
    "sensor_type": "gas",
    "value": 400.0,
    "unit": "ppm",
    "area": "control",
    "status": "critical",
    "source": "mqttx_dev_<tu-inicial>",
    "timestamp": "2026-06-04T18:50:00Z"
  }
  ```

Click **Publish**.

**Verificá (en paralelo, abrí otra pestaña con el dashboard `http://localhost:5173`):**

| Dónde | Qué tiene que pasar | Cuándo |
|---|---|---|
| MQTTX suscripción `grupo17/invernadero/#` | Aparece un mensaje en `sensores/gas` | inmediato |
| MQTTX suscripción | Aparece un mensaje en `actuadores/alarma` (el backend publica la acción) | inmediato |
| MQTTX suscripción | Aparece un mensaje en `actuadores/ventilador` (el backend publica la acción) | inmediato |
| Ventana del backend | Log `MQTT IN topic=grupo17/invernadero/sensores/gas ...` | inmediato |
| Ventana del backend | Log `MQTT command persistido` o similar para actuadores | inmediato |
| MongoDB Compass → `events` | Nuevo doc con `event_type: emergency`, `severity: critical` | inmediato |
| MongoDB Compass → `actuator_logs` | `buzzer -> on` y `fan -> on` con `source: backend_rules` | inmediato |
| Dashboard `http://localhost:5173` | Pill `EMERGENCIA` en **rojo**, `Alarma Sonora: Activo`, `Ventilación: Activo` | en ≤15s (polling) |

#### Paso 5: restaurar publicando `gas=50`

Mismo topic, mismo formato, pero `value: 50.0`:
```json
{
  "sensor_type": "gas",
  "value": 50.0,
  "unit": "ppm",
  "area": "control",
  "status": "normal",
  "source": "mqttx_dev_<tu-inicial>",
  "timestamp": "2026-06-04T18:51:00Z"
}
```

Click **Publish**. En ≤15s el dashboard vuelve a `NORMAL`/`ADVERTENCIA` (depende de cómo estén los otros sensores).

#### Paso 6: probar un comando (cambia un actuador desde MQTTX)

- **Topic:** `grupo17/invernadero/control/remoto`
- **QoS:** `1`
- **Payload:**
  ```json
  {
    "command": "set_lights",
    "target": "lights",
    "source": "mqttx_dev_<tu-inicial>",
    "payload": {"state": "on"},
    "timestamp": "2026-06-04T18:52:00Z"
  }
  ```

Click **Publish**. **Verificá:** en ≤15s, `Iluminación: Activo` en el dashboard.

**Otros comandos que podés probar** (mismo topic, mismo formato):
- `set_pump` con `payload.state: "on"` y `payload.area: "area_1"` o `"area_2"`
- `set_fan` con `payload.state: "on"` o `"off"`
- `set_buzzer` con `payload.state: "on"`, `"off"` o `"mute"`
- `set_mode` con `payload.state: "auto"` o `"manual"`

#### Paso 7: probar el filtro anti-loop (CRÍTICO entender)

- **Topic:** `grupo17/invernadero/control/remoto`
- **Payload:** igual al paso 6, pero con **`"source": "web"`** (o `"api"`, `"backend"`, `"system"`, `"dashboard"`)

Click **Publish**.

Vas a ver el mensaje en la suscripción (llegó al broker y se distribuyó), **pero NO** aparece en Compass ni cambia el dashboard. Esto es a propósito: el backend filtra `source in {web, api, backend, system, dashboard}` para evitar que un POST REST que publica por MQTT se re-procese en loop.

> **Para una persona real siempre usá `source: mqttx_<tu-inicial>` o `source: <nombre único>`.** NUNCA `web`, `api`, `backend`, `system`, `dashboard`.

#### Paso 8: si tenés el simulador, reinicialo

`python simulador.py` en otra terminal. Vas a ver aparecer mensajes en tu suscripción `grupo17/invernadero/#` cada 5s (lecturas de los 6 sensores).

❌ **Problema común — sesión pegada:** si publicás y MQTTX dice "OK" pero el backend no recibe, el broker público está guardando tu sesión vieja. Solución: cerrar la conexión → F5 → nueva conexión con Client ID `_v2` (ej. `mqttx_dev_jp_v2`).

---

### TEST 7 — Verificar reglas automáticas en vivo
**Objetivo:** ver que las reglas se disparan en modo `auto`.

1. En el dashboard, cambiá modo a **auto** (botón Modo).
2. En MQTTX Web, publicá en `grupo17/invernadero/sensores/gas`:
   ```json
   {"sensor_type": "gas", "value": 200.0, "unit": "ppm", "area": "control", "status": "critical", "source": "mqttx_dev", "timestamp": "2026-06-04T18:30:00Z"}
   ```
3. **Verificá:**
   - Dashboard: `overall_state: EMERGENCIA` (rojo) en ≤15s.
   - MongoDB Compass → `events` → documento con `event_type: emergency`, `severity: critical`.
   - MongoDB Compass → `actuator_logs` → `fan: on`, `buzzer: on` (reglas automáticas).
   - MQTTX Web suscripción → debe aparecer un mensaje en `actuadores/ventilador` y `actuadores/alarma` (el backend publica las acciones).
4. Esperá ~10s y publicá un valor normal (`value: 50.0`). El estado debe volver a `NORMAL`.

**Probar regla de suelo seco:**
5. Publicá en `grupo17/invernadero/sensores/humedad_suelo_area1`:
   ```json
   {"sensor_type": "soil_1", "value": 20.0, "unit": "%", "area": "area_1", "status": "warning", "source": "mqttx_dev", "timestamp": "2026-06-04T18:30:00Z"}
   ```
6. Verificá: dashboard `RIEGO_ACTIVO`, `actuator_logs` con `pump: on`.

---

### TEST 8 — Verificar tópicos del enunciado (15 mínimos)
**Objetivo:** confirmar que todos los topics del enunciado están cubiertos.

Ejecutá en Terminal 3:
```bash
python -c "from app.mqtt.topic_registry import MQTTTopicRegistry; r = MQTTTopicRegistry(); print('\n'.join(sorted(r.all_topics())))"
```

**Esperado:** al menos 15 topics, todos bajo `grupo17/invernadero/`:
- 6 de sensores (temperatura, humedad_aire, humedad_suelo_area1, humedad_suelo_area2, luz, gas)
- 4+ de actuadores (bomba, ventilador, luces, alarma)
- 1+ de control remoto (`control/remoto`)
- 1+ de estado global (`estado/global`)
- 1+ de eventos (`eventos/log` o similar)

Comparar contra la lista en [BACKEND.md](Proyecto1/backend/BACKEND.md) sección "Contrato MQTT".

---

### TEST 9 — Verificar archivos clave del enunciado
**Objetivo:** confirmar estructura y formato exigido.

```bash
# lecturas.csv: header + 30 datos + $ = 32 lineas
wc -l Proyecto1/arm64/lecturas.csv         # Linux/macOS
(Get-Content Proyecto1/arm64/lecturas.csv).Count  # PowerShell
```

**Esperado:** 32. Si no, regenerar (lo hace la Pi en fase ARM64).

```bash
# Formato exacto del header
head -1 Proyecto1/arm64/lecturas.csv
# Esperado: ID,TEMP,HUM_AIRE,HUM_SUELO_1,HUM_SUELO_2,LUZ,GAS,RIEGO_1,RIEGO_2
```

```bash
# Ultimo caracter debe ser $
tail -c 1 Proyecto1/arm64/lecturas.csv
# Esperado: $
```

---

## PARTE 4 — Checklist final (marca cuando confirmes)

- [ ] Python 3.10+ instalado y en PATH
- [ ] Node 18+ con npm
- [ ] MongoDB corriendo en :27017
- [ ] MongoDB Compass instalado
- [ ] Repo clonado
- [ ] `start.bat` levantó backend y frontend sin errores
- [ ] `/api/health` → `mongodb: true`, `mqtt_connected: true`, 4 suscripciones
- [ ] `test_regresion.py` → 45/45 OK
- [ ] `test_mqttx_simulator.py` → 12/12 publicados
- [ ] Dashboard en `http://localhost:5173` actualiza cada 15s
- [ ] MQTTX Web conecta a `wss://broker.emqx.io:8084` con SSL ON
- [ ] Suscripción `grupo17/invernadero/#` configurada
- [ ] Publicar `gas=400` desde MQTTX (con simulador **parado**) → dashboard va a `EMERGENCIA` ROJO (en ≤15s)
- [ ] Publicar `gas=50` desde MQTTX → dashboard vuelve a `NORMAL/ADVERTENCIA`
- [ ] Publicar `set_lights ON` desde MQTTX → `Iluminación: Activo` en dashboard
- [ ] Publicar `source=web` desde MQTTX → NO aparece en `commands` (filtro anti-loop)
- [ ] `lecturas.csv` tiene 32 líneas con formato correcto
- [ ] 6 colecciones presentes en MongoDB (sensor_readings, events, commands, system_status, actuator_logs, arm64_results)

Si **todos** los checks están OK → mandale al equipo: **"Proyecto joya, levanté todo, corrí todas las pruebas, todo OK."**

---

## PARTE 5 — Troubleshooting rápido

| Síntoma | Causa probable | Solución |
|---|---|---|
| `mongodb: false` en /api/health | MongoDB no está corriendo | Abrir Compass / `sudo systemctl start mongod` |
| `mqtt_connected: false` | Broker público saturado o red | `POST /api/mqtt/reconnect` o esperar 30s |
| Dashboard no actualiza | VITE_API_BASE_URL mal | Verificar `.env.local` en `frontend/` |
| MQTTX dice OK pero backend no recibe | Sesión pegada del broker | Cerrar → F5 → reconectar con Client ID `_v2` |
| `Address already in use` en puerto 8080 | Otro proceso en 8080 | Windows: `netstat -ano \| findstr 8080` y matar PID |
| `python` no encontrado | Python no en PATH | Usar ruta completa: `C:\Users\<user>\AppData\Local\Programs\Python\Python313\python.exe` |
| Dashboard dice "Borrar y sembrar" | Botón rojo destructivo | **NO clickear** durante pruebas |
| `ModuleNotFoundError` en tests | venv no activado | `source venv/bin/activate` o `venv\Scripts\activate` |
| `npm install` falla en Pi | Pocos recursos | `npm install --no-audit --no-fund --prefer-offline` |

---

## PARTE 6 — PROMPT para tu agente de IA

> Copiá y pegá este bloque en tu agente de IA (Claude, GPT, etc.) para que revise tu trabajo automáticamente.

````
Sos un asistente de QA técnico. Tu trabajo es ayudar a un developer a validar
que el proyecto "Invernadero Inteligente IoT — Grupo 17" en
D:\Projects\USAC\ARQUI1V1S_G-17 está funcionando al 100%.

CONTEXTO DEL PROYECTO:
- Raspberry Pi 3B+ → MQTT (broker.emqx.io:1883) → Backend FastAPI (:8080) → MongoDB
- Frontend React/Vite dashboard en :5173
- Tópicos MQTT: grupo17/invernadero/...
- 6 colecciones Mongo: sensor_readings, events, commands, system_status, actuator_logs, arm64_results
- Filtro anti-loop: source in {web, api, backend, system, dashboard} → NO persistir
- Hardware (Pi, maqueta) NO existe todavía; se simula con simulador.py
- Módulos ARM64 pendientes (5 módulos, uno por integrante)

TAREAS QUE DEBES HACER EN ORDEN:

1. LEER estos archivos para entender el proyecto:
   - D:\Projects\USAC\ARQUI1V1S_G-17\README.md
   - D:\Projects\USAC\ARQUI1V1S_G-17\Proyecto1\ESTADO.md
   - D:\Projects\USAC\ARQUI1V1S_G-17\Proyecto1\backend\BACKEND.md
   - D:\Projects\USAC\ARQUI1V1S_G-17\Proyecto1\frontend\FRONTEND.md

2. VERIFICAR que el backend está corriendo:
   curl http://127.0.0.1:8080/api/health
   → Debe devolver mongodb:true, mqtt_connected:true, 4 suscripciones

3. EJECUTAR los tests en orden:
   cd D:\Projects\USAC\ARQUI1V1S_G-17\Proyecto1\backend
   python test_regresion.py        # debe dar 45 OK, 0 FAIL
   python test_mqttx_simulator.py  # debe dar 12/12 publicados
   python simulador.py --once      # debe publicar 6 lecturas

4. VERIFICAR MongoDB con pymongo:
   - Conectar a mongodb://localhost:27017, DB invernadero_iot
   - Confirmar 6 colecciones existen
   - sensor_readings debe crecer después del simulador
   - commands debe crecer después de test_mqttx_simulator

5. SIMULAR lo que haria un developer con MQTTX Web (sin abrir navegador):
   - Publicar en grupo17/invernadero/control/remoto con source=mqttx_ai_agent
   - Verificar que aparece en MongoDB commands
   - Publicar en grupo17/invernadero/sensores/gas con value=200
   - Verificar que events tiene un emergency nuevo
   - Publicar con source=web → verificar que NO aparece (filtro anti-loop)

6. VERIFICAR archivos del enunciado:
   - Proyecto1/arm64/lecturas.csv debe tener 32 líneas
   - Header: ID,TEMP,HUM_AIRE,HUM_SUELO_1,HUM_SUELO_2,LUZ,GAS,RIEGO_1,RIEGO_2
   - Última línea: $

7. REPORTE FINAL al developer:
   - Lista de pruebas pasadas (✅) y fallidas (❌)
   - Si todo OK: "El proyecto está al 100%, podés reportarlo al equipo"
   - Si algo falla: indicar el archivo, la línea, el error exacto y cómo arreglarlo

REGLAS:
- NO modifiques código del backend o frontend. Solo diagnostica.
- Si un test falla, pegá el output completo y sugerí la causa probable.
- Si el backend no responde, primero verificá que esté corriendo
  (puede ser que se cayó o no se levantó).
- Si MongoDB no responde, primero verificá que Compass esté conectado.

Empezá ahora.
````

---

## PARTE 7 — Próximos pasos una vez validado

1. **Reportar al equipo:** "Proyecto joya, todas las pruebas pasaron, listo para migrar a Atlas."
2. **Migración a Atlas (siguiente hito):** el equipo comparte la URI de Atlas → cambiar `MONGODB_URI` en `Proyecto1/backend/.env` → reiniciar backend.
3. **Módulos ARM64 (fase siguiente):** cada integrante hace su `.s` en `arm64/modules/modulo_N_*/`. Primero grupal: `arm64/utils/utils.s` (5 pts).
4. **Maqueta + Raspberry:** cuando se tenga el hardware, reemplazar `simulador.py` con `raspberry/main.py` (ya está el esqueleto).

---

*Fin del documento — DEVELOPER_ONBOARDING.md — Grupo 17 — Invernadero Inteligente IoT*
