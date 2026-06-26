AS      = aarch64-linux-gnu-as
LD      = aarch64-linux-gnu-ld
QEMU    ?= qemu-aarch64
GDB     ?= gdb-multiarch

BUILD    = build
UTILS_S  = ../utils/utils.s
UTILS_O  = ../build/utils.o

ASFLAGS  = -g
LDFLAGS  =

M1_DIR   = modules/modulo_1_media
M1_S     = $(M1_DIR)/media.s
M1_O     = $(BUILD)/modulo_1_media.o
M1_BIN   = $(BUILD)/modulo_1_media

M4_DIR   = modules/modulo_4_prediccion
M4_S     = $(M4_DIR)/predicciones.s
M4_O     = $(BUILD)/modulo_4_prediccion.o
M4_BIN   = $(BUILD)/modulo_4_prediccion

M2_DIR   = modules/modulo_2_varianza
M2_S     = $(M2_DIR)/varianza.s
M2_O     = $(BUILD)/modulo_2_varianza.o
M2_BIN   = $(BUILD)/modulo_2_varianza

M3_DIR   = modules/modulo_3_anomalias
M3_S     = $(M3_DIR)/anomalias.s
M3_O     = $(BUILD)/modulo_3_anomalias.o
M3_BIN   = $(BUILD)/modulo_3_anomalias

M5_DIR   = modules/modulo_5_tendencia
M5_S     = $(M5_DIR)/tendencia.s
M5_O     = $(BUILD)/modulo_5_tendencia.o
M5_BIN   = $(BUILD)/modulo_5_tendencia

.PHONY: all utils modulo1 modulo2 modulo3 modulo4 modulo5 \
        run1 run2 run3 run4 run5 runall gdb1 gdb2 gdb3 gdb4 gdb5 clean info status

all: utils modulo1 modulo2 modulo3 modulo4 modulo5
	@echo
	@echo "==> Listos: los 5 modulos ARM64"

utils: $(UTILS_O)

$(UTILS_O): $(UTILS_S)
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -o $@ $<

$(M1_O): $(M1_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M1_BIN): $(M1_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

modulo1: $(M1_BIN)
	@echo "==> modulo_1_media compilado: $(M1_BIN)"

$(M4_O): $(M4_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M4_BIN): $(M4_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

modulo4: $(M4_BIN)
	@echo "==> modulo_4_prediccion compilado: $(M4_BIN)"

$(M2_O): $(M2_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M2_BIN): $(M2_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

modulo2: $(M2_BIN)
	@echo "==> modulo_2_varianza compilado: $(M2_BIN)"

$(M3_O): $(M3_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M3_BIN): $(M3_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

modulo3: $(M3_BIN)
	@echo "==> modulo_3_anomalias compilado: $(M3_BIN)"

$(M5_O): $(M5_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(M5_BIN): $(M5_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

modulo5: $(M5_BIN)
	@echo "==> modulo_5_tendencia compilado: $(M5_BIN)"

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
	@echo "=== Los 5 modulos ejecutados ==="

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
	@echo "Modulos (los 5 listos):"
	@echo "  M1    = $(M1_BIN)  (media ponderada)      OK"
	@echo "  M2    = $(M2_BIN)  (varianza)              OK"
	@echo "  M3    = $(M3_BIN)  (anomalias)             OK"
	@echo "  M4    = $(M4_BIN)  (prediccion)            OK"
	@echo "  M5    = $(M5_BIN)  (tendencia)             OK"

status:
	@echo "=== Estado de los 5 modulos ARM64 ==="
	@echo
	@if [ -f "$(M1_S)" ]; then echo "OK  M1  media.s            (Integrante 1)"; else echo "XX  M1  media.s"; fi
	@if [ -f "$(M2_S)" ]; then echo "OK  M2  varianza.s         (Integrante 2)"; else echo "--  M2  varianza.s         (Integrante 2) -- PENDIENTE"; fi
	@if [ -f "$(M3_S)" ]; then echo "OK  M3  anomalias.s        (Integrante 3)"; else echo "--  M3  anomalias.s        (Integrante 3) -- PENDIENTE"; fi
	@if [ -f "$(M4_S)" ]; then echo "OK  M4  predicciones.s     (Integrante 4)"; else echo "XX  M4  predicciones.s"; fi
	@if [ -f "$(M5_S)" ]; then echo "OK  M5  tendencia.s        (Integrante 5)"; else echo "--  M5  tendencia.s        (Integrante 5) -- PENDIENTE"; fi
