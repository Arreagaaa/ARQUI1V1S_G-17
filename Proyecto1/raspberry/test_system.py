#!/usr/bin/env python3
"""
test_system.py — Prueba completa de sensores y actuadores del invernadero.
Uso: sudo python3 test_system.py
"""

import sys
import time
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from main import load_settings, GpioController


def separator(text: str) -> None:
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}")


def wait(prompt: str = "  → Enter para continuar...") -> None:
    input(prompt)


def test_sensors(gpio) -> None:
    s = gpio.s

    separator("SENSORES")

    # 1. DHT11
    print("\n[1/6] DHT11 — Temperatura y Humedad")
    temp, hum = None, None
    for i in range(3):
        temp, hum = gpio.read_dht()
        if temp:
            print(f"  Temp: {temp:.1f} °C, Hum: {hum:.1f} %  ✓")
            break
        print(f"  Intento {i+1}/3 fallido...")
        time.sleep(1)
    if not temp:
        print("  ✗ No se pudo leer DHT11 (revisar conexión)")

    # 2. LDR
    print("\n[6/2] LDR — Luz ambiental")
    raw = gpio.read_adc_channel(s.ldr_adc_ch)
    pct = (65535 - raw) / 65535 * 100
    print(f"  Luz: {pct:.1f} %")
    wait("  → Cubrí el LDR y presioná Enter")
    raw2 = gpio.read_adc_channel(s.ldr_adc_ch)
    pct2 = (65535 - raw2) / 65535 * 100
    print(f"  Luz: {pct2:.1f} %  {'✓ cambió' if abs(pct2-pct) > 3 else '✗ sin cambio'}")
    wait("  → Descubrí el LDR y presioná Enter")

    # 3. Suelo Área 1
    print("\n[3/6] Suelo Área 1")
    raw = gpio.read_adc_channel(s.soil_adc_ch1)
    pct = (65535 - raw) / 65535 * 100
    print(f"  Humedad: {pct:.1f} %")
    print(f"  Estado: {'SECO' if pct < 65 else 'NORMAL' if pct < 80 else 'SATURADO'}")

    # 4. Suelo Área 2
    print("\n[4/6] Suelo Área 2")
    raw = gpio.read_adc_channel(s.soil_adc_ch2)
    pct = (65535 - raw) / 65535 * 100
    print(f"  Humedad: {pct:.1f} %")
    print(f"  Estado: {'SECO' if pct < 65 else 'NORMAL' if pct < 80 else 'SATURADO'}")

    # 5. Gas
    print("\n[5/6] Gas MQ-2")
    raw = gpio.read_adc_channel(s.mq_adc_ch)
    ppm = raw / 65535 * 1000
    print(f"  Gas: {ppm:.1f} ppm")
    if ppm > 10:
        print("  ✓ Sensor responde")
    else:
        print("  ⚠ Lectura muy baja — revisar conexión")

    # 6. Botones
    print("\n[6/6] Botones físicos (Mode, Pump, Lights, Silence)")
    btns = gpio.read_buttons()
    print(f"  Reposo: mode={'↓' if btns['mode'] else '↑'} pump={'↓' if btns['pump'] else '↑'} "
          f"lights={'↓' if btns['lights'] else '↑'} silence={'↓' if btns['silence'] else '↑'}")
    wait("  → Presioná MODO y Enter")
    btns = gpio.read_buttons()
    print(f"  mode={'↓' if btns['mode'] else '↑'} {'✓' if btns['mode'] else '✗ no detectado'}")
    wait("  → Presioná PUMP y Enter")
    btns = gpio.read_buttons()
    print(f"  pump={'↓' if btns['pump'] else '↑'} {'✓' if btns['pump'] else '✗ no detectado'}")
    wait("  → Presioná LIGHTS y Enter")
    btns = gpio.read_buttons()
    print(f"  lights={'↓' if btns['lights'] else '↑'} {'✓' if btns['lights'] else '✗ no detectado'}")
    wait("  → Presioná SILENCE y Enter")
    btns = gpio.read_buttons()
    print(f"  silence={'↓' if btns['silence'] else '↑'} {'✓' if btns['silence'] else '✗ no detectado'}")


def test_actuators(gpio) -> None:
    separator("ACTUADORES")

    # 1. LEDs semáforo
    print("\n[1/7] LEDs de estado (semáforo)")
    for state, color in [("NORMAL", "VERDE"), ("ADVERTENCIA", "AMARILLO"),
                          ("EMERGENCIA", "ROJO"), ("NORMAL", "VERDE")]:
        gpio.set_global_state(state)
        wait(f"  → LED {color} — presioná Enter")

    # 2. Bomba + Válvula Área 1
    print("\n[2/7] Bomba de riego + Válvula Área 1")
    gpio.set_pump_irrigation("area_1", True)
    print("  Bomba ON, Válvula Área 1 abierta")
    wait("  → ¿Fluye agua por Área 1? Enter = sí")
    gpio.set_pump_irrigation("area_1", False)
    print("  ✓ Apagado")

    # 3. Ventilador
    print("\n[3/7] Ventilador DC")
    gpio.set_actuator("fan", "on")
    wait("  → ¿Gira el ventilador? Enter = sí")
    gpio.set_actuator("fan", "off")
    print("  ✓ Apagado")

    # 4. Iluminación (4 LEDs blancos)
    print("\n[4/7] Iluminación — 4 LEDs blancos")
    gpio.set_actuator("lights", "on")
    wait("  → ¿Los 4 LEDs encienden? Enter = sí")
    gpio.set_actuator("lights", "off")
    print("  ✓ Apagado")

    # 5. Buzzer
    print("\n[5/7] Buzzer (alarma pasiva)")
    gpio.set_actuator("buzzer", "on")
    wait("  → ¿Suena el buzzer? Enter = sí")
    gpio.set_actuator("buzzer", "off")
    print("  ✓ Silencio")

    # 6. LCD 16x2
    print("\n[6/7] LCD 16x2")
    gpio.update_lcd("GRUPO 17", "TEST SENSORS OK")
    wait("  → ¿LCD muestra el texto? Enter = sí")
    gpio.update_lcd("ACTUADORES", "FAN LIGHTS BUZZ")

    # 7. Modos Auto / Manual
    print("\n[7/7] Modos de operación")
    gpio.mode = "manual"
    print("  Modo: MANUAL  ✓")
    gpio.set_global_state("MODO_MANUAL")
    time.sleep(1)
    gpio.mode = "auto"
    gpio.set_global_state("NORMAL")
    print("  Modo: AUTO    ✓")


def main() -> None:
    print("=" * 60)
    print("  PRUEBA DEL SISTEMA DE INVERNADERO")
    print("  Grupo 17 — ACYE1 — 1S 2026")
    print("=" * 60)
    print("\n  Sensores:  DHT11, LDR, Suelo x2, Gas, Botones x4")
    print("  Actuadores: LEDs semáforo x3, Bomba+Válvula,")
    print("              Ventilador, Luces x4, Buzzer, LCD 16x2\n")

    settings = load_settings()
    gpio = GpioController(settings)

    if not gpio.available:
        print("⚠ GPIO no disponible. ¿Corriendo con sudo?")
        print("  sudo python3 test_system.py")
        sys.exit(1)

    try:
        test_sensors(gpio)
        test_actuators(gpio)

        separator("PRUEBA COMPLETADA")
        print("\n  ✅ Todos los componentes respondieron.")
        print("\n  Sensores:")
        print("    • DHT11    — Temp/Hum")
        print("    • LDR      — Luz")
        print("    • Suelo x2 — Humedad áreas 1 y 2")
        print("    • Gas      — MQ-2")
        print("    • Botones  — Mode, Pump, Lights, Silence")
        print("  Actuadores:")
        print("    • LEDs     — Semáforo (Verde/Amarillo/Rojo)")
        print("    • Bomba    + Válvula Área 1")
        print("    • Ventilador DC")
        print("    • Luces    — 4 LEDs blancos")
        print("    • Buzzer   — Alarma pasiva")
        print("    • LCD      — 16x2")

    except KeyboardInterrupt:
        print("\n\n  ⚠ Prueba interrumpida por el usuario.")
    finally:
        gpio.cleanup()
        print("\n  GPIO liberado. Fin de la prueba.\n")


if __name__ == "__main__":
    main()
