# Procesamiento de Datos IoT — Coprocesador ARM64 Assembly (AArch64)

Estructura, utilidades y documentación para el coprocesador de procesamiento de datos en bajo nivel, implementado en lenguaje ensamblador ARM64 (AArch64) para ejecutarse nativamente en la **Raspberry Pi 3 (ARM Cortex-A53)**.

---

## Estructura del Directorio

```text
arm64/
├── README.md               # Documentación
├── lecturas.csv            # 30 lecturas de prueba (6 tipos: temp, hum, soil_1, soil_2, light, gas)
├── utils/
│   └── (utils.s)           # Biblioteca común — pendiente de implementar
├── modules/
│   ├── modulo_1_media/     # Cálculo de la Media Ponderada — pendiente
│   ├── modulo_2_varianza/  # Cálculo de la Varianza y Desviación Estándar — pendiente
│   ├── modulo_3_anomalias/ # Detección de Anomalías — pendiente
│   ├── modulo_4_prediccion/# Predicción Lineal Simple — pendiente
│   └── modulo_5_tendencia/ # Análisis de Tendencia Avanzada — pendiente
└── results/                # Salidas de los módulos (.txt) — pendiente
```

---

## Contrato de Módulos Ensamblador

Cada módulo lee `lecturas.csv`, realiza sus operaciones estadísticas y escribe un archivo de salida en `results/`.

### 1. Módulo 1: Media Ponderada
* **Salida**: `results/resultado_media.txt`
* **Fórmula**: `MEDIA = Σ(X_i * W_i) / ΣW_i`

### 2. Módulo 2: Varianza y Desviación Estándar
* **Salida**: `results/resultado_varianza.txt`
* **Fórmula**: `VAR = Σ(X_i - MEDIA)² / N` y `DESV = sqrt(VAR)`

### 3. Módulo 3: Detección de Anomalías
* **Salida**: `results/resultado_anomalias.txt`
* **Fórmula**: `Z = (X_i - MEDIA) / DESV`

### 4. Módulo 4: Predicción Lineal Simple
* **Salida**: `results/resultado_prediccion.txt`
* **Fórmula**: `PRED = X_final + (X_final - X_inicial) / (N - 1)`

### 5. Módulo 5: Tendencia Avanzada
* **Salida**: `results/resultado_tendencia.txt`
* **Fórmula**: `DIF_ACUM = Σ(X_i - X_(i-1))`

---

## Compilación y Ejecución en Raspberry Pi (Linux ARM64)

```bash
# Ensamblar el módulo
as -o modulo.o modulo.s

# Enlazar
ld -o modulo modulo.o

# Ejecutar
./modulo
```
