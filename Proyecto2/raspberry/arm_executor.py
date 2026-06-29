"""
ARM64 Executor — Invernadero Inteligente IoT (ACYE1, Grupo 17)

Ejecuta los 10 módulos ARM64 (5 Fase 1 + 5 Fase 2) del coprocesador,
captura su salida y envía los resultados al backend FastAPI para
almacenamiento en MongoDB.

Modos de uso:
  Desarrollo (PC con QEMU):
    python arm_executor.py --dir ../arm64/fase2 --fase1-dir ../arm64/fase1

  Raspberry Pi (ejecución nativa):
    python arm_executor.py --pi --dir ../arm64/fase2 --fase1-dir ../arm64/fase1

  Obtener datos desde el backend (CSV + columna config) y ejecutar:
    python arm_executor.py --fetch --url http://<backend>:8000 --pi --dir ../arm64/fase2 --fase1-dir ../arm64/fase1

  Solo parsear (si los módulos ya se ejecutaron):
    python arm_executor.py --parse-only --dir ../arm64/fase2 --fase1-dir ../arm64/fase1
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Any

import requests


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


def _parse_kv_lines(text: str) -> dict[str, str]:
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if "=" in line:
            k, _, v = line.partition("=")
            result[k.strip()] = v.strip()
    return result


MODULES = {
    "RMSE": {
        "binary": "rmse",
        "output": "stdout",
        "needs_ideal": True,
        "description": "Root Mean Square Error",
    },
    "LINEAR_REGRESSION": {
        "binary": "varianza",
        "output": "stdout",
        "needs_ideal": False,
        "description": "Regresion lineal (pendiente + tendencia)",
    },
    "PREDICTION_LINEAR": {
        "binary": "prediccion",
        "output": "stdout",
        "needs_ideal": False,
        "description": "Prediccion lineal K-pasos adelante",
    },
    "ERROR_INTEGRAL": {
        "binary": "integrals",
        "output": "file",
        "file": "resultado_integral.txt",
        "needs_ideal": True,
        "description": "Integral del error (regla del trapecio)",
    },
    "LOCAL_DERIVATIVE": {
        "binary": "derivada",
        "output": "stdout",
        "file": "resultado_derivada_local.txt",
        "needs_ideal": False,
        "description": "Derivada local (pendiente maxima ventana 5)",
    },
}

FASE1_MODULES = {
    "WEIGHTED_MEAN": {
        "binary": "modulo_1_media",
        "output": "file",
        "file": "resultado_media.txt",
        "needs_ideal": False,
        "description": "Media ponderada",
    },
    "VARIANCE": {
        "binary": "modulo_2_varianza",
        "output": "file",
        "file": "resultado_varianza.txt",
        "needs_ideal": False,
        "description": "Varianza y desviacion estandar",
    },
    "ANOMALY_DETECTION": {
        "binary": "modulo_3_anomalias",
        "output": "file",
        "file": "resultado_anomalias.txt",
        "needs_ideal": False,
        "description": "Deteccion de anomalias",
    },
    "PREDICTION": {
        "binary": "modulo_4_prediccion",
        "output": "file",
        "file": "resultado_prediccion.txt",
        "needs_ideal": False,
        "description": "Prediccion lineal simple",
    },
    "ADVANCED_TREND": {
        "binary": "modulo_5_tendencia",
        "output": "file",
        "file": "resultado_tendencia.txt",
        "needs_ideal": False,
        "description": "Tendencia avanzada",
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="ARM64 Executor — ejecuta modulos ARM64 Fase 1+2 y envia resultados al backend"
    )
    parser.add_argument(
        "--dir",
        default="../arm64/fase2",
        help="Directorio base de ARM64 Fase 2 (default: ../arm64/fase2)",
    )
    parser.add_argument(
        "--fase1-dir",
        default=None,
        help="Directorio base de ARM64 Fase 1 (default: ../arm64/fase1 relativo a --dir)",
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
        help="Descargar lecturas.csv desde el backend",
    )
    parser.add_argument(
        "--parse-only",
        action="store_true",
        help="Solo parsea archivos de salida (no ejecuta los binarios)",
    )
    parser.add_argument("--start", type=int, default=2, help="Linea de inicio (default: 2)")
    parser.add_argument("--end", type=int, default=30, help="Linea final (default: 30)")
    parser.add_argument("--ideal", type=int, default=55, help="Valor ideal para RMSE/INTEGRAL (default: 55)")
    parser.add_argument("--k", type=int, default=5, help="Pasos K para prediccion (default: 5)")
    for i in range(1, 6):
        parser.add_argument(
            f"--col{i}",
            type=int,
            default=None,
            help=f"Columna para modulo F2 {i} (1-6, default: 1)",
        )
    for i in range(1, 6):
        parser.add_argument(
            f"--col-f1-{i}",
            type=int,
            default=None,
            help=f"Columna para modulo F1 {i} (1-6, default: 1)",
        )
    return parser.parse_args()


def build_cmd(
    binary_path: Path, csv_path: Path, info: dict,
    start: int, end: int, column: int, ideal: int, k: int
) -> list[str]:
    binary = str(binary_path)
    if info["needs_ideal"]:
        return [binary, str(csv_path), str(start), str(end), str(column), str(ideal)]
    if info["binary"] == "prediccion":
        return [binary, str(csv_path), str(start), str(end), str(column), str(k)]
    return [binary, str(csv_path), str(start), str(end), str(column)]


def run_and_parse(
    binary_path: Path, csv_path: Path, info: dict,
    use_qemu: bool, fase2_dir: Path,
    start: int, end: int, column: int, ideal: int, k: int
) -> dict[str, Any] | None:
    if not binary_path.exists():
        print(f"  {binary_path.name}: binario no encontrado en {binary_path}")
        return None

    cmd = (
        ["qemu-aarch64", str(binary_path)] if use_qemu else [str(binary_path)]
    )
    cmd = build_cmd(binary_path, csv_path, info, start, end, column, ideal, k)

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=30, cwd=str(fase2_dir)
        )
    except FileNotFoundError:
        print(f"  {binary_path.name}: binario no encontrado")
        return None
    except subprocess.TimeoutExpired:
        print(f"  {binary_path.name}: timeout")
        return None

    if result.returncode != 0:
        print(f"  {binary_path.name}: exit code {result.returncode}")
        stderr = result.stderr.strip()
        if stderr:
            print(f"    stderr: {stderr[:200]}")
        return None

    # Parse segun modo de salida
    if info["output"] == "stdout":
        data = _parse_kv_lines(result.stdout)
        if not data:
            print(f"  {binary_path.name}: sin salida stdout")
            return None
        print(f"  {binary_path.name}: OK ({len(data)} campos)")
        return data

    # output == "file"
    file_path = fase2_dir / "results" / info["file"]
    if not file_path.exists():
        print(f"  {binary_path.name}: archivo no encontrado: {file_path}")
        return None

    text = file_path.read_text().strip()
    data = _parse_kv_lines(text)
    if not data:
        print(f"  {binary_path.name}: archivo vacio: {file_path}")
        return None
    print(f"  {binary_path.name}: OK ({len(data)} campos desde {info['file']})")
    return data


def post_to_backend(url: str, module: str, data: dict[str, Any]) -> bool:
    total_values = int(data.get("COUNT", data.get("TOTAL_VALUES", 0)))
    results = {k: _coerce(v) for k, v in data.items()}
    results["COUNT"] = total_values  # frontend lo busca en results.COUNT
    results["TOTAL_VALUES"] = total_values

    # Mapear campos del binario a lo que espera el frontend
    if module == "WEIGHTED_MEAN" and "MEAN" in results and "WEIGHTED_MEAN" not in results:
        results["WEIGHTED_MEAN"] = results["MEAN"]

    payload = {
        "module": module,
        "total_values": total_values,
        "results": results,
        "column": str(data.get("COLUMN", "")),
        "range_start": _coerce(data.get("WINDOW_START", "0")),
        "range_end": _coerce(data.get("WINDOW_END", "0")),
        "status": data.get("STATUS", "OK"),
        "source": "raspi-01",
    }

    endpoint = f"{url.rstrip('/')}/api/arm64-results"
    try:
        resp = requests.post(endpoint, json=payload, timeout=10)
        if resp.status_code in (200, 201):
            print(f"  {module}: enviado al backend")
            return True
        else:
            print(f"  {module}: backend respondio {resp.status_code}: {resp.text[:120]}")
            return False
    except requests.RequestException as exc:
        print(f"  {module}: error de conexion: {exc}")
        return False


def fetch_csv_from_backend(url: str, csv_path: Path) -> bool:
    base = url.rstrip("/")
    try:
        resp = requests.get(f"{base}/api/arm64/csv", timeout=30)
        if resp.status_code == 200:
            # Ensure parent dir is writable before writing
            csv_path.parent.mkdir(parents=True, exist_ok=True)
            if csv_path.exists():
                csv_path.chmod(0o644)
            csv_path.write_text(resp.text, encoding="utf-8")
            csv_path.chmod(0o644)
            total = resp.headers.get("X-Total-Records", "?")
            print(f"  CSV descargado: {csv_path} ({total} registros)")
            return True
        else:
            print(f"  Error descargando CSV: HTTP {resp.status_code}")
            return False
    except requests.RequestException as exc:
        print(f"  Error de conexion al descargar CSV: {exc}")
        return False


def fetch_column_config_from_backend(url: str) -> dict[int, int]:
    base = url.rstrip("/")
    try:
        resp = requests.get(f"{base}/api/arm64/column-config", timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            raw = data.get("columns", {})
            return {int(k): int(v) for k, v in raw.items()}
    except Exception:
        pass
    return {}


def main() -> int:
    args = parse_args()
    fase2_dir = Path(args.dir).resolve()
    build_dir = fase2_dir / "build"
    results_dir = fase2_dir / "results"
    use_qemu = not args.pi

    if not fase2_dir.exists():
        print(f"Directorio ARM64 Fase 2 no encontrado: {fase2_dir}")
        return 1

    results_dir.mkdir(parents=True, exist_ok=True)

    print(f"ARM64 Executor Fase 2 — Grupo 17")
    print(f"  Directorio: {fase2_dir}")
    print(f"  Backend:    {args.url}")
    print(f"  Modo:       {'QEMU' if use_qemu else 'Nativo'}{' (solo parseo)' if args.parse_only else ''}")
    print()

    csv_path = fase2_dir / "lecturas.csv"

    # Fase 0: fetch CSV + column config desde backend
    column_config: dict[int, int] = {}
    if args.fetch:
        print("Descargando datos desde el backend...")
        if not fetch_csv_from_backend(args.url, csv_path):
            print("Error al descargar CSV. Abortando.")
            return 1
        column_config = fetch_column_config_from_backend(args.url)
        print()
    elif args.url:
        column_config = fetch_column_config_from_backend(args.url)

    if not csv_path.exists():
        print(f"CSV no encontrado: {csv_path}")
        print("Usa --fetch para descargar o coloca lecturas.csv en el directorio")
        return 1

    # Mapear frontend module IDs (M6-M10) a arm_executor indices (col1-col5)
    # M6=RMSE, M7=LINEAR_REGRESSION, M8=PREDICTION_LINEAR, M9=ERROR_INTEGRAL, M10=LOCAL_DERIVATIVE
    FRONTEND_TO_EXECUTOR = {6: 1, 7: 2, 8: 3, 9: 4, 10: 5}
    cols = {}
    for i in range(1, 6):
        col = getattr(args, f"col{i}")
        if col is not None:
            cols[i] = col
        elif column_config:
            # buscar frontend module ID que mapea a este executor index i
            frontend_id = next((fid for fid, eidx in FRONTEND_TO_EXECUTOR.items() if eidx == i), None)
            if frontend_id and frontend_id in column_config:
                cols[i] = column_config[frontend_id]
            else:
                cols[i] = 1
        else:
            cols[i] = 1

    # --- Fase 2: column config ---
    print(f"  Start={args.start}, End={args.end}, Ideal={args.ideal}, K={args.k}")
    for i, (module_name, info) in enumerate(MODULES.items(), 1):
        print(f"  Modulo {i}: {module_name:20s} col={cols[i]} ({info['description']})")
    print()

    # --- Fase 1: directorio base ---
    if args.fase1_dir:
        fase1_dir = Path(args.fase1_dir).resolve()
    else:
        fase1_dir = fase2_dir.parent / "fase1"
    f1_build_dir = fase1_dir / "build"
    f1_results_dir = fase1_dir / "results"

    FRONTEND_TO_EXECUTOR_F1 = {2: 1, 3: 2, 4: 3, 5: 4, 6: 5}
    f1_cols = {}
    for i in range(1, 6):
        col = getattr(args, f"col_f1_{i}")
        if col is not None:
            f1_cols[i] = col
        elif column_config:
            frontend_id = next((fid for fid, eidx in FRONTEND_TO_EXECUTOR_F1.items() if eidx == i), None)
            if frontend_id and frontend_id in column_config:
                f1_cols[i] = column_config[frontend_id]
            else:
                f1_cols[i] = 1
        else:
            f1_cols[i] = 1

    if fase1_dir.exists():
        print(f"  Fase 1: {fase1_dir}")
        for i, (module_name, info) in enumerate(FASE1_MODULES.items(), 1):
            print(f"    M{i}: {module_name:20s} col={f1_cols[i]} ({info['description']})")
    print()

    # --- Ejecutar y parsear Fase 2 ---
    parsed = []
    for i, (module_name, info) in enumerate(MODULES.items(), 1):
        if args.parse_only and info["output"] == "stdout":
            print(f"  {module_name}: saltado (--parse-only, modulo requiere ejecucion)")
            continue

        binary_path = build_dir / info["binary"]

        if args.parse_only and info["output"] == "file":
            file_path = results_dir / info["file"]
            if file_path.exists():
                data = _parse_kv_lines(file_path.read_text().strip())
                if data:
                    parsed.append((module_name, data))
                    print(f"  {module_name}: {len(data)} campos (desde archivo)")
                else:
                    print(f"  {module_name}: archivo vacio")
            else:
                print(f"  {module_name}: archivo no encontrado")
            continue

        data = run_and_parse(
            binary_path, csv_path, info, use_qemu, fase2_dir,
            args.start, args.end, cols[i], args.ideal, args.k,
        )
        if data:
            parsed.append((module_name, data))
        else:
            print(f"  {module_name}: no ejecutado")

    # --- Ejecutar y parsear Fase 1 ---
    if fase1_dir.exists() and f1_build_dir.exists():
        print()
        for i, (module_name, info) in enumerate(FASE1_MODULES.items(), 1):
            binary_path = f1_build_dir / info["binary"]

            if not binary_path.exists():
                print(f"  {module_name}: binario no encontrado: {binary_path}")
                continue

            if args.parse_only:
                file_path = f1_results_dir / info["file"]
                if file_path.exists():
                    data = _parse_kv_lines(file_path.read_text().strip())
                    if data:
                        parsed.append((module_name, data))
                        print(f"  {module_name}: {len(data)} campos (desde archivo)")
                    else:
                        print(f"  {module_name}: archivo vacio")
                else:
                    print(f"  {module_name}: archivo no encontrado")
                continue

            cmd = [str(binary_path), str(csv_path), str(args.start), str(args.end), str(f1_cols[i])]
            try:
                result = subprocess.run(
                    cmd, capture_output=True, text=True, timeout=30, cwd=str(fase1_dir)
                )
            except FileNotFoundError:
                print(f"  {module_name}: binario no encontrado")
                continue
            except subprocess.TimeoutExpired:
                print(f"  {module_name}: timeout")
                continue

            if result.returncode != 0:
                print(f"  {module_name}: exit code {result.returncode}")
                stderr = result.stderr.strip()
                if stderr:
                    print(f"    stderr: {stderr[:200]}")
                continue

            file_path = f1_results_dir / info["file"]
            if not file_path.exists():
                print(f"  {module_name}: archivo no encontrado: {file_path}")
                continue

            text = file_path.read_text().strip()
            data = _parse_kv_lines(text)
            if not data:
                print(f"  {module_name}: archivo vacio: {file_path}")
                continue
            parsed.append((module_name, data))
            print(f"  {module_name}: OK ({len(data)} campos)")
    print()

    if not parsed:
        print("No hay resultados para enviar")
        return 1

    # --- Enviar todos los resultados al backend ---
    print("Enviando al backend...")
    success = 0
    for module_name, data in parsed:
        if post_to_backend(args.url, module_name, data):
            success += 1
    print()

    if success == len(parsed):
        print(f"Todos los modulos enviados correctamente ({success}/{len(parsed)})")
        return 0

    print(f"{success}/{len(parsed)} modulos enviados correctamente")
    return 1


if __name__ == "__main__":
    sys.exit(main())
