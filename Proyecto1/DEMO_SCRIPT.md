# SCRIPT DE DEMO — Invernadero Inteligente IoT
## Grupo 17 — ACYE1, Segundo Semestre 2026

**Duración objetivo:** 12 minutos (cronometrados)
**Audiencia:** Catedrático + auxiliares
**Pre-requisito:** Haber revisado `DEFENSA.md` sección 1 (preparación previa)

---

## TIMELINE GLOBAL

| t | Bloque | Duración | Acumulado |
|---|--------|----------|-----------|
| 0:00 | Apertura | 1:00 | 1:00 |
| 1:00 | Demo dashboard estático | 2:00 | 3:00 |
| 3:00 | **Demo MQTT externo (CORE)** | 4:00 | 7:00 |
| 7:00 | Demo de control desde MQTT | 1:00 | 8:00 |
| 8:00 | Demo backend + MongoDB | 2:00 | 10:00 |
| 10:00 | Mostrar código + contrato | 1:30 | 11:30 |
| 11:30 | Cierre + próximos pasos | 0:30 | 12:00 |
| 12:00 | **Q&A** | 5-10 | - |

**Si te quedas sin tiempo:** Salta el bloque 10:00 (código). Lo importante son 3:00-8:00 (flujo MQTT).

---

## t=0:00 — APERTURA (1 min)

**[TENER: Diagrama de arquitectura abierto en README.md]**

**Decir:**
> "Buenos días. El proyecto es un sistema IoT de monitoreo y control de invernadero
> con 6 tipos de sensores, 5 actuadores, MQTT como transporte, FastAPI + MongoDB en
> el backend, y un dashboard React en el frontend. La arquitectura está desacoplada:
> cualquier cliente MQTT puede publicar y el backend lo procesa. Vamos a ver el
> flujo end-to-end con un cliente MQTT externo."

**[SEÑALAR en README.md líneas 9-19 el diagrama de cajas]**

> "La Raspberry Pi publica sensores vía MQTT, el backend los persiste y aplica reglas
> automáticas, y el dashboard los visualiza. Los actuadores también se controlan por
> MQTT. Hoy la Raspberry Pi no está conectada, pero MQTTX Web hace exactamente lo
> mismo — publica al mismo broker con el mismo formato de payload."

---

## t=1:00 — DEMO DASHBOARD ESTÁTICO (2 min)

**[TENER: Dashboard abierto en http://localhost:5173, maximizado]**

### t=1:00-1:30 — Header + StatusPills
**Señalar:**
- "API ok" — verde
- "MongoDB Activo" — verde
- "MQTT OK" — verde

**Decir:** "Estas pills confirman que backend, base de datos y broker MQTT están conectados."

### t=1:30-2:00 — MetricCards
**Señalar (en orden):**
- Temperatura: ~25°C
- Humedad: ~55%
- Suelo área 1: ~50%
- Suelo área 2: ~45%
- Luz: ~55%
- Gas: ~44 ppm

**Decir:** "Estas son las lecturas en vivo. Vienen de MongoDB y se actualizan cada 15 segundos con polling."

### t=2:00-2:30 — Gráficos
**Señalar:** Los 6 gráficos SVG con histórico.

**Decir:** "Los gráficos muestran la tendencia de los últimos 30 datos. Los SVG son responsive con `viewBox` y `aspectRatio`."

### t=2:30-3:00 — Estado global + acciones
**Señalar:**
- Modo: `MODO_MANUAL` o `MODO_NORMAL`
- Actuadores activos (qué bombita está prendida)
- 12 quick actions (riego, luces, ventilador, alarma, modo)

**Decir:** "Las acciones envían comandos vía REST al backend, que los publica a MQTT. En modo auto, las reglas activan actuadores automáticamente. En modo manual, solo el usuario."

---

## t=3:00 — DEMO MQTT EXTERNO (CORE - 4 min) ⭐

**[MOVERSE a pestaña MQTTX Web]**

**[TENER: Pestaña Publish visible, suscripción activa a grupo17/invernadero/#]**

### t=3:00-3:30 — Explicar MQTTX
**Decir:** "Esto es MQTTX Web. Ya está conectado a `broker.emqx.io:8084` con WSS+SSL. Vamos a publicar un sensor de temperatura alta."

### t=3:30-4:30 — Publicar temperatura=35 (ADVERTENCIA)
**Hacer:**
1. Topic: `grupo17/invernadero/sensores/temperatura`
2. Payload:
   ```json
   {"sensor_type":"temperature","value":35.0,"unit":"°C","area":"control","status":"warning","source":"mqttx_demo","timestamp":"2026-06-04T17:00:00Z"}
   ```
3. Click **Publish**

**[INMEDIATAMENTE moverse a pestaña del backend (terminal)]**

**[DECIR mientras señalas el log:]** "Fíjense en la línea que acaba de aparecer..."

**[Esperar 1-2 segundos, ver la línea `MQTT IN topic=grupo17/invernadero/sensores/temperatura qos=1 retain=False payload=...`]**

**Decir:** "El backend RECIBIÓ el mensaje. Ahora esperemos la línea siguiente..."

**[Esperar 1 segundo, ver la línea `MQTT IN topic=grupo17/invernadero/estado/global payload=...`]**

**Decir:** "Y el backend RESPONDIÓ publicando el nuevo estado global."

**[MOVERSE a dashboard, esperar 5-10 segundos para el próximo polling]**

**Señalar:**
- Temperatura ahora es 35.0°C
- Estado global: `ADVERTENCIA`
- Ventilador: `Activo` (porque temp > 30 activa ventilador)

**Decir:** "La temperatura subió a 35, el sistema detectó que supera el umbral de 30, cambió a ADVERTENCIA y activó el ventilador automáticamente. Todo esto desde un cliente MQTT externo."

### t=4:30-5:30 — Publicar gas=500 (EMERGENCIA)
**Hacer:**
1. Topic: `grupo17/invernadero/sensores/gas`
2. Payload:
   ```json
   {"sensor_type":"gas","value":500.0,"unit":"ppm","area":"control","status":"critical","source":"mqttx_demo","timestamp":"2026-06-04T17:00:00Z"}
   ```
3. Click **Publish**

**[Esperar 10 segundos para el polling del dashboard]**

**Señalar:**
- Gas: 500 ppm
- Estado global: `EMERGENCIA`
- Alarma: `Activo` (buzzer)
- Ventilador: `Activo` (porque gas > 150)
- Iluminación: probablemente apagada (depende de estado previo)

**Decir:** "Ahora simulamos una fuga de gas. El sistema pasó a EMERGENCIA, encendió la alarma y el ventilador. Esto demuestra que las reglas automáticas funcionan."

### t=5:30-6:30 — Verificar persistencia
**[ABRIR MongoDB Compass, ir a colección `events`]**

**Señalar:** "Las emergencias se registran en la colección `events` con severidad crítica."

**[ABRIR Compass, ir a `sensor_readings`]**

**Señalar:** "Las dos lecturas que publicamos (temp=35, gas=500) están aquí con `source: 'mqttx_demo'`."

**[ABRIR Compass, ir a `system_status`]**

**Señalar:** "El estado global más reciente tiene `overall_state: 'EMERGENCIA'`, `gas: 500`, `buzzer_active: true`."

### t=6:30-7:00 — Mostrar el backend log completo
**[VOLVER a terminal del backend]**

**Señalar las 4 líneas clave:**
1. `MQTT IN topic=.../sensores/temperatura` — recibimos temperatura
2. `MQTT OUT topic=.../estado/global` — publicamos estado
3. `MQTT IN topic=.../sensores/gas` — recibimos gas
4. `MQTT OUT topic=.../estado/global` — publicamos nuevo estado

**Decir:** "Cada línea 'MQTT IN' es un mensaje que el backend RECIBIÓ. Cada 'MQTT OUT' es un mensaje que el backend PUBLICÓ. Esto es trazabilidad completa."

---

## t=7:00 — DEMO CONTROL DESDE MQTT (1 min)

**[VOLVER a MQTTX Web]**

### t=7:00-7:30 — Publicar comando set_lights on
**Hacer:**
1. Topic: `grupo17/invernadero/control/remoto`
2. Payload:
   ```json
   {"command":"set_lights","target":"lights","source":"mqttx_demo","payload":{"state":"on"},"timestamp":"2026-06-04T17:00:00Z"}
   ```
3. Click **Publish**

**[Esperar 10 segundos]**

**[IR a dashboard]**

**Señalar:** "Iluminación = Activo"

**Decir:** "El cliente externo no solo publica sensores, también puede ENVIAR COMANDOS, igual que lo haría la Raspberry Pi. El backend validó, persistió en `commands`, y publicó a MQTT."

### t=7:30-8:00 — Apagar
**Hacer:**
1. Topic: `grupo17/invernadero/control/remoto`
2. Payload:
   ```json
   {"command":"set_lights","target":"lights","source":"mqttx_demo","payload":{"state":"off"},"timestamp":"2026-06-04T17:00:00Z"}
   ```
3. Click **Publish**

**Decir:** "Y para apagar. Comando dual, ambas direcciones funcionan."

---

## t=8:00 — DEMO BACKEND + MONGODB (2 min)

**[IR a pestaña Swagger http://127.0.0.1:8080/docs]**

### t=8:00-8:30 — Health check
**Hacer:**
1. Expandir `GET /api/health`
2. Click "Try it out" → "Execute"
3. Mostrar el JSON: `mqtt_connected: true`, `mongodb: true`

**Decir:** "El endpoint de salud confirma que todo está vivo. Esto es importante para monitoring en producción."

### t=8:30-9:00 — Sensores
**Hacer:**
1. Expandir `GET /api/sensors/latest` → "Execute"
2. Mostrar el JSON con las 12 últimas lecturas

**Decir:** "Estas son las 12 lecturas más recientes. El frontend usa este endpoint."

### t=9:00-9:30 — Estado
**Hacer:**
1. Expandir `GET /api/status` → "Execute"
2. Mostrar el JSON con `overall_state: 'EMERGENCIA'`, `gas: 500`, `buzzer_active: true`

**Decir:** "El estado global refleja el sistema en este momento. Noten que gas=500 está aquí."

### t=9:30-10:00 — Comandos
**Hacer:**
1. Expandir `GET /api/commands` → "Execute"
2. Mostrar el JSON con los 2 comandos que publicamos (set_lights on, set_lights off)

**Decir:** "Los comandos que enviamos desde MQTTX están persistidos."

---

## t=10:00 — MOSTRAR CÓDIGO + CONTRATO (1:30 min)

**[ABRIR VSCode con el proyecto]**

### t=10:00-10:30 — Archivos clave
**Mostrar (en este orden):**
1. `backend/app/main.py` — entrypoint, ~80 líneas
2. `backend/app/mqtt/connection_manager.py` — singleton con reconexión
3. `backend/app/mqtt/handlers.py` — 4 handlers con filtro de loop

**Decir:** "La capa MQTT está desacoplada en 6 módulos: connection manager, topic registry, payload validator, publisher, subscriber, mock provider. El singleton maneja reconexión con backoff."

### t=10:30-11:00 — Reglas de automatización
**Mostrar:** `backend/app/services/sensor_service.py`

**Decir:** "Las 5 reglas automáticas están aquí: gas > 150 → EMERGENCIA, temp > 30 → ADVERTENCIA, suelo < 30 → RIEGO_ACTIVO, suelo > 80 → desactivar bomba, todo normal → NORMAL."

### t=11:00-11:30 — Contrato MQTT
**Mostrar:** `Proyecto1/docs/mqtt-contrato.md`

**Decir:** "El contrato MQTT es la especificación formal. 15 tópicos, payloads JSON, validación Pydantic. Lo que ven en MQTTX Web cumple exactamente este contrato."

---

## t=11:30 — CIERRE (30 seg)

**[VOLVER a dashboard]**

**Decir:**
> "El sistema está completo en software: dashboard, backend, MongoDB, MQTT, validaciones,
> reglas automáticas, persistencia. Lo que falta es hardware: Raspberry Pi con
> sensores reales, actuadores, LCD, botones, y la maqueta física. La capa de software
> está validada y es indistinguible del hardware desde el lado del backend."

> "Las siguientes fases son: MongoDB Atlas, módulos ARM64 individuales, integración
> física con sensores, y el video demostrativo."

> "¿Preguntas?"

---

## NOTAS DE PRODUCCIÓN

### Si algo falla durante la demo

| Falla | Plan B |
|---|---|
| MQTTX Web no conecta | Usar `test_externo_mqttx.py` con Python (ya está validado) |
| Backend no arranca | Verificar `backend/backend.log`; reiniciar con `start.bat` |
| Dashboard no actualiza | Esperar 15s; si >30s, Ctrl+C y reiniciar |
| MongoDB caído | El backend retorna `mongodb: false`; no crashea; explicar |
| WiFi inestable | Pre-cargar `test_mqttx_simulator.py` que es offline (conecta directo al broker) |

### Señales de que la demo va bien

- ✅ Backend log muestra `MQTT IN` por cada publish
- ✅ Dashboard refleja cambios en <15s
- ✅ MongoDB Compass muestra documentos nuevos
- ✅ Estado global cambia coherentemente (NORMAL → ADVERTENCIA → EMERGENCIA)
- ✅ Actuadores se activan según reglas

### Señales de que algo va mal

- ❌ No aparece `MQTT IN` en el log → sesión MQTTX pegada, reset
- ❌ Dashboard no actualiza en >30s → backend colgado, reiniciar
- ❌ MongoDB no muestra documentos → problema de persistencia
- ❌ `mqtt_connected: false` → broker caído, esperar reconexión

---

## RECORDATORIO FINAL

- **Hablar claro y pausado** — el catedrático necesita entender todo
- **Señalar la pantalla con el mouse** — no solo describir
- **Tener agua cerca** — son 12+ minutos hablando
- **Sonreír en la Q&A** — si no sabés, decir "no lo sé, pero lo investigo" (es mejor que inventar)
- **Mencionar el grupo** — "como equipo, decidimos..." en vez de "yo hice..."

**¡Éxito!** 🚀
