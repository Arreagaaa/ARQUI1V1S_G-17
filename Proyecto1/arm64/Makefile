// =============================================================================
// Makefile — Invernadero Inteligente IoT (ACYE1, Grupo 17)
//
// Compila utils/utils.s + módulos ARM64 sobre Raspberry Pi 3/4 (AArch64).
// Patrón basado en 02_ARM64/tools/makefile-templates/Makefile.qemu.multi
// del repositorio del auxiliar (D:\Projects\USAC\ARQUI1_1S2026).
//
// Estado actual (post-limpieza 2026-06-05):
//   - modulo_1_media: ✅ IMPLEMENTADO (Integrante 1 — listo para QEMU)
//   - modulo_2_varianza: ⏳ pendiente (Integrante 2)
//   - modulo_3_anomalias: ⏳ pendiente (Integrante 3)
//   - modulo_4_prediccion: ⏳ pendiente (Integrante 4)
//   - modulo_5_tendencia:  ⏳ pendiente (Integrante 5)
//   - utils: ⏳ pendiente (tarea grupal, opcional — modulo_1 es auto-contenido)
//
// Targets:
//   make all       → compila utils + modulo_1_media (lo único listo)
//   make utils     → solo utils.o
//   make modulo1   → módulo 1 (media ponderada) — LISTO
//   make modulo2   → solo módulo 2 (varianza) — pendiente
//   make modulo3   → solo módulo 3 (anomalías) — pendiente
//   make modulo4   → solo módulo 4 (predicción) — pendiente
//   make modulo5   → solo módulo 5 (tendencia) — pendiente
//   make run1      → ejecuta modulo_1_media con QEMU
//   make gdb1      → depura modulo_1_media con GDB sobre QEMU
//   make clean     → borra build/
//   make info      → muestra toolchain y variables
//   make status    → muestra qué módulos están listos
//
// Uso típico en Raspberry Pi 3/4 (toolchain nativa):
//   sudo apt install binutils-aarch64-linux-gnu
//   make all
//   ./build/modulo_1_media
//
// Uso típico en PC con QEMU (para pruebas cruzadas):
//   sudo apt install qemu-user gdb-multiarch
//   make run1
// =============================================================================

AS      ?= aarch64-linux-gnu-as
LD      ?= aarch64-linux-gnu-ld
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

# Módulos 2-5 (PENDIENTES — targets emiten mensaje y salen)
M2_S     = modules/modulo_2_varianza/varianza.s
M3_S     = modules/modulo_3_anomalias/anomalias.s
M4_S     = modules/modulo_4_prediccion/prediccion.s
M5_S     = modules/modulo_5_tendencia/tendencia.s

ASFLAGS  = -g
LDFLAGS  =

.PHONY: all utils modulo1 modulo2 modulo3 modulo4 modulo5 \
        run1 gdb1 clean info status

# Por ahora `all` solo compila utils + módulo 1 (lo único implementado)
all: utils modulo1
	@echo
	@echo "==> Listo: build/modulo_1_media"
	@echo "    Pendientes: modulo_2_varianza, modulo_3_anomalias, modulo_4_prediccion, modulo_5_tendencia"

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
# Módulos 2-5 — PENDIENTES (mensaje informativo, no fallan el make)
# ----------------------------------------------------------------------------
modulo2:
	@echo "⏳ modulo_2_varianza: PENDIENTE — Implementar Integrante 2"
	@echo "   Ver enunciado §10.2 y modules/modulo_2_varianza/README.md"
	@false

modulo3:
	@echo "⏳ modulo_3_anomalias: PENDIENTE — Implementar Integrante 3"
	@echo "   Ver enunciado §10.3 y modules/modulo_3_anomalias/README.md"
	@false

modulo4:
	@echo "⏳ modulo_4_prediccion: PENDIENTE — Implementar Integrante 4"
	@echo "   Ver enunciado §10.4 y modules/modulo_4_prediccion/README.md"
	@false

modulo5:
	@echo "⏳ modulo_5_tendencia: PENDIENTE — Implementar Integrante 5"
	@echo "   Ver enunciado §10.5 y modules/modulo_5_tendencia/README.md"
	@false

# ----------------------------------------------------------------------------
# Ejecución y depuración con QEMU
# ----------------------------------------------------------------------------
run1: $(M1_BIN)
	$(QEMU) $<

gdb1: $(M1_BIN)
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
	@echo "Módulo listo:"
	@echo "  M1    = $(M1_BIN)  (media ponderada) ✅"
	@echo
	@echo "Módulos pendientes (no compilan aún):"
	@echo "  M2    = modulo_2_varianza  ⏳"
	@echo "  M3    = modulo_3_anomalias ⏳"
	@echo "  M4    = modulo_4_prediccion ⏳"
	@echo "  M5    = modulo_5_tendencia  ⏳"

status:
	@echo "=== Estado de los 5 módulos ARM64 ==="
	@echo
	@if [ -f "$(M1_S)" ]; then echo "✅  M1  media.s            (Integrante 1)"; else echo "❌  M1  media.s"; fi
	@if [ -f "$(M2_S)" ]; then echo "✅  M2  varianza.s         (Integrante 2)"; else echo "⏳  M2  varianza.s         (Integrante 2) — PENDIENTE"; fi
	@if [ -f "$(M3_S)" ]; then echo "✅  M3  anomalias.s        (Integrante 3)"; else echo "⏳  M3  anomalias.s        (Integrante 3) — PENDIENTE"; fi
	@if [ -f "$(M4_S)" ]; then echo "✅  M4  prediccion.s       (Integrante 4)"; else echo "⏳  M4  prediccion.s       (Integrante 4) — PENDIENTE"; fi
	@if [ -f "$(M5_S)" ]; then echo "✅  M5  tendencia.s        (Integrante 5)"; else echo "⏳  M5  tendencia.s        (Integrante 5) — PENDIENTE"; fi
	@echo
	@if [ -f "$(UTILS_O)" ]; then echo "✅  utils.o"; else echo "⏳  utils.s (biblioteca común) — tarea grupal PENDIENTE"; fi
