# =============================================================================
# Makefile — Invernadero Inteligente IoT (ACYE1, Grupo 17)
#
# Compila utils/utils.s + módulos ARM64 sobre Raspberry Pi 3/4 (AArch64).
# Patrón basado en 02_ARM64/tools/makefile-templates/Makefile.qemu.multi
# del repositorio del auxiliar (D:\Projects\USAC\ARQUI1_1S2026).
#
# Estado actual (post-limpieza 2026-06-05):
#   - modulo_1_media: ✅ IMPLEMENTADO (Integrante 1 — listo para QEMU)
#   - modulo_2_varianza: ⏳ pendiente (Integrante 2)
#   - modulo_3_anomalias: ⏳ pendiente (Integrante 3)
#   - modulo_4_prediccion: ⏳ pendiente (Integrante 4)
#   - modulo_5_tendencia:  ✅ IMPLEMENTADO (Integrante 5 — listo para QEMU)
#   - utils: ⏳ pendiente (tarea grupal, opcional — modulo_1 es auto-contenido)
#
# Targets:
#   make all       → compila utils + modulo_1_media (lo único listo)
#   make utils     → solo utils.o
#   make modulo1   → módulo 1 (media ponderada) — LISTO
#   make modulo2   → solo módulo 2 (varianza) — pendiente
#   make modulo3   → solo módulo 3 (anomalías) — pendiente
#   make modulo4   → solo módulo 4 (predicción) — pendiente
#   make modulo5   → solo módulo 5 (tendencia) — LISTO
#   make run1      → ejecuta modulo_1_media con QEMU
#   make gdb1      → depura modulo_1_media con GDB sobre QEMU
#   make clean     → borra build/
#   make info      → muestra toolchain y variables
#   make status    → muestra qué módulos están listos
#
# Uso típico en Raspberry Pi 3/4 (toolchain nativa):
#   sudo apt install binutils-aarch64-linux-gnu
#   make all
#   ./build/modulo_1_media
#
# Uso típico en PC con QEMU (para pruebas cruzadas):
#   sudo apt install qemu-user gdb-multiarch
#   make run1
# =============================================================================

AS      = aarch64-linux-gnu-as
LD      = aarch64-linux-gnu-ld
QEMU    ?= qemu-aarch64
GDB     ?= gdb-multiarch

BUILD    = build
UTILS    = utils/utils.s
UTILS_O  = $(BUILD)/utils.o

# Módulo 1 (LISTO)
M1_DIR   = modules/modulo_1_media
M1_S     = $(M1_DIR)/media.s
M1_O     = $(BUILD)/modulo_1_media.o
M1_BIN   = $(BUILD)/modulo_1_media

# Módulo 4 (LISTO)
M4_DIR   = modules/modulo_4_prediccion
M4_S     = $(M4_DIR)/predicciones.s
M4_O     = $(BUILD)/modulo_4_prediccion.o
M4_BIN   = $(BUILD)/modulo_4_prediccion

# Módulo 5 (LISTO)
M5_DIR   = modules/modulo_5_tendencia
M5_S     = $(M5_DIR)/tendencia.s
M5_O     = $(BUILD)/modulo_5_tendencia.o
M5_BIN   = $(BUILD)/modulo_5_tendencia

# Módulos 2-3 (PENDIENTES — targets emiten mensaje y salen)
M2_S     = modules/modulo_2_varianza/varianza.s
M3_S     = modules/modulo_3_anomalias/anomalias.s

ASFLAGS  = -g
LDFLAGS  =

.PHONY: all utils modulo1 modulo2 modulo3 modulo4 modulo5 \
        run1 run4 run5 gdb1 gdb4 gdb5 clean info status

# Por ahora `all` compila utils + módulos implementados
all: utils modulo1 modulo4 modulo5
	@echo
	@echo "==> Listo: build/modulo_1_media, build/modulo_4_prediccion, build/modulo_5_tendencia"
	@echo "    Pendientes: modulo_2_varianza, modulo_3_anomalias"

utils: $(UTILS_O)

# ----------------------------------------------------------------------------
# utils.s (biblioteca común — tarea grupal, pendiente de implementación)
# ----------------------------------------------------------------------------
$(UTILS_O): $(UTILS) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

# ----------------------------------------------------------------------------
# Módulo 1 — Media aritmética ponderada (LISTO)
# ----------------------------------------------------------------------------
# media.s es 100% auto-contenido: no usa `.extern` ni símbolos de utils.s.
# El enlace con utils.o es por compatibilidad con el Makefile multi-módulo
# del auxiliar; si utils.s no compila, este target sigue funcionando.
$(M1_O): $(M1_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M1_BIN): $(M1_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

modulo1: $(M1_BIN)
	@echo "==> modulo_1_media compilado: $(M1_BIN)"

# ----------------------------------------------------------------------------
# Módulo 4 — Predicción lineal simple (LISTO)
# ----------------------------------------------------------------------------
$(M4_O): $(M4_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M4_BIN): $(M4_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

modulo4: $(M4_BIN)
	@echo "==> modulo_4_prediccion compilado: $(M4_BIN)"

# ----------------------------------------------------------------------------
# Módulo 5 — Tendencia acumulada avanzada (LISTO)
# ----------------------------------------------------------------------------
$(M5_O): $(M5_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M5_BIN): $(M5_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

modulo5: $(M5_BIN)
	@echo "==> modulo_5_tendencia compilado: $(M5_BIN)"

# ----------------------------------------------------------------------------
# Módulos 2-3 — PENDIENTES (mensaje informativo, no fallan el make)
# ----------------------------------------------------------------------------
modulo2:
	@echo "⏳ modulo_2_varianza: PENDIENTE — Implementar Integrante 2"
	@echo "   Ver enunciado §10.2 y modules/modulo_2_varianza/README.md"
	@false

modulo3:
	@echo "⏳ modulo_3_anomalias: PENDIENTE — Implementar Integrante 3"
	@echo "   Ver enunciado §10.3 y modules/modulo_3_anomalias/README.md"
	@false

# ----------------------------------------------------------------------------
# Ejecución y depuración con QEMU
# ----------------------------------------------------------------------------
run1: $(M1_BIN)
	$(QEMU) $<

run4: $(M4_BIN)
	$(QEMU) $<
	@echo "--- Resultado ---"
	@cat results/resultado_prediccion.txt

run5: $(M5_BIN)
	$(QEMU) $<

gdb1: $(M1_BIN)
	$(QEMU) -g 1234 $<

gdb4: $(M4_BIN)
	@echo "Iniciando QEMU en puerto 1234..."
	$(QEMU) -g 1234 $<

gdb5: $(M5_BIN)
	$(QEMU) -g 1234 $<

# ----------------------------------------------------------------------------
# Utilidades
# ----------------------------------------------------------------------------
$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)

info:
	@echo "Toolchain:"
	@echo "  AS    = $(AS)"
	@echo "  LD    = $(LD)"
	@echo "  QEMU  = $(QEMU)"
	@echo "  GDB   = $(GDB)"
	@echo
	@echo "Módulos listos:"
	@echo "  M1    = $(M1_BIN)  (media ponderada) ✅"
	@echo "  M4    = $(M4_BIN)  (predicción) ✅"
	@echo "  M5    = $(M5_BIN)  (tendencia) ✅"
	@echo
	@echo "Módulos pendientes (no compilan aún):"
	@echo "  M2    = modulo_2_varianza  ⏳"
	@echo "  M3    = modulo_3_anomalias ⏳"

status:
	@echo "=== Estado de los 5 módulos ARM64 ==="
	@echo
	@if [ -f "$(M1_S)" ]; then echo "✅  M1  media.s            (Integrante 1)"; else echo "❌  M1  media.s"; fi
	@if [ -f "$(M2_S)" ]; then echo "✅  M2  varianza.s         (Integrante 2)"; else echo "⏳  M2  varianza.s         (Integrante 2) — PENDIENTE"; fi
	@if [ -f "$(M3_S)" ]; then echo "✅  M3  anomalias.s        (Integrante 3)"; else echo "⏳  M3  anomalias.s        (Integrante 3) — PENDIENTE"; fi
	@if [ -f "$(M4_S)" ]; then echo "✅  M4  predicciones.s     (Integrante 4)"; else echo "❌  M4  predicciones.s"; fi
	@if [ -f "$(M5_S)" ]; then echo "✅  M5  tendencia.s        (Integrante 5)"; else echo "⏳  M5  tendencia.s        (Integrante 5) — PENDIENTE"; fi
	@echo
	@if [ -f "$(UTILS_O)" ]; then echo "✅  utils.o"; else echo "⏳  utils.s (biblioteca común) — tarea grupal PENDIENTE"; fi