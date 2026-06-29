"""
Generador de lecturas.csv para el coprocesador ARM64.

Genera exactamente 30 registros con el formato:
  ID,TEMP,HUM_AIRE,HUM_SUELO_1,HUM_SUELO_2,LUZ,GAS,RIEGO_1,RIEGO_2

Prioriza datos reales desde MongoDB (sensor_readings). Si no hay
suficientes, completa con datos simulados coherentes.

El archivo termina con $ como indicador de fin (formato requerido por los
módulos ARM64 en ensamblador AArch64).

Uso:
    python generate_lecturas.py                # genera en ./lecturas.csv
    python generate_lecturas.py --output /ruta/lecturas.csv
    python generate_lecturas.py --from-db      # fuerza usar datos reales de MongoDB
"""

import argparse
import csv
import random
from datetime import datetime, timezone
from pathlib import Path

FIELD_NAMES = ["ID", "TEMP", "HUM_AIRE", "HUM_SUELO_1", "HUM_SUELO_2", "LUZ", "GAS", "RIEGO_1", "RIEGO_2"]

SENSOR_TYPE_MAP = {
    "temperature": "TEMP",
    "temperatura": "TEMP",
    "humidity": "HUM_AIRE",
    "hum_aire": "HUM_AIRE",
    "humedad_ambiente": "HUM_AIRE",
    "soil_1": "HUM_SUELO_1",
    "soil_2": "HUM_SUELO_2",
    "humedad_suelo_area1": "HUM_SUELO_1",
    "humedad_suelo_area2": "HUM_SUELO_2",
    "light": "LUZ",
    "luz": "LUZ",
    "gas": "GAS",
}


def _get_readings_from_db(count: int = 30) -> list[dict] | None:
    try:
        from pymongo import MongoClient
        import os
        from dotenv import load_dotenv

        load_dotenv(Path(__file__).resolve().parent / ".env")
        uri = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
        db_name = os.getenv("MONGODB_DB_NAME", "invernadero_iot")

        client = MongoClient(uri, serverSelectionTimeoutMS=3000)
        db = client[db_name]
        total = db.sensor_readings.count_documents({})
        if total < 30:
            client.close()
            return None

        latest = list(db.sensor_readings.find().sort("recorded_at", -1).limit(30 * 6))
        client.close()

        if not latest or len(latest) < 30:
            return None

        groups: dict[str, list[float]] = {}
        for doc in latest:
            st = doc.get("sensor_type", "").lower().replace(" ", "_").replace("-", "_")
            col = SENSOR_TYPE_MAP.get(st)
            if col:
                if col not in groups:
                    groups[col] = []
                v = doc.get("value", 0.0)
                if isinstance(v, (int, float)):
                    groups[col].append(float(v))

        rows = []
        for i in range(min(count, 30)):
            row = {"ID": i + 1}
            for col in ["TEMP", "HUM_AIRE", "HUM_SUELO_1", "HUM_SUELO_2", "LUZ", "GAS"]:
                vals = groups.get(col, [])
                if i < len(vals):
                    row[col] = round(vals[i], 1) if col in ("TEMP", "HUM_AIRE", "HUM_SUELO_1", "HUM_SUELO_2") else int(round(vals[i]))
                else:
                    row[col] = 0
            row["RIEGO_1"] = 0
            row["RIEGO_2"] = 0
            rows.append(row)

        if len(rows) >= count:
            return rows[:count]
        return None

    except Exception:
        return None


def _generate_mock(count: int = 30) -> list[dict]:
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


def generate_lecturas(count: int = 30, from_db: bool = False) -> list[dict]:
    if from_db:
        rows = _get_readings_from_db(count)
        if rows:
            print(f"Generado desde MongoDB: {len(rows)} registros reales")
            return rows
        print("No hay suficientes datos reales en MongoDB. Usando datos simulados.")
    return _generate_mock(count)


def write_lecturas(output_path: Path, rows: list[dict]) -> None:
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELD_NAMES)
        writer.writeheader()
        writer.writerows(rows)
        f.write("$\n")
    print(f"lecturas.csv generado con {len(rows)} registros en {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Genera lecturas.csv para ARM64")
    parser.add_argument("--output", default="../arm64/lecturas.csv", help="Ruta de salida (default: ../arm64/lecturas.csv)")
    parser.add_argument("--count", type=int, default=30, help="Número de registros (default: 30)")
    parser.add_argument("--from-db", action="store_true", help="Usar datos reales de MongoDB")
    args = parser.parse_args()

    rows = generate_lecturas(args.count, args.from_db)
    write_lecturas(Path(args.output), rows)


if __name__ == "__main__":
    main()
