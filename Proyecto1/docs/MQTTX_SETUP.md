# Configuración de MQTTX Web — Invernadero IoT Grupo 17

Guía paso a paso para conectar cualquier integrante del grupo a MQTTX Web
y monitorear / controlar el sistema en tiempo real.

> **Broker público utilizado:** `broker.emqx.io`
> **Puertos:** `1883` (Python/CLI, sin SSL) y `8084` (MQTTX Web, **WSS+SSL obligatorio**)
> **Tópico base del grupo:** `grupo17/invernadero`

---

## 1. Acceso a MQTTX Web

1. Abre en el navegador: **https://mqttx.app/web**
2. Click en el ícono de "**+**" o "**New Connection**".

---

## 2. Crear la conexión (WSS+SSL OBLIGATORIO)

> **IMPORTANTE:** MQTTX Web (la versión navegador) **YA NO SOPORTA conexiones
> sin SSL** por seguridad. Si usás `ws://` con puerto 1883, la conexión
> fallará. **DEBÉS usar `wss://` con SSL/TLS activado en puerto 8084.**

| Campo            | Valor a ingresar                                |
|------------------|-------------------------------------------------|
| **Name**         | `Invernadero G17 <tu-inicial>` (ej. `Invernadero G17 J`) |
| **Client ID**    | `mqttx_invernadero_G17_<tu-inicial>_v<N>` — **DEBE ser único** (ver sección 2.1) |
| **Host**         | `broker.emqx.io`                                |
| **Port**         | `8084`                                          |
| **Protocol**     | `wss://`                                        |
| **Path**         | `/mqtt`                                         |
| **Username**     | *(vacío)*                                       |
| **Password**     | *(vacío)*                                       |
| **SSL/TLS**      | ✅ **ACTIVADO (toggle azul encendido)**         |
| **Clean Session**| ✅ Activado                                     |
| **Keep Alive**   | `60` segundos                                   |

Click **Connect**. Verás el punto verde arriba indicando que estás conectado.

### 2.1 Client ID único (evita problemas de sesión pegada)

Si ves que tus mensajes se publican en MQTTX pero el backend NO los recibe,
es porque el broker público está guardando sesiones de clientes "muertos"
con el mismo Client ID. **Solución:** usar un Client ID único por sesión.

- Primera conexión: `mqttx_invernadero_G17_jp`
- Si la sesión se pega: cerrar la conexión → F5 (recargar) → crear nueva
  conexión con `mqttx_invernadero_G17_jp_v2` (incrementar la versión)
- Cada integrante del grupo usa su propia inicial: `_jp`, _cr, _mj, etc.

> **Síntoma de sesión pegada:** MQTTX muestra el mensaje publicado con
> el ícono verde (OK), el broker lo confirma, pero en la BD del backend
> el comando no aparece y el log no muestra "MQTT IN". Solución: ver arriba.

---

## 3. Suscribirse a todos los topics del grupo

Una vez conectado, agrega una suscripción con wildcard para ver TODO:

1. Click en **"+ New Subscription"**
2. **Topic:** `grupo17/invernadero/#`
3. **QoS:** `0`
4. **Color:** el que prefieras
5. Click **Confirm**

Verás aparecer mensajes en tiempo real cuando:
- El simulador publica lecturas de sensores
- El backend publica cambios de actuadores
- La Raspberry Pi reporte estado global (en fase con hardware)

---

## 4. Topics individuales (opcional, para monitoreo granular)

Si prefieres ver cada categoría por separado, crea suscripciones individuales:

### Sensores (la Raspberry Pi publica cada 5s)
- `grupo17/invernadero/sensores/temperatura`
- `grupo17/invernadero/sensores/humedad_ambiente`
- `grupo17/invernadero/sensores/humedad_suelo_area1`
- `grupo17/invernadero/sensores/humedad_suelo_area2`
- `grupo17/invernadero/sensores/luz`
- `grupo17/invernadero/sensores/gas`

### Actuadores (cambios de estado del hardware)
- `grupo17/invernadero/actuadores/riego`
- `grupo17/invernadero/actuadores/riego_area1`
- `grupo17/invernadero/actuadores/riego_area2`
- `grupo17/invernadero/actuadores/ventilador`
- `grupo17/invernadero/actuadores/luces`
- `grupo17/invernadero/actuadores/alarma`

### Estado global (resumen consolidado)
- `grupo17/invernadero/estado/global`

### Control (comandos desde el dashboard)
- `grupo17/invernadero/control/remoto`
- `grupo17/invernadero/control/manual`

---

## 5. Publicar un comando de prueba (desde MQTTX)

Para activar el riego del Área 1 desde MQTTX:

1. Click en el panel derecho **"Publish"** (no en subscriptions).
2. **Topic:** `grupo17/invernadero/control/remoto`
3. **QoS:** `0`
4. **Payload (JSON):**
   ```json
   {
     "command": "set_pump",
     "target": "pump",
     "source": "mqttx_test",
     "payload": {"state": "on", "area": "area_1"},
     "timestamp": "2026-06-04T00:00:00Z"
   }
   ```
5. Click **Publish**.

El backend recibirá el mensaje, lo guardará en MongoDB (`commands`) y
actualizará el estado global. El dashboard verá el cambio en ≤ 15 segundos.

### Comandos disponibles

| Acción                           | command                | target   | state           | area     |
|----------------------------------|------------------------|----------|-----------------|----------|
| Activar bomba Área 1             | `set_pump`             | `pump`   | `on`            | `area_1` |
| Apagar bomba Área 1              | `set_pump`             | `pump`   | `off`           | `area_1` |
| Activar bomba Área 2             | `set_pump`             | `pump`   | `on`            | `area_2` |
| Encender luces                   | `set_lights`           | `lights` | `on`            | *(omitir)* |
| Apagar luces                     | `set_lights`           | `lights` | `off`           | *(omitir)* |
| Activar ventilador               | `set_fan`              | `fan`    | `on`            | *(omitir)* |
| Apagar ventilador                | `set_fan`              | `fan`    | `off`           | *(omitir)* |
| Activar alarma (buzzer)          | `set_buzzer`           | `buzzer` | `on`            | *(omitir)* |
| Silenciar alarma                 | `set_buzzer`           | `buzzer` | `mute` o `off`  | *(omitir)* |
| Cambiar a modo automático        | `set_mode`             | `mode`   | `auto`          | *(omitir)* |
| Cambiar a modo manual            | `set_mode`             | `mode`   | `manual`        | *(omitir)* |

> **Payload siempre debe incluir `command`, `target`, `payload.state` y opcionalmente `payload.area`.**

### Ejemplo para modo manual
```json
{
  "command": "set_mode",
  "target": "mode",
  "source": "mqttx_test",
  "payload": {"state": "manual"},
  "timestamp": "2026-06-04T00:00:00Z"
}
```

---

## 6. Verificar que el sistema completo está vivo

### 6.1 Backend levantado
```powershell
# En el navegador:
http://localhost:8080/api/health

# Debe responder:
{
  "status": "ok",
  "mongodb": true,
  "mqtt_enabled": true,
  "mqtt_connected": true,
  "timestamp": "..."
}
```

### 6.2 Simulador publicando
```powershell
cd Proyecto1\backend
"C:\Users\crjav\AppData\Local\Programs\Python\Python313\python.exe" simulador.py
```

Verás en consola algo como:
```
[INFO] simulador: Publicadas 6 lecturas (temp=27.4, gas=88.1, soil1=49.2, ...)
```

### 6.3 Dashboard refrescando
- Abre http://localhost:5173
- Las métricas deben actualizarse cada 15 segundos
- Las gráficas deben mostrar los nuevos puntos

### 6.4 MQTTX recibiendo
- En tu suscripción `grupo17/invernadero/#` debes ver mensajes cada 5 segundos
- Filtra por topic `sensores/temperatura` para ver solo temperatura

### 6.5 MongoDB Compass
- Conecta a `mongodb://localhost:27017` → DB `invernadero_iot`
- Colección `sensor_readings` debe crecer cada 5 segundos
- Colección `commands` debe crecer cuando publicas desde MQTTX

---

## 7. Activar MQTT en el backend

Por defecto `ENABLE_MQTT=false` (modo dry-run, las publicaciones no salen).
Para activar:

1. Abre `Proyecto1/backend/.env`
2. Cambia `ENABLE_MQTT=false` → `ENABLE_MQTT=true`
3. Reinicia el backend
4. Verifica en `/api/health` que `mqtt_connected: true`

> Si `mqtt_connected: false`, el broker puede estar caído o tu red bloquea
> el puerto 1883. Prueba cambiando a `MQTT_HOST=test.mosquitto.org`.

---

## 8. Escenarios de prueba rápida

| Quieres probar...              | Comando en simulador                                    |
|--------------------------------|----------------------------------------------------------|
| Estado normal                  | `python simulador.py`                                    |
| Emergencia por gas             | `python simulador.py --scenario emergencia`              |
| Suelo seco en Área 1           | `python simulador.py --scenario seco_area1`              |
| Suelo saturado en Área 2       | `python simulador.py --scenario saturado_area2`          |
| Poca luz (enciende luces auto) | `python simulador.py --scenario poca_luz`                |
| Publicar una sola vez          | `python simulador.py --once`                             |
| Cada 2 segundos                | `python simulador.py --interval 2`                       |

---

## 9. Troubleshooting

| Problema                                          | Solución                                                        |
|---------------------------------------------------|-----------------------------------------------------------------|
| MQTTX Web no se conecta al broker                 | **Usá `wss://` con SSL/TLS en puerto 8084**. `ws://` fue deshabilitado por MQTTX |
| No llegan mensajes en MQTTX                       | Verifica Client ID único, suscripción a `grupo17/invernadero/#` con QoS 0 |
| Publico en MQTTX pero backend no procesa (sesión pegada) | Cerrar conexión → F5 → reconectar con `_v2`, `_v3`, etc.    |
| `mqtt_connected: false` en /api/health           | `curl http://localhost:8080/api/mqtt/reconnect -X POST`        |
| Dashboard no actualiza                            | Refresca con Ctrl+F5; revisa consola del navegador              |
| Error "Address already in use" al iniciar backend | Hay otro proceso en puerto 8080: `netstat -ano | findstr 8080`  |
| MongoDB no conecta                                | Verifica que Compass esté corriendo: `mongosh mongodb://localhost:27017` |
| Comando `set_lights` no enciende las luces        | Verifica en `backend.err` que aparece `MQTT IN` y `MQTT command persistido` |
| `Sembrar BD` del dashboard borró mis pruebas      | Usar siempre el botón **verde** "Sembrar BD" (no destructivo). El botón **rojo** "Borrar y sembrar" pide confirmación antes de borrar |

---

## 9.1. Diagnóstico: ¿el backend está recibiendo mis mensajes?

Para ver EN TIEMPO REAL si el backend recibe tus publishes, abrí la
consola del backend (PowerShell que corre `uvicorn`) y verificá que
aparezca esta línea por cada mensaje que publiques:

```
2026-06-04 00:29:21,305 [INFO] app.mqtt.connection_manager: MQTT IN topic=grupo17/invernadero/control/remoto qos=1 payload={...}
```

**Si NO aparece esta línea, el backend no está recibiendo el mensaje.**
Las causas más comunes son:

1. **Sesión de MQTTX pegada** (más común): ver sección 2.1
2. **Topic incorrecto**: el topic debe empezar con `grupo17/invernadero/...`
3. **JSON malformado**: revisá comillas, comas y estructura
4. **QoS del broker**: usar QoS 1 (no QoS 2) en el panel de Publish

**Si aparece "MQTT IN" pero no "MQTT command persistido"**, el
backend recibió el mensaje pero lo filtró por `source` (por ejemplo,
si publicás con `source: "web"` o `source: "api"` se ignora para
evitar loops). Usá `source: "mqttx_javier"` u otro nombre único.

---

## 9.2. Alternativa 100% garantizada: `test_mqttx_simulator.py`

Si MQTTX Web te da problemas, **usá este script Python** que simula
exactamente lo mismo que MQTTX (mismo broker, mismos topics, mismo
formato JSON, QoS 1) y es 100% confiable:

```powershell
cd Proyecto1\backend
& "C:\Users\crjav\AppData\Local\Programs\Python\Python313\python.exe" test_mqttx_simulator.py
```

El script publica 12 mensajes (sensores, controles, apagado, emergencia)
y verifica en el dashboard que cada cambio se reflejó. Útil para:
- Demostraciones a la defensora
- Tests automatizados
- Verificar que el sistema funciona antes de una defensa

---

---

## 10. Resumen para el equipo

**Cada integrante del grupo debe:**

1. ✅ Abrir https://mqttx.app/web y conectar con `broker.emqx.io:1883` (mqtt://).
2. ✅ Usar un Client ID único basado en su inicial.
3. ✅ Suscribirse a `grupo17/invernadero/#` (wildcard).
4. ✅ Publicar al menos un comando de prueba (`set_pump` ON / OFF) y verificar
   que aparece en MongoDB Compass dentro de la colección `commands`.
5. ✅ Tomar captura de pantalla de MQTTX mostrando mensajes recibidos y
   entregarla como evidencia de la integración MQTT.

**El sistema completo (backend + simulador + frontend + MQTTX) debe estar
funcionando en la evaluación para obtener los 4 puntos de
"Implementación funcional de MQTT" en la rúbrica.**

---

*Fin del documento — MQTTX_SETUP.md — Grupo 17 — Invernadero Inteligente IoT*
