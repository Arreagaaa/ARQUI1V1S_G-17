# Pendientes — Invernadero Inteligente

Checklist del proyecto. Última actualización: **2026-06-04** (fase MQTT cerrada, pre-Atlas).

---

## Fase actual: PRE-ATLAS / PRE-MAQUETA / PRE-ARM

Lo que ya está listo para avanzar al siguiente hito sin re-trabajar MQTT.

| Área | Estado | Notas |
|---|---|---|
| Dashboard web (7 pts rúbrica) | ✅ | Panel, gráficas, controles, historial, sección ARM64 (mock) |
| Backend REST + reglas automáticas | ✅ | Modo auto/manual, estados globales, umbrales |
| MongoDB local (6 colecciones) | ✅ | Listo para cambiar solo `MONGODB_URI` → Atlas |
| MQTT + MQTTX Web | ✅ | `broker.emqx.io`, base `grupo17/invernadero`, WSS :8084 |
| Tests automatizados | ✅ | `test_regresion.py` 45/45, `test_mqttx_simulator.py` 12/12 |
| Estructura ARM64 + `lecturas.csv` | ✅ plantilla | Falta `utils.s` y los 5 módulos `.s` por integrante |
| Maqueta + sensores GPIO reales | ⬜ | Requiere hardware |
| MongoDB Atlas | ⬜ | Siguiente paso recomendado |
| Video + informe técnico | ⬜ | Entrega final |

---

## 1. Dashboard Web — 7/7 ✅

Completado. No modificar sin coordinación en el grupo.

---

## 2. Comunicación IoT y persistencia — 9/12 (3 pendientes Atlas/Pi)

| Estado | Criterio | Notas |
|---|---|---|
| ✅ | MQTT funcional (publicar/suscribir, topics del enunciado) | EMQX público + MQTTX Web documentado |
| ✅ | Comandos remotos → backend → MongoDB | `control/remoto`, filtro anti-loop, `source` en historial |
| ✅ | Persistencia MongoDB local | 6 colecciones con timestamp y origen |
| ✅ | Organización de colecciones | Índices y seed |
| ⬜ | Evidencia con Raspberry Pi real | Cuando exista maqueta |
| ⬜ | MongoDB Atlas en producción | Cambiar URI y probar Compass/Atlas |
| ⬜ | Flujo IoT completo con hardware | Pi → MQTT → backend → dashboard → actuadores físicos |

---

## 3. Sensores y actuadores (hardware) — 0/15 ⬜

Todo depende de la maqueta y `raspberry/main.py` con GPIO real.

---

## 4. Módulos ARM64 — 0/25 ⬜

| Tarea | Responsable |
|---|---|
| `arm64/utils/utils.s` | Grupal (primero) |
| `modulo_1_media.s` … `modulo_5_tendencia.s` | Cada integrante |
| Makefile que compile los 5 módulos | Grupal |
| Evidencia GDB | Individual |

Referencia de curso: `ARQUI1_1S2026/02_ARM64` (lecciones de arreglos, loops, ABI, GDB).

---

## 5. Integración ARM64 — 3/10

| Estado | Criterio |
|---|---|
| ✅ | Endpoints y colección `arm64_results` + dashboard |
| ⬜ | `lecturas.csv` desde 30 lecturas **reales** del invernadero |
| ⬜ | `raspberry/arm_executor.py` (subprocess, sin calcular en Python) |
| ⬜ | GDB por integrante |

---

## Próximos pasos (orden sugerido)

1. **MongoDB Atlas** — cluster, usuario, `MONGODB_URI` en `backend/.env`, verificar `/api/health`.
2. **ARM64** — `utils.s` + un módulo por integrante; usar `arm64/lecturas.csv` y plantillas en `ARQUI1_1S2026`.
3. **Maqueta** — dos áreas + centro de control (obligatorio para nota grupal).
4. **Raspberry Pi** — sensores/actuadores, publicar mismos topics que el simulador.
5. **Video + diagramas** — arquitectura, flujo MQTT, capturas MQTTX y Compass/Atlas.

---

## Cómo re-validar antes de cada entrega

```powershell
cd Proyecto1\backend
pip install -r requirements.txt
# Backend corriendo en :8080 con ENABLE_MQTT=true
python test_regresion.py
python test_mqttx_simulator.py
```

MQTTX Web manual: [docs/MQTTX_SETUP.md](docs/MQTTX_SETUP.md).
