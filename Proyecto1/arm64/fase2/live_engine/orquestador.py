import subprocess
import time
import requests
from typing import Optional

AMR64_PROGRAM = "/home/crjav/ARQUI1/Project/ARQUI1V1S_G-17/Proyecto1/arm64/fase2/build/live_engine"
API_BASE = "http://localhost:8000"
INTERVALO = 2

# lecturas de prueba
LECTURAS = [
    "25,55,40,50,400,120,0",
    "28,60,42,48,600,140,0",
    "32,58,41,52,350,110,0",
    "35,63,39,47,700,160,0",
    "30,61,45,53,300,100,0",
]

# acciones validas mapeadas a descripcion y GPIO
ACCIONES = {
    "ALARM_ON":    {"desc": "Alarma activada por gas critico", "gpio": None},
    "RIEGO_1_ON":  {"desc": "Riego del area 1 activado",      "gpio": None},
    "RIEGO_2_ON":  {"desc": "Riego del area 2 activado",      "gpio": None},
    "FAN_ON":      {"desc": "Ventilador encendido",           "gpio": None},
    "LIGHT_ON":    {"desc": "Iluminacion artificial encendida","gpio": None},
    "LED_GREEN":   {"desc": "Estado normal",                  "gpio": None},
    "LED_YELLOW":  {"desc": "Estado de advertencia",          "gpio": None},
    "LED_RED":     {"desc": "Estado de riesgo alto",          "gpio": None},
    "NO_ACTION":   {"desc": "Sin accion fisica requerida",    "gpio": None},
}

def leer_respuesta(proceso: subprocess.Popen) -> dict:
    """Lee las 7 lineas de la respuesta estructurada de ARM64 y devuelve un dict."""
    campos = {}
    for _ in range(7):
        linea = proceso.stdout.readline()
        if not linea:
            break
        linea = linea.strip()

        # saltar lineas vacias
        if not linea:
            continue

        if "=" in linea:
            key, _, val = linea.partition("=")
            campos[key.strip()] = val.strip()

    return campos

def parsear_respuesta(campos: dict) -> Optional[dict]:
    """Valida la respuesta y devuelve un dict limpio o None si hay error."""
    # si es un error estructurado
    if campos.get("STATUS") == "ERROR":
        error = campos.get("ERROR", "UNKNOWN")
        detalle = campos.get("DETAIL", "Sin detalle")
        print(f"[ERROR] ARM64: {error} - {detalle}")
        return None

    if "ACTION" not in campos:
        print("[ERROR] Respuesta sin ACTION")
        return None

    return {
        "action": campos.get("ACTION", "UNKNOWN"),
        "target": campos.get("TARGET", "NONE"),
        "risk": campos.get("RISK", "LOW"),
        "reason": campos.get("REASON", ""),
        "value": campos.get("VALUE", "0"),
        "indicator": campos.get("INDICATOR", "0"),
        "status": campos.get("STATUS", "ERROR"),
    }

def ejecutar_accion(decision: dict):
    """Ejecuta la accion en GPIO (stub) e imprime el resultado."""
    accion = decision["action"]
    info = ACCIONES.get(accion, {"desc": f"Accion desconocida: {accion}", "gpio": None})

    print(f"  -> {accion} | {info['desc']}")
    print(f"     TARGET={decision['target']}  RISK={decision['risk']}")
    print(f"     REASON={decision['reason']}")
    print(f"     VALUE={decision['value']}  INDICATOR={decision['indicator']}")

    # TODO: implementar control GPIO real
    if info["gpio"] is not None:
        # gpio.write(info["gpio"], True)
        pass

def registrar_en_mongodb(decision: dict, lectura: str):
    """Registra la decision ARM64 en MongoDB via API REST."""
    try:
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
            "source": "live_engine",
        }
        resp = requests.post(f"{API_BASE}/api/arm64-results", json=payload, timeout=5)
        if resp.status_code in (200, 201):
            print(f"     [MongoDB] Registrado: {resp.json().get('inserted_id', 'ok')}")
        else:
            print(f"     [MongoDB] Error {resp.status_code}: {resp.text}")
    except requests.ConnectionError:
        print("     [MongoDB] API no disponible, omitiendo registro")
    except Exception as e:
        print(f"     [MongoDB] Error inesperado: {e}")

def main():
    proceso = subprocess.Popen(
        [AMR64_PROGRAM],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1
    )

    if proceso.stdin is None:
        raise RuntimeError("No se pudo abrir stdin del proceso")

    if proceso.stdout is None:
        raise RuntimeError("No se pudo abrir stdout del proceso")

    print("=== ORQUESTADOR: INVERNADERO INTELIGENTE FASE 2 ===")
    print(f"Motor ARM64: {AMR64_PROGRAM}")
    print(f"API: {API_BASE}")
    print()

    try:
        for lectura in LECTURAS:
            print(f"\n[Lectura] {lectura}")

            # enviar lectura al motor ARM64
            proceso.stdin.write(f"{lectura}\n")
            proceso.stdin.flush()

            # leer respuesta estructurada completa
            campos = leer_respuesta(proceso)

            # validar y ejecutar
            decision = parsear_respuesta(campos)

            if decision is None:
                print("  -> Omitiendo accion por error ARM64")
                continue

            ejecutar_accion(decision)

            # TODO: descomentar cuando el backend este disponible
            # registrar_en_mongodb(decision, lectura)

            time.sleep(INTERVALO)

    finally:
        print("\nCerrando proceso ARM64...")
        proceso.stdin.close()
        proceso.wait()
        print("Listo.")

if __name__ == "__main__":
    main()
