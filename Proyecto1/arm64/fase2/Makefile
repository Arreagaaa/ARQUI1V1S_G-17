ifeq ($(shell which aarch64-linux-gnu-as 2>/dev/null),)
AS      = as
LD      = ld
else
AS      = aarch64-linux-gnu-as
LD      = aarch64-linux-gnu-ld
endif
QEMU    ?= qemu-aarch64
ASFLAGS = -g
LDFLAGS =

BUILD   = build

.PHONY: all live_engine rmse varianza prediccion integrals derivada clean

all: live_engine rmse varianza prediccion integrals derivada

LIVE_DIR = live_engine
LIVE_S   = $(LIVE_DIR)/live_engine.s
LIVE_O   = $(BUILD)/live_engine.o
LIVE_BIN = $(BUILD)/live_engine

UTILS_S = ../utils/utils.s
UTILS_O = ../build/utils.o

$(UTILS_O): $(UTILS_S)
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -o $@ $<

$(LIVE_O): $(LIVE_S) | $(BUILD)
	$(AS) $(ASFLAGS) -I $(LIVE_DIR) -o $@ $<

$(LIVE_BIN): $(LIVE_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

live_engine: $(LIVE_BIN)
	@echo "==> live_engine compilado: $(LIVE_BIN)"

RMSE_DIR   = analyzer/modules/modulo_1_rmse
RMSE_S     = $(RMSE_DIR)/rmse.s
RMSE_O     = $(BUILD)/rmse.o
RMSE_BIN   = $(BUILD)/rmse

$(RMSE_O): $(RMSE_S) | $(BUILD)
	$(AS) $(ASFLAGS) -I $(LIVE_DIR) -I ../utils -o $@ $<

$(RMSE_BIN): $(RMSE_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

rmse: $(RMSE_BIN) 
	@echo "==> rmse compilado: $(RMSE_BIN)"

VAR_DIR   = analyzer/modules/modulo_2_regresion
VAR_S     = $(VAR_DIR)/varianza.s
VAR_O     = $(BUILD)/varianza.o
VAR_BIN   = $(BUILD)/varianza

$(VAR_O): $(VAR_S) | $(BUILD)
	$(AS) $(ASFLAGS) -I $(LIVE_DIR) -I ../utils -o $@ $<

$(VAR_BIN): $(VAR_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

varianza: $(VAR_BIN)
	@echo "==> varianza compilado: $(VAR_BIN)"

PRED_DIR   = analyzer/modules/modulo_3_prediccion
PRED_S     = $(PRED_DIR)/predicciones.s
PRED_O     = $(BUILD)/prediccion.o
PRED_BIN   = $(BUILD)/prediccion

$(PRED_O): $(PRED_S) | $(BUILD)
	$(AS) $(ASFLAGS) -I $(LIVE_DIR) -I ../utils -o $@ $<

$(PRED_BIN): $(PRED_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

prediccion: $(PRED_BIN)
	@echo "==> prediccion compilado: $(PRED_BIN)"

INT_DIR   = analyzer/modules/modulo_4_integral_error
INT_S     = $(INT_DIR)/integrals.s
INT_O     = $(BUILD)/integrals.o
INT_BIN   = $(BUILD)/integrals

$(INT_O): $(INT_S) | $(BUILD)
	$(AS) $(ASFLAGS) -I $(LIVE_DIR) -I ../utils -o $@ $<

$(INT_BIN): $(INT_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

integrals: $(INT_BIN)
	@echo "==> integrals compilado: $(INT_BIN)"

DER_DIR   = analyzer/modules/modulo_5_derivada_local
DER_S     = $(DER_DIR)/derivada.s
DER_O     = $(BUILD)/derivada.o
DER_BIN   = $(BUILD)/derivada

$(DER_O): $(DER_S) | $(BUILD)
	$(AS) $(ASFLAGS) -I $(LIVE_DIR) -I ../utils -o $@ $<

$(DER_BIN): $(DER_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

derivada: $(DER_BIN)
	@echo "==> derivada compilado: $(DER_BIN)"

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
