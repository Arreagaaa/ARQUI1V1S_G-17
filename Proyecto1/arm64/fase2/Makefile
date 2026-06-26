AS      = aarch64-linux-gnu-as
LD      = aarch64-linux-gnu-ld
QEMU    ?= qemu-aarch64
ASFLAGS = -g
LDFLAGS =

BUILD   = build
UTILS_S = ../utils/utils.s
UTILS_O = ../build/utils.o

.PHONY: all utils live_engine clean

all: utils live_engine

utils: $(UTILS_O)

$(UTILS_O): $(UTILS_S)
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -o $@ $<

LIVE_DIR   = live_engine
LIVE_S     = $(LIVE_DIR)/live_engine.s
LIVE_O     = $(BUILD)/live_engine.o
LIVE_BIN   = $(BUILD)/live_engine

$(LIVE_O): $(LIVE_S) | $(BUILD)
	$(AS) $(ASFLAGS) -I $(LIVE_DIR) -o $@ $<

$(LIVE_BIN): $(LIVE_O)
	$(LD) $(LDFLAGS) -o $@ $^

live_engine: $(LIVE_BIN)
	@echo "==> live_engine compilado: $(LIVE_BIN)"

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
