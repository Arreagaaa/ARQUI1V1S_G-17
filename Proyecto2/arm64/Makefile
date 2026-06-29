ifeq ($(shell which aarch64-linux-gnu-as 2>/dev/null),)
AS      = as
LD      = ld
else
AS      = aarch64-linux-gnu-as
LD      = aarch64-linux-gnu-ld
endif
QEMU    ?= qemu-aarch64
ASFLAGS = -g

BUILD   = build
UTILS_S = utils/utils.s
UTILS_O = $(BUILD)/utils.o

.PHONY: all utils fase1 fase2 clean runall

all: utils fase1 fase2
	@echo "==> Todo compilado: utils + fase1 + fase2"

utils: $(UTILS_O)

$(UTILS_O): $(UTILS_S) | $(BUILD)
	$(AS) $(ASFLAGS) -o $@ $<

fase1: $(UTILS_O)
	$(MAKE) -C fase1

fase2: $(UTILS_O)
	$(MAKE) -C fase2

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
	$(MAKE) -C fase1 clean
	$(MAKE) -C fase2 clean

runall:
	$(MAKE) -C fase1 runall
