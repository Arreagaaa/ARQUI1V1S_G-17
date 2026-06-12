# Guía de Conexión Física — Raspberry Pi 3 al Invernadero

## Diagrama de Pines GPIO (BCM)

*Numeración: **BCM** (Broadcom) en el código; **Física** (header J8) entre paréntesis.*

```
              J8 – 40-pin Header (Raspberry Pi 3)
+-----+--------+--------+--------+-----+
| Fís |  BCM   | Nombre |  BCM   | Fís |
+-----+--------+--------+--------+-----+
|  1  |   —    | 3.3V   |  5V    |  2  |
|  3  | GPIO2  | SDA    |  5V    |  4  |
|  5  | GPIO3  | SCL    |  GND   |  6  |
|  7  | GPIO4  |BTN_MODE| GPIO14 |  8  | ← libre
|  9  |   —    | GND    | GPIO15 | 10  | → BTN_SILENCE
| 11  | GPIO17 | PUMP   | GPIO18 | 12  | → BTN_LIGHTS
| 13  | GPIO27 |VALVE_A1|  GND   | 14  |
| 15  | GPIO22 |VALVE_A2| GPIO23 | 16  | → FAN
| 17  |   —    | 3.3V   | GPIO24 | 18  | → LIGHTS
| 19  | GPIO10 |  libre |  GND   | 20  |
| 21  | GPIO9  |  libre | GPIO25 | 22  | → BUZZER
| 23  | GPIO11 |  libre | GPIO8  | 24  | → BTN_PUMP
| 25  |   —    | GND    | GPIO7  | 26  | → libre
| 27  | GPIO0  |LCD_D7  | GPIO1  | 28  | ← libre
| 29  | GPIO5  |LED_GREEN|  GND  | 30  |
| 31  | GPIO6  |LED_YELL | GPIO12 | 32  | → LED_RED
| 33  | GPIO13 |LCD_RS  |  GND   | 34  |
| 35  | GPIO19 |LCD_E   | GPIO16 | 36  | → LCD_D4
| 37  | GPIO26 |DHT_DATA| GPIO20 | 38  | → LCD_D5
| 39  |   —    | GND    | GPIO21 | 40  | → LCD_D6
+-----+--------+--------+--------+-----+
```

> **IMPORTANTE**: El código usa numeración **BCM** (GPIOxx). La numeración física del header es diferente.
>
> El ADC usa **ADS1115/ADS1015 por I2C** (no SPI). GPIO 9, 10, 11, 7 quedan libres.

---

## Tabla de Conexiones

| Componente | Pin BCM | Pin Físico | Conexión |
|---|---|---|---|
| **Bomba (relé)** | GPIO 17 | 11 | OUT → relé bomba |
| **Válvula Área 1** | GPIO 27 | 13 | OUT → relé válvula |
| **Válvula Área 2** | GPIO 22 | 15 | NO INSTALADA |
| **Ventilador** | GPIO 23 | 16 | OUT → relé ventilador |
| **Luces** | GPIO 24 | 18 | OUT → relé luces LED |
| **Buzzer** | GPIO 25 | 22 | OUT → buzzer + transistor |
| **LED Verde (NORMAL)** | GPIO 5 | 29 | OUT → LED + 220Ω → GND |
| **LED Amarillo (ADVERTENCIA)** | GPIO 6 | 31 | OUT → LED + 220Ω → GND |
| **LED Rojo (EMERGENCIA)** | GPIO 12 | 32 | OUT → LED + 220Ω → GND |
| **LCD (I2C backpack)** | SDA=GPIO2, SCL=GPIO3 | 3,5 | I2C + VCC(5V) + GND |

### LCD — Fallback Paralelo (solo si NO usas I2C backpack)

| LCD Pin | GPIO BCM | Físico |
|---|---|---|
| RS | 13 | 33 |
| E | 19 | 35 |
| D4 | 16 | 36 |
| D5 | 20 | 38 |
| D6 | 21 | 40 |
| D7 | 0 | 27 |
| VCC | — | 5V (pin 2 o 4) |
| GND | — | GND |
| V0 (contraste) | — | potenciómetro 10k a GND |

> **Recomendación**: Usar I2C backpack (PCF8574). Solo 4 cables (VCC, GND, SDA, SCL) y el código lo detecta automáticamente.

### Botones (todos con pull-up interno)

| Botón | GPIO BCM | Físico | Conexión |
|---|---|---|---|
| MODE (auto/manual) | 4 | 7 | Botón → GND |
| PUMP (riego manual) | 8 | 24 | Botón → GND |
| LIGHTS (luces manual) | 18 | 12 | Botón → GND |
| SILENCE (silencio buzzer) | 15 | 10 | Botón → GND |

*Configuración pull-up interno en GPIO.PUD_UP. Sin resistencias externas.*

### Sensores

#### DHT11/DHT22
| DHT Pin | Conexión |
|---|---|
| VCC (pin 1) | 3.3V (pin 1) |
| DATA (pin 2) | GPIO 26 (BCM) — pin 37 físico |
| NC (pin 3) | sin conectar |
| GND (pin 4) | GND |
| Resistencia pull-up | 10kΩ entre VCC y DATA |

#### ADS1115/ADS1015 — ADC por I2C

| ADS1115 Pin | Conexión |
|---|---|
| VDD | 3.3V |
| GND | GND |
| SCL | GPIO 3 (SCL) — pin 5 (I2C compartido con LCD) |
| SDA | GPIO 2 (SDA) — pin 3 (I2C compartido con LCD) |
| ADDR | GND (dirección 0x48) o VDD (0x49) |
| A0 | LDR (fotorresistencia + divisor de voltaje 10kΩ) |
| A1 | Higrómetro Área 1 |
| A2 | Higrómetro Área 2 |
| A3 | MQ-2/135 (salida analógica) |

> Usa **I2C**, no SPI. No requiere configurar nada en `raspi-config` (I2C ya viene habilitado si usás LCD con I2C backpack). El LCD y el ADS1115/ADS1015 comparten el mismo bus I2C. |

**Divisor de voltaje para LDR:**
```
3.3V ──┬── LDR ──┬── a CH0 del MCP3008
       │         │
       └─ 10kΩ ──┘
                 │
                GND
```

**Conexión MQ-2/135:**
- Pin DO (digital) → sin usar (usamos salida analógica)
- Pin AO (analógico) → CH3 del MCP3008
- VCC → 5V
- GND → GND
- *Tiempo de pre-calentamiento: ~30 segundos*

### Relés (bomba, válvula, ventilador, luces)

Cada relé se conecta como:
```
GPIO ──┬── 1kΩ ── Base(NPN 2N2222) ── Emisor ── GND
       │
       └── 1N4007 ──┐ (diodo flyback)
                    │
                Coil(Relé)
                    │
                  VCC(5V/12V según relé)
```
O usar módulos relé activos por HIGH (comunes en IoT).

---

## Lista de Materiales

| Cantidad | Componente |
|---|---|
| 1 | Raspberry Pi 3 (o 4) |
| 1 | DHT11 o DHT22 (temperatura + humedad) |
| 1 | MCP3008 (ADC 8-canales 10-bit) |
| 1 | LDR (fotorresistencia) |
| 2 | Higrómetro de suelo (FC-28 o YL-69) |
| 1 | MQ-2 o MQ-135 (sensor de gas) |
| 4 | Relé 5V (bomba, válvula, ventilador, luces) |
| 1 | Bomba de agua 12V + fuente |
| 1 | Válvula solenoide 12V (Área 1) |
| 1 | Ventilador DC 5V/12V |
| 1 | Buzzer activo 5V |
| 3 | LED 5mm (verde, amarillo, rojo) |
| 3 | Resistor 220Ω (LEDs) |
| 1 | Resistor 10kΩ (pull-up DHT) |
| 4 | Resistor 1kΩ (bases transistores relés) |
| 1 | Resistencia 10kΩ (divisor LDR) |
| 1 | Potenciómetro 10kΩ (contraste LCD) |
| 4 | Push buttons (táctiles) |
| 1 | LCD 16×2 + I2C backpack (PCF8574) |
| 4 | Diodo 1N4007 (flyback relés) |
| 4 | Transistor NPN 2N2222 (drivers relés) |
| 1 | Fuente 5V/3A (Raspberry Pi) |
| 1 | Fuente 12V/2A (bomba + válvula) |
| - | Cables dupont, protoboard, cableado |

---

## Configuración Inicial en Raspberry Pi

```bash
# 1. Deshabilitar consola serial (libera GPIO 14/15 para botones SILENCE y MODE)
sudo raspi-config
# → Interfacing Options → Serial Port → NO (login shell) → YES (hardware)

# 2. Instalar dependencias
cd Proyecto1/raspberry
pip install -r requirements.txt

# 3. Configurar .env
cp .env.example .env
nano .env
# → ENABLE_GPIO=true
# → BACKEND_URL=http://<IP-del-backend>:8000

# 4. Probar
python main.py
```

## Verificación Rápida

1. Sin sensores conectados: `ENABLE_GPIO=false` → dry-run (todo simulado)
2. Solo DHT: conecta DHT y verifica que se lean temperatura/humedad
3. Solo MCP3008: ejecuta `python3 -c "
import RPi.GPIO as GPIO
GPIO.setmode(GPIO.BCM)
# ... probar lectura de canal 0
"` (script de prueba)
4. Sistema completo: ejecuta `python main.py` y verifica:
   - Conexión MQTT exitosa
   - Lecturas en backend
   - Botones responden
   - LCD muestra datos
   - LEDs reflejan estado
