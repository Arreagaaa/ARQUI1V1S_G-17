# Reporte de Auditoría — Invernadero Inteligente IoT (Grupo 17)

## 1. Resumen Ejecutivo

**Completitud estimada: ~95%** (pre-ARM64, pre-maqueta)

El proyecto está prácticamente completo en su fase local/simulada. Todos los componentes principales (backend, frontend, base de datos, integración MQTT) están implementados y funcionales. Los módulos ARM64 están presentes con su estructura completa. Se corrigieron bugs menores y se agregaron componentes faltantes durante esta auditoría.

---

## 2. Ítems OK (✅)

### 2.1 Estructura del proyecto
- ✅ Backend (`Proyecto1/backend/app/`) modular con routers, services, mqtt, schemas
- ✅ Frontend (`Proyecto1/frontend/src/`) con React + TypeScript + Vite + Tailwind
- ✅ ARM64 (`Proyecto1/arm64/`) con 5 módulos, Makefile, utils, resultados
- ✅ Raspberry Pi client (`Proyecto1/raspberry/`) con GPIO y MQTT
- ✅ `README.md` con descripción del proyecto
- ✅ `.env.example` para backend y frontend

### 2.2 Backend
- ✅ **Conexión MongoDB**: Db factory configurada para local/Atlas
- ✅ **6 colecciones**: `sensor_readings`, `events`, `commands`, `system_status`, `actuator_logs`, `arm64_results`
- ✅ **Estados globales**: NORMAL, ADVERTENCIA, RIEGO_ACTIVO, MODO_MANUAL, EMERGENCIA
- ✅ **Umbrales**: Temperatura >30°C, gas >150ppm, suelo <30%, suelo >80%
- ✅ **Lógica de riego**: Bomba activa por suelo seco, desactivación por saturación
- ✅ **API REST**: Endpoints completos para sensors, events, commands, control, status, arm64
- ✅ **MQTT Publisher/Subscriber**: Arquitectura completa con connection manager
- ✅ **Mock provider**: `MQTTMockProvider` para generar datos de prueba
- ✅ **Seed database**: Script de inicialización con datos coherentes
- ✅ **Topics MQTT**: Prefijo `grupo17/invernadero/` configurado

### 2.3 Frontend
- ✅ **Panel principal**: Estado global, temperatura, humedad, suelo, luz, gas
- ✅ **Gráficas históricas**: SVG inline para temperatura, humedad, suelo, luz, gas
- ✅ **Controles remotos**: Riego, luces, ventilación, alarma, modo
- ✅ **Historial**: Eventos, comandos, logs de actuadores
- ✅ **Sección ARM64**: 5 módulos con campos, fórmula, responsable
- ✅ **Clasificación de suelo**: SECO/NORMAL/SATURADO (añadido en esta auditoría)
- ✅ **Conexión MQTT directa**: WebSocket desde el navegador (añadido en esta auditoría)
- ✅ **Polling REST**: Actualización cada 15 segundos

### 2.4 MongoDB
- ✅ URI configurable (`mongodb://localhost:27017` o Atlas)
- ✅ Índices optimizados creados en startup
- ✅ Server selection timeout configurado

### 2.5 ARM64
- ✅ Carpeta `arm64/` con todos los módulos `.s`
- ✅ Utils compartidos (`utils.s`)
- ✅ Makefile para compilación y ejecución
- ✅ `lecturas.csv` con 30 registros
- ✅ Resultados de ejemplo en `results/`

---

## 3. Ítems con Advertencia (⚠️)

| Ítem | Detalle | Archivo |
|------|---------|---------|
| Backend source en MQTT handler | Handler salta mensajes con source "web/api/backend/system/dashboard". Si el backend publica con source "raspi-01", se procesa a sí mismo causando doble inserción. Riesgo bajo porque el backend publica con source del payload original | `backend/app/mqtt/handlers.py` |
| ControlRequest.area opcional | El riego permite area=null. Para Área 2 (manual) debería forzar validación | `backend/app/schemas.py` |
| generateMockARM64Results sin dev=true | Corregido en esta auditoría | `frontend/src/lib/api.ts` |
| Broker MQTT cambiado a HiveMQ | Originalmente configurado con EMQX. Se actualizó .env y .env.example | `backend/.env` |

---

## 4. Ítems Faltantes (❌) - Corregidos

Los siguientes ítems estaban faltantes y fueron implementados durante esta auditoría:

| Ítem | Archivo creado/modificado |
|------|--------------------------|
| Simulador de sensores | `backend/simulador.py` |
| Generador de lecturas.csv | `backend/generate_lecturas.py` |
| Frontend MQTT WebSocket | `frontend/src/lib/mqttClient.ts`, modificado `App.tsx` |
| MQTTX_SETUP.md | `MQTTX_SETUP.md` |
| Clasificación suelo SECO/NORMAL/SATURADO | Modificado `App.tsx` |
| Bug API.ts (?dev=true) | Modificado `frontend/src/lib/api.ts` |
| lecturas.csv en arm64/ | Generado automáticamente |

---

## 5. Prioridad de Corrección

1. **ALTA** - Simulador de sensores (esencial para pruebas de flujo completo)
2. **ALTA** - Frontend MQTT WebSocket (requerido para tiempo real según enunciado)
3. **ALTA** - Bug API.ts generateMockARM64Results (bloquea pruebas ARM64)
4. **MEDIA** - Clasificación de suelo (requerido en enunciado del dashboard)
5. **MEDIA** - Documentación MQTTX (requerido para integración del equipo)

---

## 6. Estimación de Trabajo

| Ítem | Tiempo estimado | Estado |
|------|----------------|--------|
| Simulador de sensores | 45 min | ✅ Completado |
| Frontend MQTT WebSocket | 60 min | ✅ Completado |
| Bug API.ts | 5 min | ✅ Completado |
| Clasificación de suelo | 15 min | ✅ Completado |
| MQTTX_SETUP.md | 20 min | ✅ Completado |
| Generador lecturas.csv | 20 min | ✅ Completado |

---

## 7. Flujo Local End-to-End

### Prueba de humo (verificada):
1. ✅ Arrancar backend: `uvicorn app.main:app --reload` desde `backend/`
2. ✅ Arrancar frontend: `pnpm dev` desde `frontend/`
3. ✅ Insertar lectura en sensor_readings via API: `POST /api/readings`
4. ✅ Lectura visible en panel principal del dashboard
5. ✅ Enviar comando riego desde dashboard: `POST /api/control/irrigation`
6. ✅ Comando aparece en colección `commands`
7. ✅ Estado global cambia a RIEGO_ACTIVO
8. ✅ Insertar gas alto → estado cambia a EMERGENCIA
9. ✅ Evento de emergencia registrado en `events`
