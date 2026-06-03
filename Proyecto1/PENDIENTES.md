# 📋 Pendientes — Invernadero Inteligente

Checklist completo del proyecto. Lo que está marcado con ✅ ya está hecho y funcionando. Lo marcado con ⬜ está pendiente.

Última actualización: 2026-06-03

---

## 1. Dashboard Web (7 pts)

| Estado | Criterio | Pts | Notas |
|---|---|---|---|
| ✅ | Panel principal con lecturas actuales y estado global | 2 | Muestra temperatura, humedad, suelo (2 áreas), luz, gas, riego, ventilación, luces, alarma |
| ✅ | Gráficas históricas de sensores | 1 | Gráficos SVG de temperatura, humedad, suelo, luz y gas con últimos 30 datos |
| ✅ | Controles remotos funcionales | 2 | Riego, luces, ventilación, alarma, modo auto/manual |
| ✅ | Historial de eventos y comandos | 1 | Últimos eventos, comandos, alertas y logs de actuadores |
| ✅ | Sección de resultados ARM64 | 1 | Muestra los 5 módulos ARM64 (con datos mock por ahora) |

**Subtotal: 7/7 ✅**

---

## 2. Comunicación IoT y persistencia (12 pts)

| Estado | Criterio | Pts | Notas |
|---|---|---|---|
| ⬜ | Implementación funcional de MQTT | 4 | Pendiente: conectar a broker, configurar topics reales |
| ⬜ | Recepción y ejecución de comandos desde dashboard hacia Pi | 2 | Pendiente: la Pi debe recibir y ejecutar comandos vía MQTT |
| ✅ | Persistencia en MongoDB (local, migrar a Atlas) | 3 | Funciona local. Pendiente: migrar a MongoDB Atlas |
| ✅ | Organización correcta de colecciones y documentos | 2 | Todas las colecciones con timestamp, origen, valor, tipo, estado |
| ⬜ | Evidencia de flujo IoT funcional | 1 | Pendiente: demostrar sensores → Python → MQTT → MongoDB → dashboard → actuadores |

**Subtotal: 5/12 (7 pendientes)**

---

## 3. Sensores y actuadores (15 pts)

| Estado | Criterio | Pts | Notas |
|---|---|---|---|
| ⬜ | Lectura de 6 tipos de sensores | 3 | DHT22 (temp+hum), 2×higrómetro suelo, LDR (luz), MQ (gas) |
| ⬜ | Lógica automática basada en valores reales | 2 | Las reglas están en el backend, falta conectar sensores reales |
| ⬜ | Registro de eventos y comandos ejecutados | 1 | La lógica existe, falta que la Pi publique eventos reales |
| ⬜ | Control de actuadores (bomba, ventilador, luces, alarma) | 3 | GPIO preparado en `raspberry/main.py`, falta hardware real |
| ⬜ | LCD con información del sistema | 2 | Pendiente: LCD I2C en centro de control |
| ⬜ | Botones físicos para control local | 2 | Pendiente: botones en la maqueta |
| ⬜ | Lógica integrada en la Raspberry Pi | 2 | `raspberry/main.py` tiene la base, falta integrar con sensores reales |

**Subtotal: 0/15 (todo pendiente — requiere hardware)**

---

## 4. Módulos ARM64 individuales (25 pts)

| Estado | Módulo | Responsable | Pts | Notas |
|---|---|---|---|---|
| ⬜ | Biblioteca común `utils.s` | Grupal | 5 | Lectura CSV, parsing, conversión ASCII↔entero, escritura |
| ⬜ | Módulo 1: Media aritmética ponderada | Integrante 1 | 4 | Compilar, ejecutar, procesar datos, generar salida, defender |
| ⬜ | Módulo 2: Varianza y desviación estándar | Integrante 2 | 4 | Compilar, ejecutar, procesar datos, generar salida, defender |
| ⬜ | Módulo 3: Detección estadística de anomalías | Integrante 3 | 4 | Compilar, ejecutar, procesar datos, generar salida, defender |
| ⬜ | Módulo 4: Predicción lineal simple | Integrante 4 | 4 | Compilar, ejecutar, procesar datos, generar salida, defender |
| ⬜ | Módulo 5: Tendencia acumulada avanzada | Integrante 5 | 4 | Compilar, ejecutar, procesar datos, generar salida, defender |

**Subtotal: 0/25 (todo pendiente — cada integrante debe hacer el suyo)**

---

## 5. Integración ARM64 con sistema IoT (10 pts)

| Estado | Criterio | Pts | Notas |
|---|---|---|---|
| ⬜ | Generar `lecturas.csv` desde Python con 30 datos reales | 2 | Crear `raspberry/generate_csv.py` |
| ⬜ | Ejecución automática de módulos ARM64 desde Python | 2 | Crear `raspberry/arm_executor.py` con `subprocess.run()` |
| ⬜ | Lectura de archivos de salida generados por ARM64 | 2 | Leer `resultado_mX.txt` |
| ✅ | Almacenamiento de resultados ARM64 en MongoDB | 2 | Endpoint `POST /api/arm64-results` + colección `arm64_results` listo |
| ✅ | Visualización de resultados ARM64 en dashboard | 1 | Sección ARM64 en el dashboard funciona |
| ⬜ | Evidencia de depuración con GDB por integrante | 1 | Cada uno debe mostrar breakpoints, registros, memoria |

**Subtotal: 3/10 (7 pendientes)**

---

## 6. Funcionamiento global del sistema (5 pts)

| Estado | Criterio | Pts | Notas |
|---|---|---|---|
| ⬜ | Integración completa de subsistemas | 3 | Sensores + Python + actuadores + MQTT + MongoDB + dashboard + ARM64 |
| ⬜ | Estabilidad durante la evaluación | 2 | Demo continua sin fallas |

**Subtotal: 0/5 (requiere integración completa)**

---

## 7. Documentación y entrega (obligatorio)

| Estado | Criterio | Notas |
|---|---|---|
| ✅ | README.md oficial | Documentación completa del proyecto |
| ✅ | DEVELOPERS.md | Guía técnica para el equipo |
| ✅ | PENDIENTES.md | Este archivo |
| ✅ | Contrato MQTT documentado | `docs/mqtt-contrato.md` |
| ⬜ | Video demostrativo | Pendiente: grabar demo final |

---

## 8. Maqueta física (obligatorio)

| Estado | Criterio | Notas |
|---|---|---|
| ⬜ | Dos áreas de cultivo + centro de control | **Sin maqueta = 100% penalización grupal** |
| ⬜ | Sensores instalados en la maqueta | DHT22, higrómetros, LDR, MQ |
| ⬜ | Actuadores instalados | Bomba, ventilador, luces LED, buzzer |
| ⬜ | LCD + botones en centro de control | LCD I2C 16x2, botones para control local |

---

## Resumen de puntuación

| Área | Hecho | Pendiente | Total |
|---|---|---|---|
| Dashboard web | 7 | 0 | 7 |
| Comunicación IoT + persistencia | 5 | 7 | 12 |
| Sensores y actuadores | 0 | 15 | 15 |
| ARM64 individuales | 0 | 25 | 25 |
| Integración ARM64 | 3 | 7 | 10 |
| Funcionamiento global | 0 | 5 | 5 |
| **TOTAL** | **15** | **59** | **74** *(de 90 conocimientos + 10 competencias)* |

> Los 10 puntos de **competencias** se evalúan durante la defensa individual.

---

## Próximos pasos inmediatos

1. ⬜ **MongoDB Atlas** — Crear cluster, configurar URI, verificar conexión
2. ⬜ **ARM64** — Cada integrante crea su rama y empieza su módulo
3. ⬜ **MQTT** — Configurar broker (EMQX Cloud o público) y conectar
4. ⬜ **Maqueta** — Construir la maqueta física con 2 áreas + centro de control
5. ⬜ **Sensores** — Conectar sensores reales a la Raspberry Pi
6. ⬜ **Integración final** — Conectar todo: Pi → MQTT → Backend → Dashboard
