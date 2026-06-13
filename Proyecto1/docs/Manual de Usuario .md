# MANUAL TÉCNICO - DASHBOARD WEB
## Guía de Uso del Sistema de Monitoreo y Control del Invernadero

**Grupo 17 - ACYE1 - Semestre 1 2026**

---

## Tabla de Contenidos

1. [Introducción al Dashboard](#introducción-al-dashboard)
2. [Cómo Acceder](#cómo-acceder)
3. [Descripción del Panel Principal](#descripción-del-panel-principal)
4. [Cómo Usar los Controles Remotos](#cómo-usar-los-controles-remotos)
5. [Cómo Interpretar las Gráficas Históricas](#cómo-interpretar-las-gráficas-históricas)
6. [Cómo Leer el Historial de Eventos y Comandos](#cómo-leer-el-historial-de-eventos-y-comandos)
7. [Cómo Interpretar la Sección de Análisis ARM64](#cómo-interpretar-la-sección-de-análisis-arm64)
8. [Troubleshooting y Errores Comunes](#troubleshooting-y-errores-comunes)
9. [Especificaciones de Rangos y Alarmas](#especificaciones-de-rangos-y-alarmas)
10. [Características Avanzadas](#características-avanzadas)

---

## 1. Introducción al Dashboard

El **Dashboard Web** es la interfaz principal para monitorear y controlar el invernadero inteligente en tiempo real. Proporciona:

- Visualización de sensores en vivo
- Control remoto de actuadores
- Gráficas históricas de 24 horas
- Historial de eventos y comandos
- Análisis estadístico ARM64
- Alertas automáticas

**Navegadores soportados:**
- Chrome/Chromium 90+
- Firefox 88+
- Safari 14+
- Edge 90+

---

## 2. Cómo Acceder

### 2.1 Acceso Local (Desarrollo)

1. Abrir navegador web
2. Ir a: `http://localhost:5173`
3. Esperar carga inicial (~2-3 segundos)
4. El dashboard muestra datos en tiempo real

### 2.2 Requisitos Previos

```
✓ Backend FastAPI corriendo en puerto 8000
✓ MongoDB accesible (local o Atlas)
✓ MQTT Broker conectado (broker.emqx.io)
✓ Conexión a Internet
```

**Verificar estado del backend:**
```bash
curl http://localhost:8000/api/health
```

Respuesta esperada:
```json
{
  "status": "ok",
  "mongodb": true,
  "mqtt_connected": true
}
```

### 2.3 Acceso Remoto (Producción)

Para acceso desde cualquier dispositivo:

1. **Desplegar backend en servidor cloud** (AWS, DigitalOcean, Heroku, etc.)
2. **Configurar CORS** en `.env`:
   ```
   CORS_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
   ```
3. **Desplegar frontend** (Vercel, Netlify, GitHub Pages, etc.)
4. **Configurar DNS** para apuntar a servidor
5. **Habilitar HTTPS/SSL** (Let's Encrypt gratis)

---

## 3. Descripción del Panel Principal

### 3.1 Layout General

```
┌─────────────────────────────────────────────────────────┐
│              INVERNADERO INTELIGENTE IoT                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│         [STATUS CONEXIONES]                             │
│         • Backend: ✅ Conectado                         │
│         • MongoDB: ✅ Conectado                         │
│         • MQTT: ✅ Conectado                            │
│         • Último update: hace 2 segundos                │
│                                                         │
├─────────────────────────────────────────────────────────┤
│          [SENSORES EN VIVO - GRID 3 COLUMNAS]           │
│          ┌─────────┐  ┌─────────┐  ┌─────────┐          │
│          │Temp     │  │Humedad  │  │Luz Zona1│          │
│          │24.5°C   │  │65.2%    │  │450 lux  │          │
│          └─────────┘  └─────────┘  └─────────┘          │
│          ┌─────────┐  ┌─────────┐  ┌─────────┐          │
│          │Luz Zona2│  │Gas      │  │Suelo 1  │          │
│          │320 lux  │  │78.4ppm  │  │52.6%    │          │
│          └─────────┘  └─────────┘  └─────────┘          │
│          ┌─────────┐                                    │
│          │Suelo 2  │                                    │
│          │42.6%    │                                    │
│          └─────────┘                                    │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  [CONTROLES REMOTOS]                                    │
│  [Riego] [Luces] [Ventilador] [Alarma] [Modo]           │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  [GRÁFICAS] [HISTORIAL] [ANÁLISIS ARM64]                │
│  (pestañas para cambiar vista)                          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 3.2 Sección de Status del Sistema

Muestra conexión a cada componente en tiempo real:

```
┌─ STATUS ─────────────────────────┐
│                                  │
│ Backend API        Conectado     │
│   http://localhost:8000/api      │
│   Tiempo respuesta: 45ms         │
│                                  │
│ MongoDB            Conectado     │
│   Documentos: 15,234             │
│   Almacenamiento: 2.4 MB         │
│                                  │
│ MQTT Broker        Conectado     │
│   broker.emqx.io:1883            │
│   Tópicos suscritos: 12          │
│                                  │
│ Simulador          Activo        │
│   Escenario: NORMAL              │
│   Intervalo: 5 segundos          │
│                                  │
│ Última actualización: 00:02:15   │
│                                  │
└──────────────────────────────────┘
```

**Colores de estado:**
- 🟢 Verde = Conectado/Normal
- 🟡 Amarillo = Advertencia/Lento
- 🔴 Rojo = Desconectado/Error
- ⚪ Blanco = Inicializando

### 3.3 Tarjetas de Sensores

Cada sensor muestra:
- **Nombre y ícono** (temperatura, humedad, etc.)
- **Valor actual**
- **Unidad de medida**
- **Ícono de estado** (◀━ tendencia)
- **Rango esperado** (barrita de progreso)

**Ejemplo - Temperatura:**
```
┌─ Temperatura ─────────┐
│                       │
│      🌡️ 24.5 °C       │
│                       │
│  Rango: 20-30°C ▓▓▓▓░ │
│  Tendencia: ↑ +0.2°C  │
│  Últimas 1h: 22-25°C  │
│                       │
└───────────────────────┘
```

[AGREGA CAPTURA DE PANTALLA DE PANEL PRINCIPAL]

---

## 4. Cómo Usar los Controles Remotos

### 4.1 Panel de Controles

```
┌─ CONTROLES REMOTOS ────────────────────────────┐
│                                                │
│  [RIEGO]      [LUCES]      [VENTILADOR]        │
│  ● ON / OFF   ● ON / OFF   ● ON / OFF          │
│                                                │
│  [ALARMA]        [MODO]                        │
│  ● ON / OFF      AUTO / MANUAL                 │
│                                                │
└────────────────────────────────────────────────┘
```

### 4.2 Control de Riego

**Propósito:** Activar/desactivar bomba de riego

**Instrucciones:**
1. Buscar botón "💧 RIEGO"
2. Presionar "ON" para activar
3. Esperar confirmación (luz verde)
4. Presionar "OFF" para desactivar
5. Verificar en "Logs de Actuadores" que se registre

**Indicadores:**
- 🟢 Verde = Bomba activa, regando
- 🔴 Rojo = Bomba inactiva
- 🟡 Amarillo = Error/falla en bomba

**Casos de uso:**
- Riego manual inmediato
- Mantenimiento de suelo
- Rescate en caso de sequía

**Límites de seguridad:**
- Máximo tiempo encendido: 2 horas
- Apagado automático si humedad > 85%
- Alerta si falla después de 30 segundos

[AGREGA CAPTURA: CONTROL RIEGO]

### 4.3 Control de Luces

**Propósito:** Iluminación artificial del invernadero

**Instrucciones:**
1. Presionar "💡 LUCES"
2. Opciones: ON / OFF
3. Deslizador de brillo (si está disponible)
4. El cambio es inmediato

**Modos:**
- **ON:** 100% brillo
- **50% brillo:** Ideal para horarios intermedios
- **OFF:** Luces apagadas (ahorro energético)

**Ciclo automático (Modo AUTO):**
- 06:00-18:00: Luces ON (12h luz natural)
- 18:00-21:00: Luces 50% (atardecer)
- 21:00-06:00: Luces OFF (noche)

**Consumo energético:**
- ON: ~150W
- 50%: ~75W
- OFF: 0W

[AGREGA CAPTURA: CONTROL LUCES]

### 4.4 Control de Ventilador

**Propósito:** Circulación de aire y control de temperatura

**Instrucciones:**
1. Presionar "🌀 VENTILADOR"
2. Opciones: OFF / 50% / 100%
3. Recomendación: usar 50% en horas cálidas
4. Usar 100% en caso de emergencia (temp > 30°C)

**Tabla de referencia:**
| Temp | Humedad | Velocidad Recomendada |
|---|---|---|
| < 20°C | Normal | OFF |
| 20-25°C | < 70% | 50% |
| 25-28°C | > 70% | 100% |
| > 28°C | Cualquiera | 100% |

**Ruido del ventilador:**
- 50%: ~45 dB (conversación normal)
- 100%: ~65 dB (tráfico ligero)

[AGREGA CAPTURA: CONTROL VENTILADOR]

### 4.5 Control de Alarma

**Propósito:** Sistema de alertas sonoras ante emergencias

**Instrucciones:**
1. Presionar "🔊 ALARMA"
2. ON: Activa alarma manual
3. Normalmente se activa automáticamente en:
   - Temperatura > 35°C
   - Gas > 1000 ppm
   - Humedad < 10% (sequedad extrema)
   - Falla de sensor

**Silenciar alarma:**
- Presionar "OFF"
- O resolver problema causante (bajar temp, etc.)

**Volumen:** ~85 dB (perceptible a ~100m)

[AGREGA CAPTURA: CONTROL ALARMA]

### 4.6 Control de Modo

**Propósito:** Cambiar entre operación automática y manual

**Modos disponibles:**
- **AUTO:** Sistema toma decisiones automáticamente
  - Riego según humedad del suelo
  - Luces según hora del día
  - Ventilador según temperatura


- **MANUAL:** Control total del usuario
  - Cada actuador se controla manualmente
  - Sistema no toma decisiones automáticas
  - Útil para mantenimiento/limpieza

**Cómo cambiar:**
1. Presionar "⚙️ MODO"
2. Seleccionar AUTO o MANUAL
3. Confirmar cambio

**Transición:**
- Al cambiar a MANUAL: controles se habilitان
- Al cambiar a AUTO: sistema vuelve a la lógica automática

[AGREGA CAPTURA: CONTROL MODO]

### 4.7 Feedback Visual y Audible

**En el navegador (Feedback Visual):**
- Flash verde: Comando exitoso
- Flash rojo: Error en ejecución
- Giro: Enviando comando
- Naranja: Confirmación pendiente

**En el invernadero (Feedback Real):**
- LED del actuador parpadea
- Sonido de relé activándose
- Cambio físico (bomba enciende, luz se prende, etc.)

---

## 5. Cómo Interpretar las Gráficas Históricas

### 5.1 Acceso a Gráficas

Presionar la pestaña **"📈 GRÁFICAS"** en la parte inferior del panel principal.

### 5.2 Componentes de la Gráfica

```
         Temperatura en los últimos 24h
       ┌────────────────────────────────────┐
  30°C │                    ╱╲╱╲            │
       │                  ╱      ╲          │
  25°C │    ╱╲╱╲╱╲╱╲╱╲╱╲          ╲         │
       │  ╱                        ╲╱╲      │
  20°C │╱                               ╲╱  │
       └────────────────────────────────────┘
        0h    6h   12h   18h   00h    
       
       Rango: MIN=19°C, MAX=28°C, PROMEDIO=24°C
```

**Elementos principales:**
- **Línea:** Valor en cada momento (muestreo cada 5 minutos)
- **Eje X:** Tiempo (últimas 24 horas)
- **Eje Y:** Valores de magnitud (temperatura en °C, humedad en %, etc.)
- **Color:** Diferente para cada sensor
- **Zoom:** Pasar mouse sobre puntos para ver detalle
- **Leyenda:** Mostrar/ocultar sensores

### 5.3 Interpretación de Patrones

#### Patrón 1: Ciclo Diurno Normal (Temperatura)

```
30°C │                    ╱╲
     │                  ╱    ╲
25°C │                ╱        ╲
     │              ╱            ╲
20°C │            ╱                ╲
     └──────────────────────────────┘
      0h (noche) 12h (día) 24h (noche)
```

**Significado:** Normal
- Sube durante el día (calefacción + luz solar)
- Baja durante la noche (radiación nocturna)
- Amplitud: 5-10°C

#### Patrón 2: Temperatura Baja Sostenida

```
20°C │ ─────────────────────────────
     │
15°C │
     └──────────────────────────────┘
```

**Significado:** Problema
- Posible: Puerta abierta, ventilador mal calibrado
- Acción: Revisar sistema de calefacción
- Riesgo: Plantas en estrés por frío

#### Patrón 3: Picos Anómalos

```
30°C │
     │        ╱╲
25°C │ ──────╱  ╲──────
     │
20°C │
     └──────────────────────────────┘
```

**Significado:** Anomalía
- Posible: Sensor defectuoso, puerta abierta momentáneamente
- Acción: Ver "Historial de Eventos" para causa
- Investigar si se repite

#### Patrón 4: Tendencia Creciente

```
30°C │                              ╱
     │                            ╱
25°C │                          ╱
     │                        ╱
20°C │                      ╱
     └────────────────────────────────┘
      0h            12h            24h
```

**Significado:** Calor acumulado
- Posible: Sistema de enfriamiento insuficiente
- Acción: Aumentar ventilación, abrir puertas
- Urgencia: Si supera 30°C

### 5.4 Comparativa de Múltiples Sensores

```
% Humedad vs Temperatura (ejemplo)

TEMP (°C)          HUMEDAD (%)
30│              100│
  │ ╱╲             │   ╱╲╱╲
25│╱  ╲            │ ╱        ╲
  │     ╲         50│          ╲╱╲
20│      ╲╱╲     │              
  └───────────│   └───────────────
```

**Relación esperada:**
- TEMP ↑ → HUMEDAD ↓ (inversamente proporcional)
- Si no ocurre: posible problema en sensor de humedad

### 5.5 Herramientas de Gráficas

**Controles disponibles:**

| Control | Función |
|---|---|
| Selector de rango | Elegir: 24h, 7d, 30d |
| Zoom | Acercar/alejar región específica |
| Mostrar/ocultar | Seleccionar qué sensores mostrar |
| Descargar | Exportar gráfica como PNG/SVG |
| Exportar CSV | Descargar datos en CSV para análisis |
| Actualizar | Forzar actualización manual |

[AGREGA CAPTURA: PANTALLA DE GRÁFICAS]

---

## 6. Cómo Leer el Historial de Eventos y Comandos

### 6.1 Pestaña de Eventos

Presionar **"📋 HISTORIAL"** → **"EVENTOS"**

Muestra log cronológico (más reciente primero):

```
┌─ HISTORIAL DE EVENTOS ──────────────────────┐
│                                             │
│ [FILTRO: todos] [desde] [hasta] [aplicar]   │
│                                             │
│ • 14:35:22 | INFO | Lectura registrada      │
│   Temp: 24.5°C, Humedad: 65%                │
│                                             │
│ • 14:30:45 | ALERTA | Humedad alta          │
│   Sensor zona 1: 85% (límite: 80%)          │
│   Acción: Ventilador activado 100%          │
│                                             │
│ • 14:25:10 | CRÍTICO | Temperatura alta     │
│   Temp: 32°C (límite: 30°C)                 │
│   Acción: Alarma activada, email enviado    │
│                                             │
│ • 14:20:33 | INFO | Comando ejecutado       │
│   Riego manual: ON                          │
│   Duración: 5 minutos                       │
│                                             │
│ • 14:15:50 | ADVERTENCIA | Sensor lento     │
│   Tiempo de respuesta: 2.3s (normal: 0.5s)  │ 
│                                             │
└─────────────────────────────────────────────┘
```

### 6.2 Tipos de Eventos

| Tipo | Color | Descripción |
|---|---|---|
| **INFO** | 🟦 Azul | Operación normal registrada |
| **ADVERTENCIA** | 🟨 Amarillo | Condición fuera de rango normal |
| **ALERTA** | 🟧 Naranja | Acción correctiva activada automáticamente |
| **CRÍTICO** | 🟥 Rojo | Emergencia, requiere intervención |
| **DEBUG** | ⬜ Gris | Información para técnicos (si habilitado) |

### 6.3 Filtros de Eventos

```
Filtros disponibles:
□ INFO (muestra operaciones normales)
□ ADVERTENCIA (condiciones anómalas)
☑ ALERTA (acciones automáticas)
☑ CRÍTICO (emergencias)
□ DEBUG (detalles técnicos)

Rango temporal:
Desde: [2026-01-15] Hasta: [2026-01-16]

Búsqueda por palabra clave:
[                      ] (ej: "temperatura", "riego")
```

### 6.4 Interpretar Eventos Comunes

#### Evento: Temperatura Alta

```
14:25:10 | CRÍTICO | Temperatura superior a 30°C
  Valor: 31.2°C
  Sensor: Zona principal
  Acción: 
    1. Ventilador 100%
    2. Luces OFF
    3. Alarma ON
    4. Email a admin@invernadero.local
  Tiempo de respuesta: 250ms
```

**Qué significa:**
- Sistema detectó temp > umbral
- Tomó acciones automáticas correctivas
- Notificó al administrador

**Acciones:**
1. Verificar abertura de puertas/ventanas
2. Revisar ventilador (¿funciona correctamente?)
3. Medir temperatura manual con termómetro
4. Reiniciar sensor si es defectuoso

#### Evento: Humedad Baja

```
13:50:30 | ADVERTENCIA | Humedad del suelo baja
  Zona: Área 1
  Valor: 15% (recomendado: > 20%)
  Acción: Sistema en espera de manual
```

**Qué significa:**
- Suelo muy seco, riesgo para plantas
- Sistema en MODO MANUAL: requiere decisión del usuario
- En MODO AUTO: activaría riego automático

**Acciones:**
1. Presionar "💧 RIEGO" → ON
2. Esperar 10 minutos
3. Revisar el valor de humedad nuevamente

#### Evento: Sensor Lento

```
12:30:15 | ADVERTENCIA | Tiempo de respuesta alto
  Sensor: Temperatura Zona 1
  Tiempo: 1.8s (normal: 0.3s)
  Causa posible: Cable suelto, interferencia
```

**Qué significa:**
- Sensor responde, pero lentamente
- Puede indicar problema conexión/calibración

**Acciones:**
1. Revisar cable del sensor
2. Limpiar conectores
3. Si persiste: calibrar sensor
4. Último recurso: reemplazar sensor

### 6.5 Pestaña de Comandos

Presionar **"📋 HISTORIAL"** → **"COMANDOS"**

```
┌─ HISTORIAL DE COMANDOS ────────────────┐
│                                        │
│ Buscar: [                           ]  │
│                                        │
│ • 14:35:00 | RIEGO | ON                │
│   Usuario: admin                       │
│   Ejecutado: ✅ Exitoso                │
│   Duración: 5 minutos 23 segundos      │
│   Confirmación recibida: 14:35:05      │
│                                        │
│ • 14:30:00 | VENTILADOR | 100%         │
│   Usuario: admin                       │
│   Ejecutado: ✅ Exitoso                │
│   Respuesta: 120ms                     │
│                                        │
│ • 14:25:00 | LUCES | ON                │
│   Usuario: admin                       │
│   Ejecutado: ❌ Error                  │
│   Código error: -5 (MOSFET fault)      │
│   Acción: Verificar circuito           │
│                                        │
└────────────────────────────────────────┘
```

**Información por comando:**
- Tipo de comando (RIEGO, LUCES, etc.)
- Acción (ON, OFF, porcentaje)
- Usuario que lo ejecutó
- Estado (✅ Exitoso / ❌ Error)
- Timestamp exacto
- Tiempo de ejecución
- Código de error (si aplica)

---

## 7. Cómo Interpretar la Sección de Análisis ARM64

### 7.1 Acceso a Resultados ARM64

Presionar pestaña **"🔬 ANÁLISIS ARM64"**

### 7.2 Descripción General

```
┌─ ANÁLISIS ESTADÍSTICO (ARM64) ───────────────┐
│                                              │
│ Última ejecución: hace 5 minutos             │
│ Próxima ejecución: en 10 minutos             │
│ Intervalo: cada 15 minutos                   │
│                                              │
│ [EJECUTAR AHORA] [DESCARGAR CSV]             │
│                                              │
├──────────────────────────────────────────────┤
│ MÓDULO 1: MEDIA PONDERADA                    │
├──────────────────────────────────────────────┤
│ Temperatura media ponderada: 24.3°C          │
│ Datos procesados: 30 registros               │
│ Conclusión: Normal                           │
│                                              │
├──────────────────────────────────────────────┤
│ MÓDULO 2: VARIANZA Y DESVIACIÓN ESTÁNDAR     │
├──────────────────────────────────────────────┤
│ Media: 24.5°C                                │
│ Varianza: 3.2°C²                             │
│ Desviación Estándar: 1.8°C                   │
│ Conclusión: Datos bien dispersos (normal)    │
│                                              │
│ 📊 Gráfica de distribución:                  │
│    ░░░                                       │
│    ███░░░                                    │
│    ███████░                                  │
│    ════════────────                          │
│    20°C 24°C 28°C                            │
│                                              │
├──────────────────────────────────────────────┤
│ MÓDULO 3: DETECCIÓN DE ANOMALÍAS             │
├──────────────────────────────────────────────┤
│ Anomalías detectadas: 0                      │
│ Umbral Z-score: ±3 desv. estándar            │
│ Nivel de riesgo: ✅ NORMAL                   │
│                                              │
│ Conclusión: Ningún valor atípico             │
│                                              │
├──────────────────────────────────────────────┤
│ MÓDULO 4: PREDICCIÓN LINEAL                  │
├──────────────────────────────────────────────┤
│ Humedad Suelo 2 - Predicción:                │
│ Valor actual: 42.6%                          │
│ Valor predicho (próximo): 41.8%              │
│ Cambio esperado: -0.8% por período           │
│                                              │
│ ⚠️ Recomendación: Activar riego en 2h        │
│ (Cuando humedad < 30%)                       │
│                                              │
├──────────────────────────────────────────────┤
│ MÓDULO 5: TENDENCIA ACUMULADA                │
├──────────────────────────────────────────────┤
│ Temperatura - Análisis de Tendencia:         │
│ Incrementos: 14 subidas                      │
│ Decrementos: 15 bajadas                      │
│ Racha máxima UP: 3 consecutivas              │
│ Racha máxima DOWN: 4 consecutivas            │
│ Tendencia general: ➡️ ESTABLE                │
│                                              │
│ 📈 Gráfica de cambios:                       │
│    ┌─ ─ ─ ─ ─┐                               │
│    │  ╱╲ ╱╲  │ Oscilante                     │
│    │╱    ╲  ╲╱                               │
│    └─────────┘                               │
│                                              │
└──────────────────────────────────────────────┘
```

### 7.3 Módulo 1: Media Ponderada

```
┌─ MEDIA PONDERADA ────────────────────┐
│                                      │
│ Temperatura Media: 24.3°C            │
│                                      │
│ Fórmula:                             │
│ Σ(X_i × W_i) / Σ(W_i)                │
│ donde W_i = 1,2,3...30               │
│ (pesos mayores para datos recientes) │
│                                      │
│ Datos: 30 lecturas de temperatura    │
│ Rango: 22.1°C a 26.8°C               │
│ Suma simple: 735°C (media 24.5°C)    │
│                                      │
│ Diferencia:                          │
│ Media ponderada (24.3°C)             │
│ vs Media simple (24.5°C)             │
│ = -0.2°C (ligero sesgo a baja)       │
│                                      │
│ Interpretación:                      │
│ ✅ Normal - Datos recientes          │
│    son ligeramente más fríos         │
│                                      │
└──────────────────────────────────────┘
```

**Cuándo usar:**
- Para tendencias recientes (último sesgo)
- Para control predictivo (reaccionar a cambios)
- Para auditoría (peso en mediciones recientes)

### 7.4 Módulo 2: Varianza y Desviación Estándar

```
┌─ VARIANZA Y DESVIACIÓN ESTÁNDAR ──┐
│                                   │
│ Media: 24.5°C                     │
│ Varianza (σ²): 3.2°C²             │
│ Desviación Est. (σ): 1.8°C        │
│                                   │
│ Distribución de datos:            │
│ μ - 3σ = 19.1°C  ┐                │
│ μ - 2σ = 21.0°C  │                │
│ μ - σ  = 22.7°C  │ Esperado:      │
│ μ      = 24.5°C  │ ~95% de datos  │
│ μ + σ  = 26.2°C  │ en este rango  │
│ μ + 2σ = 28.0°C  │                │
│ μ + 3σ = 29.9°C  ┘                │
│                                   │
│ Rango real: 22.1-26.8°C (OK)      │
│                                   │
│ Conclusión:                       │
│ ✅ Dispersión normal              │
│ Datos homogéneos                  │
│ Sistema en equilibrio             │
│                                   │
└───────────────────────────────────┘
```

**Interpretar dispersión:**
- σ < 1°C: Datos muy concentrados (poco cambio)
- σ = 1-3°C: Normal (variación esperada)
- σ > 5°C: Datos muy dispersos (revisar sistema)

### 7.5 Módulo 3: Detección de Anomalías

```
┌─ DETECCIÓN DE ANOMALÍAS ──────────┐
│                                   │
│ Z-Score: ±3 desviaciones estándar │
│                                   │
│ Rango normal: [19.1°C, 29.9°C]    │
│                                   │
│ Anomalías detectadas: 0           │
│                                   │
│ Distribuir de anomalías:          │
│ Ninguna por fuera de límites      │
│                                   │
│ Nivel de Riesgo: ✅ NORMAL        │
│                                   │
│ Tabla de riesgo:                  │
│ 0 anomalías       → NORMAL        │
│ 1-2 anomalías     → MEDIUM        │
│ ≥ 3 anomalías     → HIGH          │
│                                   │
│ Acciones recomendadas:            │
│ ✅ Continuar monitoreo normal     │
│                                   │
└───────────────────────────────────┘
```

**Si hay anomalías:** Revisar eventos para causa posible

### 7.6 Módulo 4: Predicción Lineal

```
┌─ PREDICCIÓN LINEAL ────────────────┐
│                                    │
│ Variable: HUM_SUELO_2              │
│                                    │
│ Valor Inicial: 48.0%               │
│ Valor Final: 35.0%                 │
│ Cambio total: -13.0%               │
│ Períodos: 29 (entre 30 registros)  │
│                                    │
│ Cambio promedio: -0.45% / período  │
│ Predicción próximo: 34.55%         │
│                                    │
│ Timeline:                          │
│ Ahora:   42.6% ████░░░░░░░░░░░░    │
│ +5min:   42.2% ████░░░░░░░░░░░░    │
│ +30min:  40.0% ███░░░░░░░░░░░░░    │
│ +2h:     29.2% ██░░░░░░░░░░░░░░    │
│                                    │
│ ⚠️ ALERTA PREDICCIÓN:              │
│ Humedad baja en ~2 horas           │
│ Acción recomendada: Activar riego  │
│                                    │
│ Confianza: 75% (modelo lineal)     │
│                                    │
└────────────────────────────────────┘
```

**Cómo usar para control automático:**
```
IF predicción < 25% IN NEXT 2_HOURS:
  → Activar riego preventivamente
  
IF predicción > 80% IN NEXT 2_HOURS:
  → Desactivar riego
  → Aumentar ventilación
```

### 7.7 Módulo 5: Tendencia Acumulada

```
┌─ TENDENCIA ACUMULADA ──────────────┐
│                                    │
│ Variable: Temperatura              │
│                                    │
│ Incrementos: 14 (subidas)          │
│ Decrementos: 15 (bajadas)          │
│ Estable: 0 (sin cambio)            │
│                                    │
│ Racha máxima UP: 3 consecutivas    │
│ Racha máxima DOWN: 4 consecutivas  │
│                                    │
│ Diferencia acumulada: -1           │
│ (-1 significa ligeramente bajista) │
│                                    │
│ Tendencia General: ➡️ ESTABLE      │
│ (Incrementos ≈ Decrementos)        │
│                                    │
│ Gráfica de cambios:                │
│ ╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱             │
│ (oscilaciones de corta amplitud)   │
│                                    │
│ Conclusión:                        │
│ ✅ Sistema en equilibrio dinámico  │
│ Las fluctuaciones son normales     │
│                                    │
│ Recomendación:                     │
│ Mantener configuración actual      │
│                                    │
└────────────────────────────────────┘
```

### 7.8 Botones de Acción

| Botón | Función |
|---|---|
| 🔄 Ejecutar Ahora | Fuerza análisis inmediato (no esperar 15 min) |
| 📥 Descargar CSV | Exporta datos analizados en formato CSV |
| 📊 Exportar PDF | Genera reporte visual en PDF |
| 🔔 Habilitar Alertas | Notificaciones automáticas cuando detecta anomalías |
| ⚙️ Configurar | Ajusta intervalos y umbrales |

---

## 8. Troubleshooting y Errores Comunes

### 8.1 El Dashboard No Carga

**Error:** Pantalla blanca o "404 Not Found"

**Causas posibles:**
1. Frontend no está corriendo
2. Puerto 5173 está en uso
3. Backend no responde
4. Problema de red

**Soluciones:**
```bash
# 1. Verificar que frontend está corriendo
cd frontend
pnpm dev

# 2. Si puerto está en uso, cambiar puerto
pnpm dev --port 3000
# Acceder a http://localhost:3000

# 3. Verificar backend
curl http://localhost:8000/api/health
# Debe devolver JSON con status "ok"

# 4. Limpiar caché navegador
Ctrl+Shift+R (Windows/Linux)
Cmd+Shift+R (Mac)
```

### 8.2 Conexión a Backend Perdida

**Error:** Página carga pero todo gris, "Backend no disponible"

**Causas posibles:**
1. Backend caído
2. MongoDB desconectada
3. Firewall bloqueando puerto 8000
4. CORS mal configurado

**Soluciones:**
```bash
# 1. Verificar backend está corriendo
cd backend
source .venv/bin/activate
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000

# 2. Verificar MongoDB
curl mongodb://localhost:27017  # Debe conectar

# 3. Verificar CORS en .env
# CORS_ORIGINS=http://localhost:5173

# 4. Reiniciar todo
Ctrl+C (en todas las terminales)
# Reiniciar backend primero, luego frontend
```

### 8.3 Sensores Muestran "N/A" o "--"

**Error:** Valores de sensores no se actualizan

**Causas:**
1. Simulador no está corriendo
2. MQTT desconectado
3. Sensor defectuoso
4. CSV vacío

**Soluciones:**
```bash
# 1. Iniciar simulador
cd backend
source .venv/bin/activate
python3 simulador.py --scenario ninguno

# 2. Verificar MQTT en logs
# Debe decir "MQTT connected"

# 3. Reiniciar app
Ctrl+F5 en navegador

# 4. Generar datos de prueba
python3 generate_lecturas.py --from-db
```

### 8.4 Comandos No Se Ejecutan (Botones No Responden)

**Error:** Presionar "Riego ON" pero nada pasa

**Causas:**
1. Backend no responde
2. Modo MANUAL no activado
3. Error de permisos
4. MQTT desconectado

**Soluciones:**
```bash
# 1. Verificar backend está vivo
curl http://localhost:8000/api/status

# 2. Verificar que está en MODO AUTO o MANUAL está permitido
# Cambiar modo en dashboard

# 3. Ver logs del backend
# Buscar errores en terminal

# 4. Reiniciar conexión MQTT
# En dashboard: Sistema → Reconectar
```

### 8.5 Gráficas Muestran Línea Recta

**Error:** Gráfica no oscila, solo línea plana

**Causas:**
1. Datos insuficientes (< 24h)
2. Todos los valores iguales (sistema muy estable)
3. Bug de rendering

**Soluciones:**
```bash
# 1. Esperar 24 horas para historial completo

# 2. Cambiar rango temporal
# Selector de gráfica: cambiar a "7 días"

# 3. Actualizar página
F5 o Cmd+R

# 4. Si persiste, contactar soporte
```

### 8.6 Análisis ARM64 Dice "Sin datos"

**Error:** Módulos muestran "No results found"

**Causas:**
1. Análisis nunca se ejecutó
2. CSV vacío
3. Archivos de resultado faltantes

**Soluciones:**
```bash
# 1. Ejecutar análisis manualmente
cd arm64
make all
make runall

# 2. Verificar que results/ tiene archivos
ls -la results/
# Debe haber: resultado_media.txt, resultado_varianza.txt, etc.

# 3. Forzar upload al backend
cd ../raspberry
python3 arm_executor.py --parse-only --dir ../arm64 --url http://localhost:8000

# 4. Actualizar dashboard
Ctrl+R
```

### 8.7 Tabla Comparativa de Errores

| Error | Síntoma | Causa | Solución |
|---|---|---|---|
| **500 Internal** | Rojo en backend | Error en código | Ver logs backend |
| **Connection Timeout** | Gris/sin respuesta | RED caída | Verificar WiFi/Ethernet |
| **404 Not Found** | Endpoint no existe | Versión mismatch | Actualizar código |
| **Unauthorized** | No autorizado | CORS/Auth | Verificar configuración |
| **Database Error** | MongoDB falla | Base datos offline | Reiniciar MongoDB |

---

## 9. Especificaciones de Rangos y Alarmas

### 9.1 Tabla de Rangos Normales

| Sensor | Mín | Óptimo | Máx | Unidad |
|---|---|---|---|---|
| **Temperatura** | 15°C | 22-26°C | 35°C | °C |
| **Humedad Aire** | 30% | 60-75% | 95% | % |
| **Luz Zona 1** | 50 | 400-600 | 2000 | lux |
| **Luz Zona 2** | 50 | 300-500 | 2000 | lux |
| **Humedad Suelo 1** | 10% | 40-60% | 90% | % |
| **Humedad Suelo 2** | 10% | 40-60% | 90% | % |
| **Gas (CO2)** | 300 | 400-800 | 1200 | ppm |

### 9.2 Umbrales de Alarma

| Condición | Valor | Acción |
|---|---|---|
| **Temp > 30°C** | 30°C | Ventilador 100%, Alarma, Email |
| **Temp < 15°C** | 15°C | Calefacción ON, Email |
| **Humedad Aire > 90%** | 90% | Ventilador ON, Reducir riego |
| **Humedad Aire < 30%** | 30% | Aumentar riego, Humidificador |
| **Suelo < 20%** | 20% | Riego automático si AUTO |
| **Suelo > 85%** | 85% | Detener riego, Drenaje |
| **Gas > 1000 ppm** | 1000 | Emergencia, Evacuar, Alarma |
| **Luz < 100 lux** | 100 | Luces ON (si horario) |

### 9.3 Tiempos de Respuesta Esperados

| Sistema | Normal | Máximo Aceptable |
|---|---|---|
| Dashboard update | 1-2s | 5s |
| Backend response | 50-200ms | 1000ms |
| MQTT publish | 100-500ms | 2000ms |
| Actuador response | 500-1000ms | 3000ms |
| Análisis ARM64 | 2-5s | 15s |

---

## 10. Características Avanzadas

### 10.1 Configuración de Umbrales Personalizados

En futuras versiones, acceso a:
```
⚙️ CONFIGURACIÓN → Umbrales
├─ Temperatura Máxima: [_____°C]
├─ Temperatura Mínima: [_____°C]
├─ Humedad Máxima: [_____%)
├─ Humedad Mínima: [_____%)
├─ Tiempo Riego Máximo: [_____min]
└─ [GUARDAR]
```

### 10.2 Exportación de Datos

Generar reportes CSV/Excel:
```
Período: [Desde] [Hasta]
Incluir:
  ☑ Sensores
  ☑ Comandos
  ☑ Eventos
  ☑ Análisis ARM64
  
[EXPORTAR]
```

### 10.3 API REST para Integración

Documentación en: `http://localhost:8000/docs`

Ejemplos:
```bash
# Obtener último valor de temperatura
curl http://localhost:8000/api/sensors/temperatura/latest

# Activar riego
curl -X POST http://localhost:8000/api/control/riego \
  -H "Content-Type: application/json" \
  -d '{"action":"on", "duration_minutes": 5}'

# Obtener análisis ARM64
curl http://localhost:8000/api/arm64/results
```





