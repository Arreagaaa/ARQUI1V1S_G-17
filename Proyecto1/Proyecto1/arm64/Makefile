# =============================================================================
# Makefile — Invernadero Inteligente IoT (ACYE1, Grupo 17)
#
# Compila utils/utils.s + módulos ARM64 sobre Raspberry Pi 3/4 (AArch64).
# Patrón basado en 02_ARM64/tools/makefile-templates/Makefile.qemu.multi
# del repositorio del auxiliar (D:\Projects\USAC\ARQUI1_1S2026).
#
# Estado actual:
#   - modulo_1_media:      ✅ IMPLEMENTADO (Integrante 1)
#   - modulo_2_varianza:   ✅ IMPLEMENTADO (Integrante 2)
#   - modulo_3_anomalias:  ✅ IMPLEMENTADO (Integrante 3)
#   - modulo_4_prediccion: ✅ IMPLEMENTADO (Integrante 4)
#   - modulo_5_tendencia:  ✅ IMPLEMENTADO (Integrante 5)
#   - utils: ✅ IMPLEMENTADO (biblioteca común con 11 subrutinas)
#
# Targets:
#   make all       → compila utils + los 5 módulos
#   make utils     → solo utils.o
#   make modulo1   → módulo 1 (media ponderada)
#   make modulo2   → módulo 2 (varianza)
#   make modulo3   → módulo 3 (anomalías)
#   make modulo4   → módulo 4 (predicción)
#   make modulo5   → módulo 5 (tendencia)
#   make run1-5    → ejecuta el módulo N con QEMU
#   make gdb1-5    → depura el módulo N con GDB sobre QEMU
#   make runall    → ejecuta los 5 módulos secuencialmente
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

# Módulo 2 (LISTO)
M2_DIR   = modules/modulo_2_varianza
M2_S     = $(M2_DIR)/varianza.s
M2_O     = $(BUILD)/modulo_2_varianza.o
M2_BIN   = $(BUILD)/modulo_2_varianza

# Módulo 3 (LISTO)
M3_DIR   = modules/modulo_3_anomalias
M3_S     = $(M3_DIR)/anomalias.s
M3_O     = $(BUILD)/modulo_3_anomalias.o
M3_BIN   = $(BUILD)/modulo_3_anomalias

# Módulo 5 (LISTO)
M5_DIR   = modules/modulo_5_tendencia
M5_S     = $(M5_DIR)/tendencia.s
M5_O     = $(BUILD)/modulo_5_tendencia.o
M5_BIN   = $(BUILD)/modulo_5_tendencia

ASFLAGS  = -g
LDFLAGS  =

.PHONY: all utils modulo1 modulo2 modulo3 modulo4 modulo5 \
        run1 run2 run3 run4 run5 runall gdb1 gdb2 gdb3 gdb4 gdb5 clean info status

all: utils modulo1 modulo2 modulo3 modulo4 modulo5
	@echo
	@echo "==> Listos: los 5 módulos ARM64"

utils: $(UTILS_O)

# ----------------------------------------------------------------------------
# utils.s (biblioteca común — tarea grupal, pendiente de implementación)
# ----------------------------------------------------------------------------
$(UTILS_O): $(UTILS) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

# ----------------------------------------------------------------------------
# Módulo 1 — Media aritmética ponderada (LISTO)
# ----------------------------------------------------------------------------
# media.s usa utils.s (open_csv, read_int_column, etc.).
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
# Módulo 2 — Varianza y Desviación Estándar (LISTO)
# ----------------------------------------------------------------------------
$(M2_O): $(M2_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M2_BIN): $(M2_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

modulo2: $(M2_BIN)
	@echo "==> modulo_2_varianza compilado: $(M2_BIN)"

# ----------------------------------------------------------------------------
# Módulo 3 — Detección de Anomalías (LISTO)
# ----------------------------------------------------------------------------
$(M3_O): $(M3_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M3_BIN): $(M3_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

modulo3: $(M3_BIN)
	@echo "==> modulo_3_anomalias compilado: $(M3_BIN)"

# ----------------------------------------------------------------------------
# Módulo 5 — Tendencia Acumulada Avanzada (LISTO)
# ----------------------------------------------------------------------------
$(M5_O): $(M5_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M5_BIN): $(M5_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

modulo5: $(M5_BIN)
	@echo "==> modulo_5_tendencia compilado: $(M5_BIN)"

# ----------------------------------------------------------------------------
# Ejecución y depuración con QEMU
# ----------------------------------------------------------------------------
run1: $(M1_BIN)
	mkdir -p results
	$(QEMU) $<
	@echo "--- Resultado ---"
	@cat results/resultado_media.txt

run2: $(M2_BIN)
	mkdir -p results
	$(QEMU) $<
	@echo "--- Resultado ---"
	@cat results/resultado_varianza.txt

run3: $(M3_BIN)
	mkdir -p results
	$(QEMU) $<
	@echo "--- Resultado ---"
	@cat results/resultado_anomalias.txt

run4: $(M4_BIN)
	mkdir -p results
	$(QEMU) $<
	@echo "--- Resultado ---"
	@cat results/resultado_prediccion.txt

run5: $(M5_BIN)
	mkdir -p results
	$(QEMU) $<
	@echo "--- Resultado ---"
	@cat results/resultado_tendencia.txt

runall: run1 run2 run3 run4 run5
	@echo "=== Los 5 módulos ejecutados ==="

gdb1: $(M1_BIN)
	$(QEMU) -g 1234 $<

gdb2: $(M2_BIN)
	$(QEMU) -g 1234 $<

gdb3: $(M3_BIN)
	$(QEMU) -g 1234 $<

gdb4: $(M4_BIN)
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
	@echo "Biblioteca común:"
	@echo "  utils = $(UTILS_O)     (11 subrutinas)      ✅"
	@echo
	@echo "Módulos (los 5 listos):"
	@echo "  M1    = $(M1_BIN)  (media ponderada)      ✅"
	@echo "  M2    = $(M2_BIN)  (varianza)              ✅"
	@echo "  M3    = $(M3_BIN)  (anomalías)             ✅"
	@echo "  M4    = $(M4_BIN)  (predicción)            ✅"
	@echo "  M5    = $(M5_BIN)  (tendencia)             ✅"

status:
	@echo "=== Estado de los 5 módulos ARM64 ==="
	@echo
	@if [ -f "$(M1_S)" ]; then echo "✅  M1  media.s            (Integrante 1)"; else echo "❌  M1  media.s"; fi
	@if [ -f "$(M2_S)" ]; then echo "✅  M2  varianza.s         (Integrante 2)"; else echo "⏳  M2  varianza.s         (Integrante 2) — PENDIENTE"; fi
	@if [ -f "$(M3_S)" ]; then echo "✅  M3  anomalias.s        (Integrante 3)"; else echo "⏳  M3  anomalias.s        (Integrante 3) — PENDIENTE"; fi
	@if [ -f "$(M4_S)" ]; then echo "✅  M4  predicciones.s     (Integrante 4)"; else echo "❌  M4  predicciones.s"; fi
	@if [ -f "$(M5_S)" ]; then echo "✅  M5  tendencia.s        (Integrante 5)"; else echo "⏳  M5  tendencia.s        (Integrante 5) — PENDIENTE"; fi
	@echo
	@if [ -f "$(UTILS_O)" ]; then echo "✅  utils.o (biblioteca común con 11 subrutinas)"; else echo "⏳  utils.s — PENDIENTE"; fi