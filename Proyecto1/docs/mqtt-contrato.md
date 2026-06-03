# Contrato de Comunicación MQTT

Este documento define la estructura y el formato de los mensajes MQTT que se utilizarán para la integración entre la Raspberry Pi 3B+ (hardware/sensores) y el Backend (FastAPI) a través de MQTTX Web.

---

## 1. Configuración de Conexión

- **Broker Sugerido:** `broker.emqx.io` o un servidor de prueba público (ej. `test.mosquitto.org` o HiveMQ). En producción, se utilizará la instancia Atlas / EMQX Cloud.
- **Puerto Estándar:** `1883` (sin SSL) o `8883` (con SSL).
- **Tópico Base:** `grupo17/invernadero`

---

## 2. Contrato de Tópicos de Sensores

La Raspberry Pi debe publicar periódicamente (o en base a cambios significativos) en los siguientes tópicos:

### Tópicos
- `grupo17/invernadero/sensores/temperatura`
- `grupo17/invernadero/sensores/humedad_ambiente`
- `grupo17/invernadero/sensores/humedad_suelo_area1`
- `grupo17/invernadero/sensores/humedad_suelo_area2`
- `grupo17/invernadero/sensores/luz`
- `grupo17/invernadero/sensores/gas`

### Formato de Payload (JSON)
Cada publicación en un tópico de sensor debe utilizar la siguiente estructura JSON:

```json
{
  "sensor_type": "temperature",
  "value": 28.5,
  "unit": "°C",
  "area": "control",
  "status": "normal",
  "source": "raspi-01",
  "timestamp": "2026-06-03T11:20:00Z"
}
```

#### Detalles de campos:
- `sensor_type`: Tipo de variable (ej. `temperature`, `humidity`, `soil_1`, `soil_2`, `light`, `gas`).
- `value`: Valor numérico (punto flotante).
- `unit`: Unidad de medida (`°C`, `%`, `ppm`).
- `area`: Ubicación física (`area_1`, `area_2`, `control`).
- `status`: Estado local (`normal`, `warning`, `critical`).
- `source`: Identificador de la Raspberry Pi (ej. `raspi-01`).
- `timestamp`: Marca de tiempo en formato ISO-8601 UTC.

---

## 3. Contrato de Tópicos de Actuadores y Logs

Cuando un actuador cambia de estado (ya sea por regla automática en la Raspberry Pi o por comando manual desde los botones físicos), la Pi publica el registro correspondiente.

### Tópicos
- `grupo17/invernadero/actuadores/riego`
- `grupo17/invernadero/actuadores/riego_area1`
- `grupo17/invernadero/actuadores/riego_area2`
- `grupo17/invernadero/actuadores/ventilador`
- `grupo17/invernadero/actuadores/luces`
- `grupo17/invernadero/actuadores/alarma`

### Formato de Payload (JSON)
```json
{
  "actuator": "pump",
  "action": "on",
  "area": "area_1",
  "source": "raspi-01",
  "payload": {
    "pin": 17,
    "duration_seconds": 15
  },
  "timestamp": "2026-06-03T11:20:05Z"
}
```

#### Detalles de campos:
- `actuator`: Identificador del actuador (`pump`, `fan`, `lights`, `buzzer`).
- `action`: Acción realizada (`on`, `off`, `mute`).
- `area`: Área de la maqueta afectada (`area_1`, `area_2`, `control`).
- `source`: Quien originó el cambio (`raspi-01` para reglas locales, `web` para control remoto).
- `payload`: Metadatos adicionales (ej. GPIO utilizado, parámetros de duración).

---

## 4. Contrato de Tópicos de Control Remoto y Comando

El Backend publica en estos tópicos cuando el usuario envía comandos manuales desde el Dashboard Web, y la Raspberry Pi los consume.

### Tópicos
- `grupo17/invernadero/control/remoto`
- `grupo17/invernadero/control/manual`

### Formato de Payload (JSON)
```json
{
  "command": "set_pump",
  "target": "pump",
  "source": "web",
  "payload": {
    "state": "on",
    "area": "area_1"
  },
  "timestamp": "2026-06-03T11:20:10Z"
}
```

#### Detalles de campos:
- `command`: Nombre del comando (`set_pump`, `set_fan`, `set_lights`, `set_buzzer`, `set_mode`).
- `target`: Actuador objetivo (`pump`, `fan`, `lights`, `buzzer`, `mode`).
- `source`: Origen (`web`, `api`).
- `payload`: Estado objetivo (`state`: `on`/`off`/`auto`/`manual`/`mute`, y `area` si aplica).

---

## 5. Contrato de Estado Global

La Raspberry Pi calcula periódicamente el estado global del sistema de acuerdo a las reglas de umbrales y lo publica en este tópico. El backend y el frontend lo consumen para mantener sincronizado el dashboard.

### Tópico
- `grupo17/invernadero/estado/global`

### Formato de Payload (JSON)
```json
{
  "mode": "auto",
  "overall_state": "NORMAL",
  "temperature": 24.5,
  "humidity": 55.0,
  "soil_1": 45.2,
  "soil_2": 42.1,
  "light": 60.0,
  "gas": 85.0,
  "pump_active": false,
  "fan_active": false,
  "lights_active": false,
  "buzzer_active": false,
  "source": "raspi-01",
  "timestamp": "2026-06-03T11:20:30Z"
}
```

#### Estados Globales Válidos (`overall_state`):
1. `NORMAL`: Todos los sensores dentro de rangos seguros.
2. `ADVERTENCIA`: Temperatura alta, poca luz, o suelo seco en algún área.
3. `RIEGO_ACTIVO`: La bomba de riego físico está funcionando.
4. `MODO_MANUAL`: El usuario ha tomado control manual del sistema.
5. `EMERGENCIA`: Presencia de gas o humo por encima del límite tolerado (MQ).
