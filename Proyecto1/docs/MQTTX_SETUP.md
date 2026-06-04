# Configuración de MQTTX Web — Invernadero IoT Grupo 17

Guía paso a paso para conectar cualquier integrante del grupo a MQTTX Web
y monitorear / controlar el sistema en tiempo real.

> **Broker público utilizado:** `broker.emqx.io:1883` (sin SSL)
> **Broker alternativo:** `test.mosquitto.org:1883` o `broker.hivemq.com:1883`
> **Tópico base del grupo:** `grupo17/invernadero`

---

## 1. Acceso a MQTTX Web

1. Abre en el navegador: **https://mqttx.app/web**
2. Click en el ícono de "**+**" o "**New Connection**".

---

## 2. Crear la conexión

| Campo            | Valor a ingresar                                |
|------------------|-------------------------------------------------|
| **Name**         | `Invernadero Grupo 17` (o el nombre que prefieras) |
| **Client ID**    | `mqttx_invernadero_G17_<tu-inicial>` (ej. `mqttx_invernadero_G17_jp`) — **cada integrante debe usar un Client ID único** |
| **Host**         | `broker.emqx.io`                                |
| **Port**         | `1883` (MQTT estándar, sin TLS)                 |
| **Protocol**     | `mqtt://`                                       |
| **Username**     | *(vacío)*                                       |
| **Password**     | *(vacío)*                                       |
| **Clean Session**| ✅ Activado                                     |
| **Keep Alive**   | `60` segundos                                   |
| **SSL/TLS**      | ❌ Desactivado (1883 sin TLS)                   |

Click **Connect**. Verás el punto verde arriba indicando que estás conectado.

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
| No llegan mensajes en MQTTX                       | Verifica Client ID único, suscripción a `grupo17/invernadero/#` con QoS 0 |
| `mqtt_connected: false` en /api/health           | Cambiar a `MQTT_HOST=test.mosquitto.org` o `broker.hivemq.com`  |
| Dashboard no actualiza                            | Refresca con Ctrl+F5; revisa consola del navegador              |
| Error "Address already in use" al iniciar backend | Hay otro proceso en puerto 8080: `netstat -ano | findstr 8080`  |
| MongoDB no conecta                                | Verifica que Compass esté corriendo: `mongosh mongodb://localhost:27017` |
| MQTTX no se conecta al broker                    | El navegador bloquea WSS: usa `mqtt://` en puerto `1883` (no WSS 8884) |

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
