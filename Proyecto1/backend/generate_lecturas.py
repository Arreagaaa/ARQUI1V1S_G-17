"""
Generador de lecturas.csv para el coprocesador ARM64.

Genera exactamente 30 registros con el formato:
  ID,TEMP,HUM_AIRE,HUM_SUELO_1,HUM_SUELO_2,LUZ,GAS,RIEGO_1,RIEGO_2

El archivo termina con $ como indicador de fin (formato requerido por los
módulos ARM64 en ensamblador AArch64).

Uso:
    python generate_lecturas.py                # genera en ./lecturas.csv
    python generate_lecturas.py --output /ruta/lecturas.csv
"""

import argparse
import csv
import random
from pathlib import Path


def generate_lecturas(count: int = 30) -> list[dict]:
    rng = random.Random(42)
    rows = []
    for i in range(1, count + 1):
        rows.append({
            "ID": i,
            "TEMP": round(rng.uniform(22.0, 38.0), 1),
            "HUM_AIRE": round(rng.uniform(40.0, 90.0), 1),
            "HUM_SUELO_1": round(rng.uniform(0.0, 100.0), 1),
            "HUM_SUELO_2": round(rng.uniform(0.0, 100.0), 1),
            "LUZ": rng.randint(0, 1023),
            "GAS": rng.randint(0, 1023),
            "RIEGO_1": rng.randint(0, 1),
            "RIEGO_2": rng.randint(0, 1),
        })
    return rows


def write_lecturas(output_path: Path, rows: list[dict]) -> None:
    fieldnames = ["ID", "TEMP", "HUM_AIRE", "HUM_SUELO_1", "HUM_SUELO_2", "LUZ", "GAS", "RIEGO_1", "RIEGO_2"]
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
        f.write("$\n")
    print(f"lecturas.csv generado con {len(rows)} registros en {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Genera lecturas.csv para ARM64")
    parser.add_argument("--output", default="lecturas.csv", help="Ruta de salida (default: lecturas.csv)")
    parser.add_argument("--count", type=int, default=30, help="Número de registros (default: 30)")
    args = parser.parse_args()

    rows = generate_lecturas(args.count)
    write_lecturas(Path(args.output), rows)


if __name__ == "__main__":
    main()
