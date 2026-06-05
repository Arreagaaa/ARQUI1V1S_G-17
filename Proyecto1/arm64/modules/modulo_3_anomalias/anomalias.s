// =============================================================================
// anomalias.s — Módulo 3: Detección estadística de anomalías
// Integrante 3
//
// Lee la columna TEMP del archivo ../lecturas.csv (30 datos reales),
// calcula media y desviación estándar (o las recibe de módulo 2),
// y clasifica cada valor según su Z-score:
//   Z = (X - MEDIA) / DESV
//   |Z| >= 2  →  ANOMALIA
//
// Clasificación de riesgo (enunciado §10.3):
//   0 anomalías      → NORMAL
//   1-3 anomalías    → MEDIUM
//   4+ anomalías     → HIGH
//
// Formato exacto de salida:
//   MODULE=ANOMALY_DETECTION
//   TOTAL_VALUES=30
//   MEAN=29
//   STD_DEV=3
//   ANOMALIES=4
//   SYSTEM_RISK=HIGH
//
// TODO: Integrante 3
//   - Calcular (o leer) media y std_dev de la columna
//   - Para cada valor: z_num = (X - mean) * 100, z_den = std_dev * 100
//   - Comparar |X - mean| con 2 * std_dev
//   - Contar anomalías
//   - Clasificar riesgo
// =============================================================================

.section .data
msg_module:       .ascii "MODULE=ANOMALY_DETECTION\n"
msg_module_len = . - msg_module
msg_total:        .ascii "TOTAL_VALUES=30\n"
msg_total_len = . - msg_total
msg_mean:         .ascii "MEAN="
msg_mean_len = . - msg_mean
msg_stddev:       .ascii "STD_DEV="
msg_stddev_len = . - msg_stddev
msg_anomalies:    .ascii "ANOMALIES="
msg_anomalies_len = . - msg_anomalies
msg_risk_normal:  .ascii "SYSTEM_RISK=NORMAL\n"
msg_risk_normal_len = . - msg_risk_normal
msg_risk_medium:  .ascii "SYSTEM_RISK=MEDIUM\n"
msg_risk_medium_len = . - msg_risk_medium
msg_risk_high:    .ascii "SYSTEM_RISK=HIGH\n"
msg_risk_high_len = . - msg_risk_high
msg_nl:           .ascii "\n"
msg_nl_len = . - msg_nl

.equ N_VALUES, 30
.equ Z_THRESHOLD_NUM, 2     // numerador del threshold: |X - mean| >= 2 * std_dev

.section .bss
.lcomm values,     8 * N_VALUES
.lcomm result_buf, 256

.section .text
.global _start

_start:
    // TODO:
    //   1. utils_open_csv + utils_read_int_column(1, values)
    //   2. mean = compute_mean(values)
    //   3. std_dev = compute_std_dev(values, mean)
    //   4. anomalies = count_anomalies(values, mean, std_dev)
    //   5. risk = classify(anomalies)
    //   6. utils_write_result(...)
    //   7. utils_exit(0)

    mov x0, #0
    bl utils_exit

// Subrutinas propias
compute_mean:      ret
compute_std_dev:   ret
count_anomalies:   ret   // cuenta |X - mean| >= 2 * std_dev
classify:          ret   // NORMAL / MEDIUM / HIGH según cantidad

// Truco: usar aritmética de punto fijo (multiplicar por 100) para evitar
// divisiones con fracciones. Comparar enteros:
//   anomaly = (|X - mean| * 100) >= (2 * std_dev * 100)
