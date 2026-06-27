#!/usr/bin/env python3
"""
Orquestador del Invernadero Inteligente — Fase 2 (Seccion 4.20)

Ciclo principal:
  1. Lee sensores (GPIO real o datos de prueba)
  2. Envia lectura CSV al motor ARM64 via stdin
  3. Recibe la decision estructurada (ACCION/TARGET/RISK/REASON/VALUE/INDICATOR/STATUS)
  4. Ejecuta la accion en GPIO
  5. Registra la decision en MongoDB via API REST
  6. Se repite en ciclo infinito hasta Ctrl+C

Modos:
  test      — datos de prueba predefinidos (default)
  realtime  — sensores GPIO reales (Raspberry Pi)
  file      — archivo CSV con lecturas

Uso:
  python3 orquestador.py
  python3 orquestador.py --mode realtime --interval 3
  python3 orquestador.py --mode file --file lecturas.csv
  python3 orquestador.py --api-url https://api.mi-servidor.com --no-mongo
"""

import argparse
import os
import signal
import subprocess
import sys
import time
from typing import Optional

import requests

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------

ARM64_PROGRAM = os.path.realpath(
    os.path.join(os.path.dirname(__file__), "..", "build", "live_engine")
)
API_BASE_DEFAULT = os.environ.get("API_URL", "http://localhost:8000")
INTERVALO_DEFAULT = 2

ACCIONES = {
    "ALARM_ON":    {"desc": "Alarma activada por gas critico",            "pin": 17, "actuator": "buzzer"},
    "RIEGO_1_ON":  {"desc": "Riego del area 1 activado",                 "pin": 18, "actuator": "valve_1"},
    "RIEGO_2_ON":  {"desc": "Riego del area 2 activado",                 "pin": 19, "actuator": "valve_2"},
    "FAN_ON":      {"desc": "Ventilador encendido",                      "pin": 20, "actuator": "fan"},
    "LIGHT_ON":    {"desc": "Iluminacion artificial encendida",          "pin": 21, "actuator": "light"},
    "LED_GREEN":   {"desc": "Estado normal — todo en parametros",        "pin": 22, "actuator": "led_green"},
    "LED_YELLOW":  {"desc": "Estado de advertencia",                     "pin": 23, "actuator": "led_yellow"},
    "LED_RED":     {"desc": "Estado de riesgo alto",                     "pin": 24, "actuator": "led_red"},
    "NO_ACTION":   {"desc": "Sin accion fisica requerida",               "pin": None, "actuator": None},
}

_ACCIONES_CON_PIN = {k: v for k, v in ACCIONES.items() if v["pin"] is not None}

# ---------------------------------------------------------------------------
# GPIO — RPi.GPIO con fallback simulado
# ---------------------------------------------------------------------------

try:
    import RPi.GPIO as GPIO
    GPIO_AVAILABLE = True
except ImportError:
    GPIO_AVAILABLE = False


def gpio_setup():
    if not GPIO_AVAILABLE:
        print("[GPIO] RPi.GPIO no disponible — modo simulado")
        return
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    for nombre, info in _ACCIONES_CON_PIN.items():
        GPIO.setup(info["pin"], GPIO.OUT)
        GPIO.output(info["pin"], GPIO.LOW)
    print(f"[GPIO] {len(_ACCIONES_CON_PIN)} pines configurados como salida")


def gpio_cleanup():
    if not GPIO_AVAILABLE:
        return
    for nombre, info in _ACCIONES_CON_PIN.items():
        try:
            GPIO.output(info["pin"], GPIO.LOW)
        except Exception:
            pass
    GPIO.cleanup()
    print("[GPIO] Pines liberados")


_accion_actual: Optional[str] = None


def ejecutar_accion_en_gpio(accion: str):
    global _accion_actual
    if accion == _accion_actual:
        return
    if GPIO_AVAILABLE:
        for nombre, info in _ACCIONES_CON_PIN.items():
            try:
                GPIO.output(info["pin"], GPIO.HIGH if nombre == accion else GPIO.LOW)
            except Exception:
                pass
        pin = ACCIONES.get(accion, {}).get("pin")
        if pin is not None:
            print(f"[GPIO] {accion} -> PIN {pin}")
    _accion_actual = accion


# ---------------------------------------------------------------------------
# Sensores
# ---------------------------------------------------------------------------

def leer_sensores_realtime() -> Optional[str]:
    try:
        if GPIO_AVAILABLE:
            import Adafruit_DHT
            hum, temp = Adafruit_DHT.read_retry(Adafruit_DHT.DHT22, 4)
            if hum is None or temp is None:
                print("[SENSOR] Error DHT22, usando defaults")
                temp, hum = 25.0, 55.0
            import board, busio
            import adafruit_ads1x15.ads1115 as ADS
            from adafruit_ads1x15.analog_in import AnalogIn
            i2c = busio.I2C(board.SCL, board.SDA)
            ads = ADS.ADS1115(i2c)
            soil1 = int((AnalogIn(ads, ADS.P0).value >> 4) * 1023 / 4095)
            soil2 = int((AnalogIn(ads, ADS.P1).value >> 4) * 1023 / 4095)
            luz   = int((AnalogIn(ads, ADS.P2).value >> 4) * 1023 / 4095)
            gas   = int((AnalogIn(ads, ADS.P3).value >> 4) * 1023 / 4095)
        else:
            t = time.time()
            temp = 27.0 + (t % 10) * 0.5
            hum  = 55.0 + (t % 5) * 1.0
            soil1 = 400 + int(t) % 200
            soil2 = 420 + int(t) % 180
            luz   = 500 + int(t) % 300
            gas   = 200 + int(t) % 100
        return f"{int(round(temp))},{int(round(hum))},{soil1},{soil2},{luz},{gas},0"
    except ImportError as e:
        print(f"[SENSOR] Libreria no disponible: {e}")
        return None
    except Exception as e:
        print(f"[SENSOR] Error: {e}")
        return None


# ---------------------------------------------------------------------------
# Comunicacion ARM64
# ---------------------------------------------------------------------------

def iniciar_motor() -> Optional[subprocess.Popen]:
    if not os.path.exists(ARM64_PROGRAM):
        print(f"[ARM64] ERROR: No se encuentra {ARM64_PROGRAM}")
        print("[ARM64] Compila con: make -C ..")
        sys.exit(1)
    proc = subprocess.Popen(
        [ARM64_PROGRAM],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    print(f"[ARM64] PID {proc.pid}")
    return proc


def enviar_lectura(proc: subprocess.Popen, lectura: str) -> bool:
    if proc.stdin is None or proc.stdin.closed:
        return False
    try:
        proc.stdin.write(f"{lectura}\n")
        proc.stdin.flush()
        return True
    except (BrokenPipeError, OSError):
        return False


def leer_respuesta(proc: subprocess.Popen) -> dict:
    campos = {}
    for _ in range(7):
        if proc.stdout is None or proc.stdout.closed:
            break
        linea = proc.stdout.readline()
        if not linea:
            break
        linea = linea.strip()
        if not linea:
            continue
        if "=" in linea:
            k, _, v = linea.partition("=")
            campos[k.strip()] = v.strip()
    return campos


def validar_respuesta(campos: dict) -> Optional[dict]:
    if campos.get("STATUS") == "ERROR":
        print(f"  [ARM64] ERROR: {campos.get('ERROR','?')} — {campos.get('DETAIL','?')}")
        return None
    if "ACTION" not in campos:
        print("  [ARM64] Respuesta sin ACTION")
        return None
    return {
        "action": campos.get("ACTION", "?"),
        "target": campos.get("TARGET", "?"),
        "risk": campos.get("RISK", "?"),
        "reason": campos.get("REASON", ""),
        "value": campos.get("VALUE", "0"),
        "indicator": campos.get("INDICATOR", "0"),
        "status": campos.get("STATUS", "OK"),
    }


# ---------------------------------------------------------------------------
# MongoDB via API REST
# ---------------------------------------------------------------------------

def registrar_en_mongodb(decision: dict, lectura: str, api_url: str):
    payload = {
        "module": "LIVE_ENGINE",
        "total_values": 7,
        "results": {
            "action": decision["action"],
            "target": decision["target"],
            "risk": decision["risk"],
            "reason": decision["reason"],
            "value": decision["value"],
            "indicator": decision["indicator"],
            "input": lectura,
        },
        "source": "raspi-01",
    }
    try:
        resp = requests.post(f"{api_url}/api/arm64-results", json=payload, timeout=5)
        if resp.status_code in (200, 201):
            print(f"     [MongoDB] OK id={resp.json().get('inserted_id','?')}")
        else:
            print(f"     [MongoDB] HTTP {resp.status_code}")
    except requests.ConnectionError:
        print(f"     [MongoDB] API no disponible ({api_url})")
    except Exception as e:
        print(f"     [MongoDB] {e}")


# ---------------------------------------------------------------------------
# Señales
# ---------------------------------------------------------------------------

_motor_proc: Optional[subprocess.Popen] = None


def _signal_handler(signum, frame):
    print(f"\n[Señal {signum}] Cerrando...")
    if _motor_proc and _motor_proc.poll() is None:
        try:
            _motor_proc.stdin.close()
        except Exception:
            pass
        try:
            _motor_proc.terminate()
            _motor_proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            _motor_proc.kill()
    gpio_cleanup()
    sys.exit(0)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(
        description="Orquestador del Invernadero Inteligente (seccion 4.20)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Ejemplos:
  %(prog)s                            # modo test
  %(prog)s --mode realtime            # GPIO real
  %(prog)s --mode file --file datos.csv
  %(prog)s --interval 5 --api-url https://ejemplo.com
  %(prog)s --once --no-mongo""")
    p.add_argument("--mode", choices=["test", "realtime", "file"], default="test",
                   help="modo de operacion (default: test)")
    p.add_argument("--interval", type=float, default=INTERVALO_DEFAULT,
                   help=f"segundos entre lecturas (default: {INTERVALO_DEFAULT})")
    p.add_argument("--api-url", default=API_BASE_DEFAULT,
                   help=f"URL base API REST (default: {API_BASE_DEFAULT})")
    p.add_argument("--file", help="archivo CSV para --mode file")
    p.add_argument("--no-gpio", action="store_true", help="deshabilitar GPIO")
    p.add_argument("--no-mongo", action="store_true", help="no registrar en MongoDB")
    p.add_argument("--once", action="store_true", help="una sola iteracion")
    return p.parse_args()


# ---------------------------------------------------------------------------
# Datos de prueba (13 casos cubriendo las 9 acciones)
# ---------------------------------------------------------------------------

LECTURAS_PRUEBA = [
    "25,55,40,50,400,120,0",   # LED_GREEN
    "28,60,42,48,600,140,0",   # LED_GREEN
    "32,58,41,52,350,110,0",   # LED_GREEN
    "35,63,39,47,700,160,0",   # LED_GREEN
    "30,61,45,53,300,100,0",   # LED_GREEN
    "20,50,250,280,150,90,0",  # LIGHT_ON
    "18,65,200,250,100,80,0",  # RIEGO_1_ON
    "22,55,400,180,120,70,0",  # RIEGO_2_ON
    "33,58,500,500,600,95,0",  # FAN_ON
    "29,60,450,480,800,350,0", # ALARM_ON
    "27,62,420,450,700,310,0", # ALARM_ON
    "28,60,42,48,600,140,1",   # NO_ACTION (manual)
    "25,55,40,50,400,120,0",   # LED_GREEN
]


def _mostrar_decision(decision: dict):
    info = ACCIONES.get(decision["action"], {})
    print(f"  -> {decision['action']} | {info.get('desc', '')}")
    print(f"     TARGET={decision['target']}  RISK={decision['risk']}")
    print(f"     REASON={decision['reason']}")
    print(f"     VALUE={decision['value']}  INDICATOR={decision['indicator']}")


def _procesar_lectura(lectura: str, proc: subprocess.Popen, args) -> bool:
    if not enviar_lectura(proc, lectura):
        print("[ERROR] Motor ARM64 cerrado")
        return False
    campos = leer_respuesta(proc)
    decision = validar_respuesta(campos)
    if not decision:
        print("  -> Omitiendo")
        return True
    _mostrar_decision(decision)
    ejecutar_accion_en_gpio(decision["action"])
    if not args.no_mongo:
        registrar_en_mongodb(decision, lectura, args.api_url)
    print()
    return True


def _ciclo_test(args, proc: subprocess.Popen):
    print(f"[TEST] {len(LECTURAS_PRUEBA)} lecturas, intervalo {args.interval}s\n")
    for i, lectura in enumerate(LECTURAS_PRUEBA, 1):
        print(f"[{i}/{len(LECTURAS_PRUEBA)}] {lectura}")
        if not _procesar_lectura(lectura, proc, args):
            break
        time.sleep(args.interval)
    print("[TEST] Completado")


def _ciclo_realtime(args, proc: subprocess.Popen):
    print(f"[REALTIME] Ctrl+C para detener, intervalo {args.interval}s\n")
    while True:
        lectura = leer_sensores_realtime()
        if not lectura:
            time.sleep(args.interval)
            continue
        print(f"[Sensor] {lectura}")
        if not _procesar_lectura(lectura, proc, args):
            proc = iniciar_motor()
            if not proc:
                break
            continue
        time.sleep(args.interval)


def _ciclo_file(args, proc: subprocess.Popen):
    ruta = args.file
    if not ruta:
        print("[ERROR] Usa --file <ruta> con --mode file")
        return
    if not os.path.exists(ruta):
        print(f"[ERROR] Archivo no encontrado: {ruta}")
        return
    with open(ruta) as f:
        lineas_raw = [line.strip() for line in f if line.strip()]
    lineas = []
    for line in lineas_raw:
        if line.startswith("#") or "ID" in line.upper().split(",")[0]:
            continue
        partes = [p.strip() for p in line.split(",")]
        if len(partes) < 7:
            continue
        try:
            idx_t = 1 if len(partes) >= 8 else 0
            csv_line = ",".join([
                str(int(float(partes[idx_t]))),
                str(int(float(partes[idx_t+1]))),
                str(int(float(partes[idx_t+2]))),
                str(int(float(partes[idx_t+3]))),
                str(int(float(partes[idx_t+4]))),
                str(int(float(partes[idx_t+5]))),
                "0"
            ])
            lineas.append(csv_line)
        except (ValueError, IndexError):
            continue
    if not lineas:
        print("[FILE] No se encontraron lineas validas")
        return
    print(f"[FILE] {len(lineas)} lecturas desde {ruta}\n")
    for i, linea in enumerate(lineas, 1):
        print(f"[{i}/{len(lineas)}] {linea}")
        if not _procesar_lectura(linea, proc, args):
            break
        time.sleep(args.interval)
    print("[FILE] Completado")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    global _motor_proc, GPIO_AVAILABLE

    args = parse_args()

    if args.no_gpio:
        GPIO_AVAILABLE = False

    gpio_setup()
    signal.signal(signal.SIGINT, _signal_handler)
    signal.signal(signal.SIGTERM, _signal_handler)

    _motor_proc = iniciar_motor()
    if not _motor_proc:
        gpio_cleanup()
        sys.exit(1)

    print(f"API:   {args.api_url}")
    print(f"GPIO:  {'REAL' if GPIO_AVAILABLE else 'SIMULADO'}")
    print(f"MONGO: {'ACTIVO' if not args.no_mongo else 'DESACTIVADO'}")
    print()

    try:
        if args.mode == "test":
            _ciclo_test(args, _motor_proc)
        elif args.mode == "realtime":
            _ciclo_realtime(args, _motor_proc)
        elif args.mode == "file":
            _ciclo_file(args, _motor_proc)

        if not args.once:
            try:
                r = input(">> Repetir? (s/n): ").strip().lower()
                if r == "s":
                    main()
            except (EOFError, KeyboardInterrupt):
                pass
    except KeyboardInterrupt:
        print("\n[Ctrl+C]")
    finally:
        print("[Orquestador] Cerrando motor...")
        if _motor_proc and _motor_proc.poll() is None:
            try:
                _motor_proc.stdin.close()
            except Exception:
                pass
            try:
                _motor_proc.terminate()
                _motor_proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                _motor_proc.kill()
        gpio_cleanup()
        print("[Orquestador] Terminado")


if __name__ == "__main__":
    main()
