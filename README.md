# Taller 2 — Procesador RV32I monociclo

Taller de la asignatura **Arquitectura de Computadores**, Universidad Tecnológica de Pereira.

- **Profesor:** Daniel Alejandro Serna Olarte
- **Autores:**
  - Jhon Felipe Loaiza Restrepo
  - Carlos Abiecer Velez Cardona

El enunciado completo está en [`taller.md`](taller.md) (y en [`taller.pdf`](taller.pdf)).

## Estructura

```text
rtl/     módulos del procesador en SystemVerilog
tb/      testbenches auto-comprobables
prog/    programas de prueba en ensamblador RISC-V
tools/   ensamblador (rvasm.py)
```

## Requisitos

- [Icarus Verilog](https://steveicarus.github.io/iverilog/) (`iverilog` y `vvp`)
- Python 3
- GTKWave (opcional, solo para ver ondas)

## Cómo correrlo

```bash
make            # corre todos los testbenches
make basicos    # sumador y multiplexores
make imm        # generador de inmediatos
make dmem       # memoria de datos
make control    # unidad de control
make cpu        # procesador completo
make clean      # borra build/ y los .hex generados
```

Cada testbench termina con `PASS` o `FAIL`.
