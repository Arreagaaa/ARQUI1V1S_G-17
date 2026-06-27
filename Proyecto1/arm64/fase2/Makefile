AS      = aarch64-linux-gnu-as
LD      = aarch64-linux-gnu-ld
QEMU    ?= qemu-aarch64
ASFLAGS = -g
LDFLAGS =

BUILD   = build
UTILS_S = ../utils/utils.s
UTILS_O = ../build/utils.o

.PHONY: all utils live_engine rmse clean

all: utils live_engine rmse

utils: $(UTILS_O)

$(UTILS_O): $(UTILS_S)
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -o $@ $<

LIVE_DIR     = live_engine
LIVE_S       = $(LIVE_DIR)/live_engine.s
LIVE_O       = $(BUILD)/live_engine.o
LIVE_ATOI_S  = $(LIVE_DIR)/utils/atoi.s
LIVE_ATOI_O  = $(BUILD)/atoi.o
LIVE_ARRAY_S = $(LIVE_DIR)/utils/array.s
LIVE_ARRAY_O = $(BUILD)/array.o
LIVE_BIN     = $(BUILD)/live_engine

$(LIVE_O): $(LIVE_S) | $(BUILD)
	$(AS) $(ASFLAGS) -I $(LIVE_DIR) -o $@ $<

$(LIVE_ATOI_O): $(LIVE_ATOI_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(LIVE_ARRAY_O): $(LIVE_ARRAY_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(LIVE_BIN): $(LIVE_O) $(LIVE_ATOI_O) $(LIVE_ARRAY_O)
	$(LD) $(LDFLAGS) -o $@ $^

live_engine: $(LIVE_BIN)
	@echo "==> live_engine compilado: $(LIVE_BIN)"

RMSE_DIR   = analyzer/modules/modulo_1_rmse
RMSE_S     = $(RMSE_DIR)/rmse.s
RMSE_O     = $(BUILD)/rmse.o
RMSE_BIN   = $(BUILD)/rmse

$(RMSE_O): $(RMSE_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

$(RMSE_BIN): $(RMSE_O) $(UTILS_O)
	$(LD) $(LDFLAGS) -o $@ $^

rmse: $(RMSE_BIN)
	@echo "==> rmse compilado: $(RMSE_BIN)"

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
