# CHECKLIST DE DEFENSA INDIVIDUAL — Invernadero Inteligente IoT
## Grupo 17 — ACYE1, Segundo Semestre 2026

**Última actualización:** 2026-06-04
**Duración estimada:** 10-15 min de demo + 5 min de Q&A
**Audiencia:** Catedrático + auxiliares

---

## 1. PREPARACIÓN PREVIA (5 min antes de defender)

### 1.1 Verificar que todo está corriendo
```powershell
# Abrir 2 terminales:
# Terminal 1 (backend):
cd D:\Projects\USAC\ARQUI1V1S_G-17
start.bat
#   -> Doble click al .bat abre backend y frontend en ventanas separadas

# Terminal 2 (verificar health):
curl http://127.0.0.1:8080/api/health
# Debe responder: {"status":"ok","mongodb":true,"mqtt_enabled":true,"mqtt_connected":true}

# Terminal 3 (simulador, opcional):
cd D:\Projects\USAC\ARQUI1V1S_G-17\Proyecto1\backend
C:\Users\crjav\AppData\Local\Programs\Python\Python313\python.exe simulador.py
```

### 1.2 Abrir pestañas del navegador
1. **Dashboard** `http://localhost:5173` — maximizar
2. **Swagger** `http://127.0.0.1:8080/docs` — para mostrar endpoints
3. **MQTTX Web** `https://mqttx.app/web` — para la demo en vivo
4. **MongoDB Compass** `mongodb://localhost:27017` — opcional
5. **GitHub repo** del grupo — para mostrar commits

### 1.3 Conectar MQTTX Web (pre-demo)
1. New Connection → Manual Configuration
2. Name: `demo-g17`
3. Host: `broker.emqx.io` | Port: `8084` | Path: `/mqtt`
4. **SSL/TLS: ON** (obligatorio, ws:// fue deshabilitado)
5. Protocol: `MQTT v3.1.1`
6. Client ID: `mqttx_g17_demo_1`
7. Username/Password: dejar en blanco
8. Connect
9. Subscribe to: `grupo17/invernadero/#` (QoS 0)
10. NO desconectar — dejarlo listo

---

## 2. FLUJO DE DEMO (10-15 min)

### 2.1 Apertura (1 min)
**Decir:**
> "El proyecto es un sistema IoT de monitoreo de invernadero con 6 sensores, 5 actuadores,
> backend FastAPI, MongoDB, MQTT como transporte y dashboard React. La arquitectura está
> desacoplada: cualquier cliente MQTT puede publicar y el backend lo procesa."
>
> "Voy a demostrar: el dashboard funcionando, el flujo MQTT end-to-end con un cliente
> externo, y las reglas automáticas en modo auto."

**Mostrar:** Diagrama de arquitectura en el README (`README.md` líneas 9-19).

### 2.2 Demo dashboard estático (2 min)
**Hacer:**
1. Señalar el dashboard en `http://localhost:5173`
2. Mostrar header con 3 StatusPills (API ok, MongoDB Activo, MQTT OK)
3. Mostrar 6 MetricCards con valores actuales (temp, hum, soil_1, soil_2, light, gas)
4. Mostrar gráficos SVG con histórico
5. Mostrar estado global (modo, actuadores activos, alarma)
6. Mostrar 12 quick actions (riego, luces, ventilación, alarma, modo auto/manual)
7. Mostrar sección ARM64 con los 5 módulos

**Decir:**
> "El dashboard se actualiza cada 15 segundos con polling. Los valores que ven vienen
> de MongoDB. Las acciones envían comandos que se persisten y publican a MQTT."

**Si preguntan sobre responsive:** "El layout es responsive con Tailwind — breakpoints sm/md/lg."

### 2.3 Demo de flujo MQTT externo (3 min) — *LA MÁS IMPORTANTE*
**Hacer (en este orden):**

1. **Mostrar backend log** (la terminal del backend debe estar visible)
   - Señalar las líneas `MQTT IN topic=... qos=1 payload=...`

2. **Ir a MQTTX Web** (pestaña ya conectada)
   - Pestaña "Publish"
   - Topic: `grupo17/invernadero/sensores/temperatura`
   - Payload:
     ```json
     {"sensor_type":"temperature","value":35.0,"unit":"°C","area":"control","status":"warning","source":"mqttx_demo","timestamp":"2026-06-04T17:00:00Z"}
     ```
   - Click "Publish"

3. **Volver al dashboard y esperar 5-10 segundos**
   - La temperatura debe cambiar a 35.0°C
   - El estado debe pasar a `ADVERTENCIA` (porque temp > 30°C activa ventilador)
   - Mostrar que `ventilador = Activo` y `Iluminación = Inactivo`

4. **Mostrar backend log de nuevo**
   - Señalar la nueva línea `MQTT IN topic=grupo17/invernadero/sensores/temperatura`
   - Señalar la línea siguiente `MQTT IN topic=grupo17/invernadero/estado/global`
     (el backend publica el estado global automáticamente)

5. **Hacer la EMERGENCIA (gas peligroso)**
   - Topic: `grupo17/invernadero/sensores/gas`
   - Payload:
     ```json
     {"sensor_type":"gas","value":500.0,"unit":"ppm","area":"control","status":"critical","source":"mqttx_demo","timestamp":"2026-06-04T17:00:00Z"}
     ```
   - Click "Publish"

6. **Mostrar reacción en dashboard**
   - Estado global debe pasar a `EMERGENCIA`
   - `Alarma = Activo` (buzzer)
   - `Ventilador = Activo` (porque gas > 150ppm)
   - Los logs de eventos deben registrar la emergencia

**Decir:**
> "Acabamos de publicar dos mensajes desde un cliente MQTT externo. El backend los
> procesó automáticamente, aplicó las reglas de automatización, y respondió publicando
> el nuevo estado global. Todo esto sin que la Raspberry Pi exista todavía — el cliente
> MQTTX Web ES la Raspberry Pi simulada."

### 2.4 Demo de control desde MQTT (1 min)
**Hacer:**
1. Topic: `grupo17/invernadero/control/remoto`
2. Payload:
   ```json
   {"command":"set_lights","target":"lights","source":"mqttx_demo","payload":{"state":"on"},"timestamp":"2026-06-04T17:00:00Z"}
   ```
3. Click "Publish"

**Mostrar:**
- Dashboard: `Iluminación = Activo`
- Backend log: comando procesado

**Decir:**
> "El cliente externo también puede ENVIAR comandos, igual que lo haría la Raspberry
> Pi. El backend los valida, los persiste en MongoDB, y los publica a MQTT."

### 2.5 Demo del backend y MongoDB (2 min)
**Hacer:**
1. Ir a Swagger `http://127.0.0.1:8080/docs`
2. Mostrar `/api/health` → click "Try it out" → "Execute"
   - Mostrar `mqtt_enabled: true`, `mqtt_connected: true`
3. Mostrar `/api/sensors/latest` → ver últimas 12 lecturas
4. Mostrar `/api/sensors/history?limit=5` → ver historial
5. Mostrar `/api/status` → ver estado global actual

**Opcional:** Abrir MongoDB Compass y mostrar las 6 colecciones:
- `sensor_readings` (lecturas)
- `events` (eventos: advertencias, emergencias)
- `commands` (comandos enviados)
- `system_status` (estado global)
- `actuator_logs` (logs de actuadores)
- `arm64_results` (resultados ARM64)

**Decir:**
> "Hay 26 endpoints REST documentados en OpenAPI. Las 6 colecciones tienen índices
> para queries eficientes. El backend maneja CORS para que el frontend React pueda
> consumir la API."

### 2.6 Mostrar código (1-2 min)
**Mostrar archivos clave:**
1. `backend/app/main.py` (entrypoint + lifespan)
2. `backend/app/mqtt/connection_manager.py` (singleton + reconexión)
3. `backend/app/mqtt/handlers.py` (4 handlers con filtro de loop)
4. `backend/app/services/sensor_service.py` (reglas de automatización)
5. `frontend/src/App.tsx` (dashboard completo)
6. `docs/mqtt-contrato.md` (contrato MQTT)

### 2.7 Mostrar el contrato MQTT (1 min)
**Decir:**
> "El contrato MQTT es la especificación formal del sistema. Define 15 tópicos
> con sus payloads JSON. Lo que ven en MQTTX Web cumple exactamente este contrato.
> El backend lo valida con Pydantic antes de procesar."

**Mostrar:** `docs/mqtt-contrato.md` — sección de tópicos de sensores.

### 2.8 Cierre (30 seg)
**Decir:**
> "Lo que falta es el hardware: Raspberry Pi con sensores reales (DHT22, higrómetros,
> LDR, MQ), actuadores (bomba, ventilador, LED, buzzer), LCD I2C y botones. La capa
> de software está completa y validada. La migración a MongoDB Atlas y los módulos
> ARM64 individuales son las siguientes fases."

---

## 3. Q&A — PREGUNTAS PROBABLES Y RESPUESTAS

### 3.1 Técnicas

| # | Pregunta probable | Respuesta |
|---|---|---|
| 1 | ¿Por qué MQTT y no HTTP? | MQTT es el estándar IoT: liviano, publish/subscribe, broker desacopla clientes, QoS 0/1/2, retain, LWT. Permite que múltiples clientes (Pi, dashboard, otros suscriptores) reciban los mismos datos sin polling. |
| 2 | ¿Qué broker usan y por qué? | `broker.emqx.io` público (EMQX Cloud free). Razones: (1) cero instalación, (2) cualquier integrante del grupo puede usarlo desde MQTTX Web, (3) es lo que el enunciado pide como broker externo. En producción se migraría a uno propio o EMQX Cloud con auth. |
| 3 | ¿Cómo evitan loops infinitos? | Los handlers filtran mensajes con `source in (web, api, backend, system, dashboard)`. Si el backend publica un estado global, NO se vuelve a procesar. Ver `backend/app/mqtt/handlers.py`. |
| 4 | ¿Qué pasa si MQTT se cae? | `MQTTConnectionManager` (singleton) tiene reconexión automática con backoff (`reconnect_delay_set(min=1, max=30)`). El backend no crashea — publica cuando reconecta. Hay endpoint `POST /api/mqtt/reconnect` para forzar. |
| 5 | ¿Por qué MongoDB y no SQL? | Documentos JSON se mapean 1:1 con payloads MQTT. Esquema flexible (no requiere ALTER TABLE para agregar campos). Índices en campos clave para queries rápidas. Atlas tiene free tier M0. |
| 6 | ¿Qué validaciones hacen? | (1) Pydantic schemas validan payloads MQTT en `payload_validator.py`. (2) `check_value_range` valida rangos de sensores. (3) Estados de actuadores son enum (on/off/auto). (4) Modo es enum (auto/manual). |
| 7 | ¿Cómo escala? | El backend es stateless. MongoDB escala con Atlas. MQTT broker maneja miles de clientes. El único cuello de botella es el polling de 15s del dashboard — se puede migrar a WebSockets o Server-Sent Events. |
| 8 | ¿Y la seguridad? | CORS configurado. En producción: autenticación JWT, MQTT con TLS + user/pass, MongoDB con auth, variables de entorno para secretos. Para el curso, el broker público es sin auth (es la práctica común del curso). |
| 9 | ¿Por qué Python y no Node? | (1) FastAPI es excelente para APIs async. (2) paho-mqtt es la librería MQTT más madura en Python. (3) Raspberry Pi GPIO tiene RPi.GPIO/gpiozero. (4) El equipo ya conoce Python por ARQUI1. |
| 10 | ¿Cómo sincronizan frontend y backend? | Polling cada 15s. Trade-off: simple, robusto, no requiere WebSockets. Para la demo es suficiente. Mejora futura: WebSockets o SSE. |
| 11 | ¿Qué hace el simulador? | Genera 6 lecturas de sensores con valores realistas y random walk (`_drift()`). Publica cada 5s. Permite demostrar el sistema sin hardware. Ver `backend/simulador.py`. |
| 12 | ¿Qué hacen los 5 módulos ARM64? | Procesamiento estadístico de las 30 lecturas del CSV: (1) media ponderada, (2) varianza/desviación, (3) anomalías, (4) predicción lineal, (5) tendencia acumulada. Cada uno genera un .txt. |

### 3.2 De proceso

| # | Pregunta probable | Respuesta |
|---|---|---|
| 13 | ¿Cómo se organizaron? | División de tareas: backend, frontend, MQTT, ARM64. Reuniones semanales. Repositorio compartido con ramas por feature. Revisiones de código cruzadas. |
| 14 | ¿Qué tests tienen? | `test_integration.py` (45 tests REST), `test_mqtt_e2e.py` (3 tests), `test_mqtt_subscriber.py` (control/remoto), `test_externo_mqttx.py` (3 tests externos), `test_mqttx_simulator.py` (12 mensajes E2E). Total: 60+ tests. |
| 15 | ¿Qué bugs encontraron? | 12 bugs críticos (C1-C12) documentados en `AUDITORIA.md`. Los más importantes: deadlock en publish (C7), loop infinito de mensajes propios (C8-C9), topic MQTT incorrecto en POST /api/commands (C10). |
| 16 | ¿Por qué este puerto? | Backend en `127.0.0.1:8080` (evita conflicto con 8000 de Jupyter). Frontend en `5173` (default de Vite). Ver `start.bat`. |
| 17 | ¿Cómo lo deployan? | En desarrollo: `start.bat` local. En producción: Docker en Raspberry Pi 4/5, MongoDB Atlas, MQTT broker propio. Por ahora es local-only. |
| 18 | ¿Qué sigue? | Atlas, ARM64 individual, maqueta física con sensores reales, video demostrativo, defensa individual. |
| 19 | ¿Cuánto tiempo tomó? | ~X semanas (ajustar). El sprint más largo fue la integración MQTT + MongoDB. |
| 20 | ¿Qué fue lo más difícil? | (1) Bucle infinito cuando el backend publicaba y se re-procesaba. (2) uvicorn `--reload` mata la conexión MQTT singleton. (3) MQTTX Web requiere WSS+SSL obligatoriamente. |

---

## 4. CHECKLIST PRE-DEFENSA (15 min antes)

| # | Item | ✓ |
|---|---|---|
| 1 | Backend corriendo (visible en terminal con logs) | ☐ |
| 2 | Frontend abierto en pestaña 1 | ☐ |
| 3 | Swagger abierto en pestaña 2 | ☐ |
| 4 | MQTTX Web conectado en pestaña 3 (WSS+SSL puerto 8084) | ☐ |
| 5 | Suscripción activa: `grupo17/invernadero/#` en MQTTX | ☐ |
| 6 | `curl http://127.0.0.1:8080/api/health` responde `mqtt_connected: true` | ☐ |
| 7 | Dashboard muestra valores actualizados (no NaN) | ☐ |
| 8 | MongoDB Compass abierto con 6 colecciones visibles | ☐ |
| 9 | Repositorio GitHub abierto (último commit visible) | ☐ |
| 10 | `AUDITORIA.md` abierto en pestaña 4 (para Q&A) | ☐ |
| 11 | `docs/mqtt-contrato.md` abierto en pestaña 5 | ☐ |
| 12 | `test_mqttx_simulator.py` probado 5 min antes (valida que el sistema funciona) | ☐ |
| 13 | Mensaje de prueba con `temperature=35` enviado y dashboard refleja cambio | ☐ |
| 14 | Mensaje de prueba con `gas=500` enviado y dashboard pasa a EMERGENCIA | ☐ |
| 15 | Tiempo de la demo cronometrado: <15 min | ☐ |

---

## 5. SI ALGO FALLA EN LA DEMO

### 5.1 Backend no arranca
- Verificar: `cd backend && venv\Scripts\activate && uvicorn app.main:app --port 8080`
- Ver logs en `backend/backend.log` (si está configurado)
- Verificar MongoDB: `mongosh` o Compass en puerto 27017

### 5.2 Dashboard no carga
- Verificar: `http://localhost:5173` (no 8080)
- Verificar: `curl http://127.0.0.1:8080/api/health` → 200
- Verificar `.env.local` en frontend con `VITE_API_BASE_URL=http://localhost:8080`

### 5.3 MQTTX no conecta
- Verificar: WSS+SSL ON, puerto 8084, path `/mqtt`
- Cambiar Client ID (sufijo `_v2`, `_v3`) por si hay sesión pegada
- F5 + reconectar
- Backup: ejecutar `test_mqttx_simulator.py` que conecta con Python

### 5.4 Publica MQTTX pero no llega al backend
- Verificar backend log: `MQTT IN topic=...`
- Si NO aparece: sesión MQTTX pegada → reset Client ID
- Si aparece: el backend ya procesó, revisar dashboard con F5 (no espera 15s)

### 5.5 Dashboard no se actualiza
- Esperar 15s (polling)
- Si >30s: backend puede estar colgado → Ctrl+C y reiniciar con `start.bat`
- Verificar: `GET /api/status` directo en navegador

---

## 6. RESPUESTAS A PREGUNTAS TRAMPAS COMUNES

### 6.1 "Si MQTT es público, ¿no hay安全问题 de seguridad?"
**Responder:**
> "Sí, cualquier persona puede publicar en `grupo17/invernadero/...` y nuestro backend
> lo va a procesar. Por eso las validaciones Pydantic son importantes: rechazamos
> payloads malformados. En producción usaríamos un broker con autenticación (EMQX Cloud
> con user/pass, o Mosquitto con ACL). Para esta fase del curso, el broker público es
> la práctica estándar — el catedrático puede verificar publicando desde su propio
> MQTTX."

### 6.2 "¿Por qué polling y no WebSockets?"
**Responder:**
> "Trade-off consciente. Polling es simple, robusto, y los 15 segundos son suficientes
> para la demo y el uso real (el sistema no necesita tiempo real estricto). WebSockets
> agregan complejidad (mantener conexión, manejar desconexiones, reconexión) y no son
> necesarios aquí. FastAPI soporta WebSockets nativamente si quisiéramos migrar."

### 6.3 "¿Y si dos clientes publican a la vez?"
**Responder:**
> "El broker MQTT serializa los mensajes y los entrega en orden. MongoDB usa `_id`
> único y los `timestamp` permiten ordenamiento. Si dos comandos contradictorios
> llegan (ej. `set_lights on` y `set_lights off` simultáneos), el último en llegar
> gana — es el comportamiento esperado para actuadores. No hay race condition
> significativa."

### 6.4 "¿Cómo probaron que funciona sin Raspberry Pi?"
**Responder:**
> "Tenemos 60+ tests automatizados y un test externo (`test_externo_mqttx.py`) que
> simula exactamente lo que haría una Raspberry Pi real: publica a `broker.emqx.io`
> con `source: 'raspi-01'`. El backend lo procesa igual que si viniera de la Pi
> física. La simulación es indistinguible del hardware desde el lado del backend."

### 6.5 "¿Cuánto cuesta correr esto en producción?"
**Responder:**
> "MongoDB Atlas free tier M0: gratis hasta 512MB. EMQX Cloud free: gratis hasta
> 1000 conexiones. Raspberry Pi 3B+: ~$35 (usada) o $75 (nueva). Sensores + actuadores:
> ~$50. Total: <$200 para una unidad. Si escalamos a 100 unidades, los costos son
> lineales en hardware; el software no escala en costo."

---

## 7. RECURSOS PARA TENER A MANO

| Recurso | URL/Path | Para qué |
|---|---|---|
| Dashboard | `http://localhost:5173` | Demo en vivo |
| Swagger | `http://127.0.0.1:8080/docs` | Mostrar endpoints |
| MQTTX Web | `https://mqttx.app/web` | Publicar en vivo |
| Repositorio | (URL del grupo) | Mostrar código, commits |
| AUDITORIA.md | `Proyecto1/AUDITORIA.md` | Para Q&A sobre bugs |
| Contrato MQTT | `Proyecto1/docs/mqtt-contrato.md` | Para Q&A sobre tópicos |
| PENDIENTES.md | `Proyecto1/PENDIENTES.md` | Mostrar checklist |
| test_externo_mqttx.py | `Proyecto1/backend/test_externo_mqttx.py` | Backup de demo |
| test_mqttx_simulator.py | `Proyecto1/backend/test_mqttx_simulator.py` | Backup de demo |
| MongoDB Compass | `mongodb://localhost:27017` | Mostrar 6 colecciones |
| Postman / curl | `curl http://127.0.0.1:8080/api/dashboard` | Mostrar API raw |

---

**¡Éxito en la defensa!** 🚀
