# Root Makefile — compila Fase 1 y Fase 2
.PHONY: all fase1 fase2 clean

all: fase1 fase2

fase1:
	$(MAKE) -C fase1

fase2:
	$(MAKE) -C fase2

clean:
	$(MAKE) -C fase1 clean
	$(MAKE) -C fase2 clean

.PHONY: runall
runall:
	$(MAKE) -C fase1 runall
