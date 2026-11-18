#!/usr/bin/env python3
"""para_eda.py - Prepara los archivos para pegarlos en EDA Playground.

EDA Playground no corre Makefile ni Python y trabaja con una sola carpeta plana,
asi que este script genera en eda/ :
  design.sv          todo el RTL concatenado en el orden correcto (paquete primero)
  tb_*.sv            los testbenches con las rutas "prog/x.hex" -> "x.hex" y el .vcd -> dump.vcd
  *.hex              los programas ya ensamblados

Uso (desde la raiz del repo):   python3 tools/para_eda.py
"""
import os, re, subprocess, sys

ORDEN = ["riscv_pkg", "pc", "alu", "register_file", "instruction_memory", "adder", "mux2", "mux4",
         "imm_gen", "data_memory", "control_unit", "pipe_reg", "forwarding_unit", "hazard_unit",
         "riscv_segmentado"]
PROGS = ["humo", "completo", "bytes", "seg_fwd", "seg_carga", "seg_saltos"]
TBS = ["tb_forwarding", "tb_hazard", "tb_segmentado"]

os.makedirs("eda", exist_ok=True)
with open("eda/design.sv", "w") as d:
    for m in ORDEN:
        d.write(f"// ===== {m}.sv =====\n")
        d.write(open(f"rtl/{m}.sv").read().rstrip() + "\n\n")
for t in TBS:
    s = open(f"tb/{t}.sv").read()
    s = s.replace('"prog/', '"').replace('"build/tb_segmentado.vcd"', '"dump.vcd"')
    open(f"eda/{t}.sv", "w").write(s)
for p in PROGS:
    subprocess.run([sys.executable, "tools/rvasm.py", f"prog/{p}.s", "-o", f"eda/{p}.hex"],
                   capture_output=True, check=True)
print("listo: eda/design.sv, eda/tb_*.sv y", len(PROGS), "archivos .hex")
