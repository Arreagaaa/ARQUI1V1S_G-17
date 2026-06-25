AS      = aarch64-linux-gnu-as
LD      = aarch64-linux-gnu-ld
QEMU    ?= qemu-aarch64

BUILD   = ../build/fase2

.PHONY: all live_engine clean

all: live_engine

# --- Motor en vivo ---
LIVE_DIR   = live_engine
LIVE_S     = $(LIVE_DIR)/live_engine.s
LIVE_O     = $(BUILD)/live_engine.o
LIVE_BIN   = $(BUILD)/live_engine

$(LIVE_O): $(LIVE_S) | $(BUILD)
	$(AS) -g -o $@ $<

$(LIVE_BIN): $(LIVE_O) | $(BUILD)
	$(LD) -o $@ $^

live_engine: $(LIVE_BIN)
	@echo "==> live_engine compilado: $(LIVE_BIN)"

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
