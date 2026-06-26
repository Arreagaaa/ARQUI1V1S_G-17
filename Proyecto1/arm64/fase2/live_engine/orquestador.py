import subprocess
import time

AMR64_PROGRAM = "/home/crjav/ARQUI1/Project/ARQUI1V1S_G-17/Proyecto1/arm64/build/live_engine"
INTERVALO = 2

LECTURAS = [
    "25,55,40,50,400,120,0",
    "28,60,42,48,600,140,0",
    "32,58,41,52,350,110,0",
    "35,63,39,47,700,160,0",
    "30,61,45,53,300,100,0",
]

def aplica_accion(accion):
    accion = accion.strip()
    if accion == "ACTION=FAN_ON":
        print("Ventilador encendido")
    elif accion == "ACTION=NO_ACTION":
        print("Sin accion")
    else:
        print(f"Accion desconocida: {accion}")

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

    try:
        for lectura in LECTURAS:
            print(f"\nLectura: {lectura}")

            proceso.stdin.write(f"{lectura}\n")
            proceso.stdin.flush()

            respuesta = proceso.stdout.readline().strip()

            print(f"Respuesta ARM64: {respuesta}")

            aplica_accion(respuesta)

            time.sleep(INTERVALO)

    finally:
        print("Cerrando proceso...")
        proceso.stdin.close()
        proceso.wait()

if __name__ == "__main__":
    main()
