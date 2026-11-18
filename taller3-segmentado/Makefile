# =============================================================================
# Makefile - Taller del procesador monociclo
#
#   make basicos    compila y corre el testbench del sumador y los muxes
#   make imm        compila y corre el testbench del generador de inmediatos
#   make dmem       compila y corre el testbench de la memoria de datos
#   make control    compila y corre el testbench de la unidad de control
#   make cpu        ensambla los programas y corre el procesador entero
#   make forwarding compila y corre el testbench de la unidad de forwarding      (Taller 3)
#   make hazard     compila y corre el testbench de la unidad de riesgos         (Taller 3)
#   make seg        corre el procesador segmentado contra la referencia ISA      (Taller 3)
#   make ciclos     mide los ciclos de cada programa en el segmentado            (Taller 3)
#   make modelo     modelo en Python: referencia + pipeline + defectos inyectados (Taller 3)
#   make all        todos, en orden (es lo que corre "make" a secas)
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
PROGRAMAS_SEG := prog/seg_fwd.hex prog/seg_carga.hex prog/seg_saltos.hex

# Taller 3: los modulos nuevos del segmentado
SEG := rtl/pipe_reg.sv \
       rtl/forwarding_unit.sv \
       rtl/hazard_unit.sv \
       rtl/riscv_segmentado.sv

.PHONY: all basicos imm dmem control cpu forwarding hazard seg ciclos modelo wave clean
.DEFAULT_GOAL := all

all: basicos imm dmem control cpu forwarding hazard seg

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

# --- Taller 3: la unidad de forwarding -----------------------------------
forwarding: build/tb_forwarding.out
	@echo ""
	@echo "=== tb_forwarding ==="
	@$(VVP) $<

build/tb_forwarding.out: rtl/forwarding_unit.sv tb/tb_forwarding.sv | build
	$(IVERILOG) $(IFLAGS) -s tb_forwarding -o $@ $^

# --- Taller 3: la unidad de deteccion de riesgos -------------------------
hazard: build/tb_hazard.out
	@echo ""
	@echo "=== tb_hazard ==="
	@$(VVP) $<

build/tb_hazard.out: $(PKG) rtl/hazard_unit.sv tb/tb_hazard.sv | build
	$(IVERILOG) $(IFLAGS) -s tb_hazard -o $@ $^

# --- Taller 3: el procesador segmentado entero ---------------------------
seg: build/tb_segmentado.out $(PROGRAMAS) $(PROGRAMAS_SEG)
	@echo ""
	@echo "=== tb_segmentado ==="
	@$(VVP) build/tb_segmentado.out

build/tb_segmentado.out: $(PKG) $(DADOS) rtl/adder.sv rtl/mux2.sv rtl/mux4.sv rtl/imm_gen.sv \
					rtl/data_memory.sv rtl/control_unit.sv $(SEG) tb/tb_segmentado.sv | build
	$(IVERILOG) $(IFLAGS) -s tb_segmentado -o $@ $^

# --- Taller 3: cuantos ciclos tarda cada programa ------------------------
ciclos: build/tb_ciclos.out $(PROGRAMAS) $(PROGRAMAS_SEG)
	@echo ""
	@echo "=== tb_ciclos ==="
	@$(VVP) build/tb_ciclos.out

build/tb_ciclos.out: $(PKG) $(DADOS) rtl/adder.sv rtl/mux2.sv rtl/mux4.sv rtl/imm_gen.sv \
					rtl/data_memory.sv rtl/control_unit.sv $(SEG) tb/tb_ciclos.sv | build
	$(IVERILOG) $(IFLAGS) -s tb_ciclos -o $@ $^

# --- Taller 3: el modelo en Python (no necesita simulador) ---------------
modelo: $(PROGRAMAS) $(PROGRAMAS_SEG)
	@for p in $(PROGRAMAS) $(PROGRAMAS_SEG); do echo "== $$p"; $(PYTHON) tools/modelo.py $$p || exit 1; done
	$(PYTHON) tools/mutantes.py

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
	rm -rf build $(PROGRAMAS) $(PROGRAMAS_SEG)
