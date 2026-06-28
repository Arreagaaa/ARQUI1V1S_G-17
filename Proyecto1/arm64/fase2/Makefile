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

.PHONY: all live_engine rmse varianza prediccion clean

all: live_engine rmse varianza prediccion

LIVE_DIR = live_engine
LIVE_S   = $(LIVE_DIR)/live_engine.s
LIVE_O   = $(BUILD)/live_engine.o
LIVE_BIN = $(BUILD)/live_engine

$(LIVE_O): $(LIVE_S) | $(BUILD)
	$(AS) $(ASFLAGS) -I $(LIVE_DIR) -o $@ $<

$(LIVE_BIN): $(LIVE_O)
	$(LD) $(LDFLAGS) -o $@ $^

live_engine: $(LIVE_BIN)
	@echo "==> live_engine compilado: $(LIVE_BIN)"

UTILS_S = ../utils/utils.s
UTILS_O = ../build/utils.o

$(UTILS_O): $(UTILS_S)
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -o $@ $<

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
	$(AS) $(ASFLAGS) -I $(LIVE_DIR) -I ../utils -I $(VAR_DIR) -o $@ $<

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


$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
