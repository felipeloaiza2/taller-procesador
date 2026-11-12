# =============================================================================
# Makefile - Taller del procesador monociclo
#
#   make basicos    compila y corre el testbench del sumador y los muxes
#   make imm        compila y corre el testbench del generador de inmediatos
#   make dmem       compila y corre el testbench de la memoria de datos
#   make control    compila y corre el testbench de la unidad de control
#   make cpu        ensambla los programas y corre el procesador entero
#   make all        los cinco, en orden (es lo que corre "make" a secas)
#   make wave TB=tb_cpu    abre las ondas de un testbench en GTKWave
#   make clean      borra build/ y los .hex generados
#
# Los .hex NO se escriben a mano ni se versionan: se ensamblan desde los .s con
# tools/rvasm.py. Esa es la regla del curso, y existe porque el material llego a
# tener instrucciones en hexadecimal que no hacian lo que decia su comentario.
# =============================================================================

IVERILOG := iverilog
VVP      := vvp
PYTHON   := python3
IFLAGS   := -g2012 -Wall -Wno-timescale

# El paquete va PRIMERO: define las constantes que todos los demas importan.
PKG := rtl/riscv_pkg.sv

# Los modulos que te dan
DADOS := rtl/pc.sv \
         rtl/alu.sv \
         rtl/register_file.sv \
         rtl/instruction_memory.sv

# Los modulos que escribes tu
TUYOS := rtl/adder.sv \
         rtl/mux2.sv \
         rtl/mux4.sv \
         rtl/imm_gen.sv \
         rtl/data_memory.sv \
         rtl/control_unit.sv \
         rtl/riscv_monociclo.sv

PROGRAMAS := prog/humo.hex prog/completo.hex prog/bytes.hex

.PHONY: all basicos imm dmem control cpu wave clean
.DEFAULT_GOAL := all

all: basicos imm dmem control cpu

# --- Fase 1: el sumador y los multiplexores ------------------------------
basicos: build/tb_basicos.out
	@echo ""
	@echo "=== tb_basicos ==="
	@$(VVP) $<

build/tb_basicos.out: rtl/adder.sv rtl/mux2.sv rtl/mux4.sv tb/tb_basicos.sv | build
	$(IVERILOG) $(IFLAGS) -s tb_basicos -o $@ $^

# --- Fase 1: el generador de inmediatos ----------------------------------
imm: build/tb_imm_gen.out
	@echo ""
	@echo "=== tb_imm_gen ==="
	@$(VVP) $<

build/tb_imm_gen.out: $(PKG) rtl/imm_gen.sv tb/tb_imm_gen.sv | build
	$(IVERILOG) $(IFLAGS) -s tb_imm_gen -o $@ $^

# --- Fase 1: la memoria de datos -----------------------------------------
dmem: build/tb_data_memory.out
	@echo ""
	@echo "=== tb_data_memory ==="
	@$(VVP) $<

build/tb_data_memory.out: $(PKG) rtl/data_memory.sv tb/tb_data_memory.sv | build
	$(IVERILOG) $(IFLAGS) -s tb_data_memory -o $@ $^

# --- Fase 1: la unidad de control ----------------------------------------
control: build/tb_control_unit.out
	@echo ""
	@echo "=== tb_control_unit ==="
	@$(VVP) $<

build/tb_control_unit.out: $(PKG) rtl/control_unit.sv tb/tb_control_unit.sv | build
	$(IVERILOG) $(IFLAGS) -s tb_control_unit -o $@ $^

# --- Fase 2: el procesador entero ----------------------------------------
cpu: build/tb_cpu.out $(PROGRAMAS)
	@echo ""
	@echo "=== tb_cpu ==="
	@$(VVP) build/tb_cpu.out

build/tb_cpu.out: $(PKG) $(DADOS) $(TUYOS) tb/tb_cpu.sv | build
	$(IVERILOG) $(IFLAGS) -s tb_cpu -o $@ $^

# --- Los programas se ensamblan, nunca se escriben a mano ----------------
prog/%.hex: prog/%.s tools/rvasm.py
	$(PYTHON) tools/rvasm.py $< -o $@

# --- Las ondas -----------------------------------------------------------
wave:
	@test -n "$(TB)" || (echo "uso: make wave TB=tb_cpu" && false)
	gtkwave build/$(TB).vcd &

build:
	@mkdir -p build

clean:
	rm -rf build $(PROGRAMAS)
