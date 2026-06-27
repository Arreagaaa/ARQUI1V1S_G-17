AS      = aarch64-linux-gnu-as
LD      = aarch64-linux-gnu-ld
QEMU    ?= qemu-aarch64
ASFLAGS = -g
LDFLAGS =

BUILD   = build

.PHONY: all live_engine rmse clean

all: live_engine rmse

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

REGRESION_DIR = analyzer/modules/modulo_2_regresion
REGRESION_S   = $(REGRESION_DIR)/regresion.s
REGRESION_O   = $(BUILD)/regresion.o
REGRESION_BIN = $(BUILD)/regresion

$(REGRESION_O): $(REGRESION_S) | $(BUILD)
	$(AS) $(ASFLAGS) -I $(LIVE_DIR) -I ../utils -o $@ $<

$(REGRESION_BIN): $(REGRESION_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

regresion: $(REGRESION_BIN)
	@echo "==> regresion compilado: $(REGRESION_BIN)"

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
