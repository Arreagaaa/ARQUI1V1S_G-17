"""
ARM64 Executor — Invernadero Inteligente IoT (ACYE1, Grupo 17)

Ejecuta los 5 módulos ARM64 del coprocesador, parsea sus archivos de salida
y envía los resultados al backend FastAPI para almacenamiento en MongoDB.

Modos de uso:
  Desarrollo (PC con QEMU):
    python arm_executor.py --dir ../arm64

  Raspberry Pi (ejecución nativa):
    python arm_executor.py --pi --dir ../arm64

  Obtener datos desde el backend (CSV + columna config) y ejecutar:
    python arm_executor.py --fetch --url http://<backend>:8000 --pi --dir ../arm64

  Solo parsear (si los módulos ya se ejecutaron con make run1..run5):
    python arm_executor.py --parse-only --dir ../arm64

  Especificar URL del backend:
    python arm_executor.py --url http://localhost:8000
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Any

import requests


MODULES = {
    "WEIGHTED_MEAN": {
        "file": "resultado_media.txt",
        "binary": "modulo_1_media",
    },
    "VARIANCE": {
        "file": "resultado_varianza.txt",
        "binary": "modulo_2_varianza",
    },
    "ANOMALY_DETECTION": {
        "file": "resultado_anomalias.txt",
        "binary": "modulo_3_anomalias",
    },
    "PREDICTION": {
        "file": "resultado_prediccion.txt",
        "binary": "modulo_4_prediccion",
    },
    "ADVANCED_TREND": {
        "file": "resultado_tendencia.txt",
        "binary": "modulo_5_tendencia",
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="ARM64 Executor — ejecuta módulos ARM64 y envía resultados al backend"
    )
    parser.add_argument(
        "--dir",
        default="../arm64",
        help="Directorio base de ARM64 (default: ../arm64)",
    )
    parser.add_argument(
        "--url",
        default="http://localhost:8000",
        help="URL base del backend FastAPI (default: http://localhost:8000)",
    )
    parser.add_argument(
        "--pi",
        action="store_true",
        help="Modo Raspberry Pi: ejecuta binarios nativamente (sin QEMU)",
    )
    parser.add_argument(
        "--fetch",
        action="store_true",
        help="Descargar lecturas.csv y column_config.txt desde el backend",
    )
    parser.add_argument(
        "--parse-only",
        action="store_true",
        help="Solo parsea archivos de salida (no ejecuta los binarios)",
    )
    for i in range(1, 6):
        parser.add_argument(
            f"--col{i}",
            type=int,
            default=None,
            help=f"Columna para módulo {i} (0-based, default: 1 para M1-M3,M5, 4 para M4)",
        )
    return parser.parse_args()


def run_module(binary_path: Path, use_qemu: bool) -> bool:
    if not binary_path.exists():
        return False

    # El binario espera lecturas.csv en el CWD (directorio arm64/)
    arm64_dir = binary_path.parent.parent
    if not arm64_dir.exists():
        arm64_dir = Path.cwd()

    cmd = ["qemu-aarch64", str(binary_path)] if use_qemu else [str(binary_path)]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, cwd=str(arm64_dir))
        if result.returncode != 0:
            print(f"  {binary_path.name}: exit code {result.returncode}")
            return False
        return True
    except FileNotFoundError:
        print(f"  {binary_path.name}: binario no encontrado")
        return False
    except subprocess.TimeoutExpired:
        print(f"  {binary_path.name}: timeout")
        return False


def parse_output_file(file_path: Path) -> dict[str, Any] | None:
    if not file_path.exists():
        return None

    try:
        text = file_path.read_text().strip()
    except IOError:
        return None

    result = {}
    for line in text.splitlines():
        line = line.strip()
        if "=" in line:
            key, value = line.split("=", 1)
            result[key] = value

    return result


def post_to_backend(url: str, module: str, data: dict[str, Any]) -> bool:
    total_values = int(data.get("TOTAL_VALUES", 0))
    results = {
        k: _coerce(v) for k, v in data.items()
        if k not in ("MODULE", "TOTAL_VALUES")
    }

    payload = {
        "module": module,
        "total_values": total_values,
        "results": results,
        "column": data.get("COLUMN"),
        "range_start": _coerce(data.get("WINDOW_START", "0")) if data.get("WINDOW_START") else None,
        "range_end": _coerce(data.get("WINDOW_END", "0")) if data.get("WINDOW_END") else None,
        "status": data.get("STATUS", "OK"),
        "error_detail": data.get("ERROR") if data.get("STATUS") == "ERROR" else None,
        "source": "raspi-01",
    }

    endpoint = f"{url.rstrip('/')}/api/arm64-results"
    try:
        resp = requests.post(endpoint, json=payload, timeout=10)
        if resp.status_code == 200:
            print(f"  {module}: enviado al backend")
            return True
        else:
            print(f"  {module}: backend respondió {resp.status_code}: {resp.text[:120]}")
            return False
    except requests.RequestException as exc:
        print(f"  {module}: error de conexión: {exc}")
        return False


def _coerce(v: str) -> Any:
    v = v.strip()
    try:
        return int(v)
    except ValueError:
        pass
    try:
        return float(v)
    except ValueError:
        pass
    return v


def fetch_from_backend(url: str, arm_dir: Path) -> bool:
    """Descarga lecturas.csv y column_config.txt desde el backend."""
    base = url.rstrip("/")

    # Descargar CSV
    csv_path = arm_dir / "lecturas.csv"
    try:
        resp = requests.get(f"{base}/api/arm64/csv", timeout=30)
        if resp.status_code == 200:
            csv_path.write_text(resp.text, encoding="utf-8")
            total = resp.headers.get("X-Total-Records", "?")
            source = resp.headers.get("X-Source", "?")
            print(f"  CSV descargado: {csv_path} ({total} registros, fuente: {source})")
        else:
            print(f"  Error descargando CSV: HTTP {resp.status_code}")
            return False
    except requests.RequestException as exc:
        print(f"  Error de conexión al descargar CSV: {exc}")
        return False

    # Descargar column_config
    config_path = arm_dir / "column_config.txt"
    try:
        resp = requests.get(f"{base}/api/arm64/column-config", timeout=15)
        if resp.status_code == 200:
            data = resp.json()
            columns = data.get("columns", {})
            lines = [f"{k}:{v}" for k, v in sorted(columns.items())]
            config_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            print(f"  Config descargada: {config_path} ({len(lines)} módulos)")
        else:
            print(f"  Error descargando config: HTTP {resp.status_code}")
            return False
    except requests.RequestException as exc:
        print(f"  Error de conexión al descargar config: {exc}")
        return False

    return True


def main() -> int:
    args = parse_args()
    arm_dir = Path(args.dir).resolve()
    build_dir = arm_dir / "build"
    results_dir = arm_dir / "results"
    use_qemu = not args.pi

    if not arm_dir.exists():
        print(f"Directorio ARM64 no encontrado: {arm_dir}")
        return 1

    results_dir.mkdir(parents=True, exist_ok=True)

    print(f"ARM64 Executor — Grupo 17")
    print(f"  Directorio: {arm_dir}")
    print(f"  Backend:    {args.url}")
    print(f"  Modo:       {'QEMU' if use_qemu else 'Nativo'}{' (solo parseo)' if args.parse_only else ''}")

    # Fase 0: fetch desde backend
    if args.fetch:
        print("Descargando datos desde el backend...")
        if not fetch_from_backend(args.url, arm_dir):
            print("Error al descargar datos. Abortando.")
            return 1
        print()

    columns = {}
    for i in range(1, 6):
        col = getattr(args, f"col{i}")
        if col is not None:
            columns[i] = col
            col_name = {0: "ID", 1: "TEMP", 2: "HUM_AIRE", 3: "HUM_SUELO_1", 4: "HUM_SUELO_2", 5: "LUZ", 6: "GAS"}.get(col, f"col{col}")
            print(f"  Módulo {i}: columna {col} ({col_name})")
        else:
            default_col = 4 if i == 4 else 1
            col_name = {0: "ID", 1: "TEMP", 2: "HUM_AIRE", 3: "HUM_SUELO_1", 4: "HUM_SUELO_2", 5: "LUZ", 6: "GAS"}.get(default_col, f"col{default_col}")
            print(f"  Módulo {i}: columna por defecto {default_col} ({col_name})")
    print()

    # Escribir column_config.txt para los módulos ARM64 (si no se fetch)
    if not args.fetch:
        config_path = arm_dir / "column_config.txt"
        try:
            config_lines = []
            for i in range(1, 6):
                col = columns.get(i, 4 if i == 4 else 1)
                config_lines.append(f"{i}:{col}")
            config_path.write_text("\n".join(config_lines) + "\n")
            print(f"Configuración de columnas escrita en {config_path}")
        except IOError as exc:
            print(f"Error escribiendo config: {exc}")
        print()

    # Fase 1: ejecutar módulos
    if not args.parse_only:
        print("Ejecutando módulos ARM64...")
        for module_name, info in MODULES.items():
            binary_path = build_dir / info["binary"]
            if run_module(binary_path, use_qemu):
                print(f"  {info['binary']}: OK")
            else:
                print(f"  {info['binary']}: no ejecutado")
        print()

    # Fase 2: parsear resultados
    print("Parseando resultados...")
    parsed = []
    for module_name, info in MODULES.items():
        file_path = results_dir / info["file"]
        data = parse_output_file(file_path)
        if data:
            module = data.get("MODULE", module_name)
            print(f"  {module}: {len(data)} campos")
            parsed.append((module_name, data))
        else:
            print(f"  {module_name}: sin archivo de salida")
    print()

    if not parsed:
        print("No hay resultados para enviar")
        return 1

    # Fase 3: enviar al backend
    print("Enviando al backend...")
    success = 0
    for module_name, data in parsed:
        if post_to_backend(args.url, module_name, data):
            success += 1
    print()

    if success == len(parsed):
        print(f"Todos los módulos enviados correctamente ({success}/{len(parsed)})")
        return 0

    print(f"{success}/{len(parsed)} módulos enviados correctamente")
    return 1


if __name__ == "__main__":
    sys.exit(main())
