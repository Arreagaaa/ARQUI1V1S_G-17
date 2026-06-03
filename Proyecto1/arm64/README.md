# Procesamiento de Datos IoT — Coprocesador ARM64 Assembly (AArch64)

Este directorio contiene la estructura, utilidades y documentación de soporte para el coprocesador de procesamiento de datos en bajo nivel, implementado en lenguaje ensamblador ARM64 (AArch64) y diseñado para ejecutarse nativamente en la **Raspberry Pi 3 (ARM Cortex-A53)**.

---

## Estructura del Directorio

```text
arm64/
├── README.md               # Este archivo de documentación
├── lecturas.csv            # Archivo CSV de entrada con 30 lecturas de prueba
├── utils/
│   └── utils.s             # Biblioteca común (rutinas de E/S, conversión, etc.) [Placeholder]
├── modules/
│   ├── modulo_1_media/     # Cálculo de la Media Ponderada
│   ├── modulo_2_varianza/  # Cálculo de la Varianza y Desviación Estándar
│   ├── modulo_3_anomalias/ # Detección de Anomalías (Límite Z)
│   ├── modulo_4_prediccion/# Predicción Lineal Simple
│   └── modulo_5_tendencia/ # Análisis de Tendencia Avanzada
└── results/                # Directorio donde se guardan las salidas de texto (.txt)
```

---

## Contrato de Módulos Ensamblador

Cada módulo lee el archivo de datos (`lecturas.csv`), realiza sus operaciones estadísticas y escribe un archivo de salida en formato plano (`arm64/results/...`) para ser consumido y reportado a la base de datos por el script de la Raspberry Pi.

### 1. Módulo 1: Media Ponderada
* **Archivo**: `modules/modulo_1_media/modulo_1_media.s`
* **Salida**: `results/resultado_media.txt`
* **Fórmula**: `MEDIA = Σ(X_i * W_i) / ΣW_i`
* **Descripción**: Asigna mayor peso a las lecturas más recientes.

### 2. Módulo 2: Varianza y Desviación Estándar
* **Archivo**: `modules/modulo_2_varianza/modulo_2_varianza.s`
* **Salida**: `results/resultado_varianza.txt`
* **Fórmula**: `VAR = Σ(X_i - MEDIA)² / N` y `DESV = sqrt(VAR)`
* **Descripción**: Evalúa la dispersión de las lecturas.

### 3. Módulo 3: Detección de Anomalías
* **Archivo**: `modules/modulo_3_anomalias/modulo_3_anomalias.s`
* **Salida**: `results/resultado_anomalias.txt`
* **Fórmula**: `Z = (X_i - MEDIA) / DESV`
* **Descripción**: Clasifica las lecturas fuera de rango Z como anomalías críticas y calcula el nivel de riesgo del sistema.

### 4. Módulo 4: Predicción Lineal Simple
* **Archivo**: `modules/modulo_4_prediccion/modulo_4_prediccion.s`
* **Salida**: `results/resultado_prediccion.txt`
* **Fórmula**: `PRED = X_final + (X_final - X_inicial) / (N - 1)`
* **Descripción**: Estima el siguiente valor esperado de la variable.

### 5. Módulo 5: Tendencia Avanzada
* **Archivo**: `modules/modulo_5_tendencia/modulo_5_tendencia.s`
* **Salida**: `results/resultado_tendencia.txt`
* **Fórmula**: `DIF_ACUM = Σ(X_i - X_(i-1))`
* **Descripción**: Cuenta incrementos/decrementos y racha alcista/bajista para predecir si la tendencia es UP o DOWN.

---

## Compilación y Ejecución en Raspberry Pi (Linux ARM64)

Para compilar y enlazar cualquiera de los módulos usando `gcc` o `as` directamente en la Raspberry Pi:

```bash
# Ensamblar el módulo
as -o modulo.o modulo_1_media.s

# Enlazar con la biblioteca estándar C (si es necesario) o con utils.s
gcc -o modulo_media modulo.o -lc

# Ejecutar
./modulo_media
```
