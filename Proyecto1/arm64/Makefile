// =============================================================================
// Makefile — Invernadero Inteligente IoT (ACYE1, Grupo 17)
//
// Compila utils/utils.s + 5 módulos ARM64 sobre Raspberry Pi 3/4 (AArch64).
// Patrón basado en 02_ARM64/tools/makefile-templates/Makefile.qemu.multi
// del repositorio del auxiliar (D:\Projects\USAC\ARQUI1_1S2026).
//
// Targets:
//   make all       → compila utils + los 5 módulos
//   make utils     → solo utils.o (objeto compartido)
//   make modulo1   → solo módulo 1 (media ponderada)
//   make modulo2   → solo módulo 2 (varianza)
//   make modulo3   → solo módulo 3 (anomalías)
//   make modulo4   → solo módulo 4 (predicción)
//   make modulo5   → solo módulo 5 (tendencia)
//   make run1      → ejecuta modulo1 con QEMU
//   make gdb1      → depura modulo1 con GDB sobre QEMU
//   make clean     → borra build/
//   make info      → muestra toolchain y variables
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

# Módulos individuales
M1_DIR   = modules/modulo_1_media
M2_DIR   = modules/modulo_2_varianza
M3_DIR   = modules/modulo_3_anomalias
M4_DIR   = modules/modulo_4_prediccion
M5_DIR   = modules/modulo_5_tendencia

M1_S     = $(M1_DIR)/media.s
M2_S     = $(M2_DIR)/varianza.s
M3_S     = $(M3_DIR)/anomalias.s
M4_S     = $(M4_DIR)/prediccion.s
M5_S     = $(M5_DIR)/tendencia.s

M1_O     = $(BUILD)/modulo_1_media.o
M2_O     = $(BUILD)/modulo_2_varianza.o
M3_O     = $(BUILD)/modulo_3_anomalias.o
M4_O     = $(BUILD)/modulo_4_prediccion.o
M5_O     = $(BUILD)/modulo_5_tendencia.o

M1_BIN   = $(BUILD)/modulo_1_media
M2_BIN   = $(BUILD)/modulo_2_varianza
M3_BIN   = $(BUILD)/modulo_3_anomalias
M4_BIN   = $(BUILD)/modulo_4_prediccion
M5_BIN   = $(BUILD)/modulo_5_tendencia

ASFLAGS  = -g
LDFLAGS  =

.PHONY: all utils modulo1 modulo2 modulo3 modulo4 modulo5 run1 gdb1 clean info

all: utils modulo1 modulo2 modulo3 modulo4 modulo5

utils: $(UTILS_O)

# Compilar utils.s primero (objeto compartido)
$(UTILS_O): $(UTILS) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

# Compilar cada módulo enlazándolo con utils.o
$(M1_O): $(M1_S) $(UTILS_O) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M2_O): $(M2_S) $(UTILS_O) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M3_O): $(M3_S) $(UTILS_O) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M4_O): $(M4_S) $(UTILS_O) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M5_O): $(M5_S) $(UTILS_O) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

# Enlazar cada módulo con utils.o
$(M1_BIN): $(M1_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

$(M2_BIN): $(M2_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

$(M3_BIN): $(M3_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

$(M4_BIN): $(M4_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

$(M5_BIN): $(M5_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

# Targets individuales
modulo1: $(M1_BIN)
modulo2: $(M2_BIN)
modulo3: $(M3_BIN)
modulo4: $(M4_BIN)
modulo5: $(M5_BIN)

# Ejecución con QEMU (en PC) o nativa (en Pi)
run1: $(M1_BIN)
	$(QEMU) $<
run2: $(M2_BIN)
	$(QEMU) $<
run3: $(M3_BIN)
	$(QEMU) $<
run4: $(M4_BIN)
	$(QEMU) $<
run5: $(M5_BIN)
	$(QEMU) $<

# Depuración con GDB (servidor QEMU en :1234)
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
	@echo "Módulos:"
	@echo "  M1    = $(M1_BIN)  (media ponderada)"
	@echo "  M2    = $(M2_BIN)  (varianza y desv. estándar)"
	@echo "  M3    = $(M3_BIN)  (detección de anomalías)"
	@echo "  M4    = $(M4_BIN)  (predicción lineal)"
	@echo "  M5    = $(M5_BIN)  (tendencia acumulada)"
