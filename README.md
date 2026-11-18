# Talleres de Arquitectura de Computadores — Procesador RV32I

Talleres de la asignatura **Arquitectura de Computadores**, Universidad Tecnológica de Pereira.

- **Profesor:** Daniel Alejandro Serna Olarte
- **Autores:**
  - Jhon Felipe Loaiza Restrepo
  - Carlos Abiecer Velez Cardona

| Taller | Qué es | Dónde está |
|---|---|---|
| Taller 2 | Procesador RV32I **monociclo** | raíz del repositorio |
| Taller 3 | Procesador RV32I **segmentado** (forwarding y detección de riesgos) | [`taller3-segmentado/`](taller3-segmentado) |

El enunciado de cada taller está en su `taller.md` ([Taller 2](taller.md), [Taller 3](taller3-segmentado/taller.md)).

## Estructura

```text
rtl/                módulos del monociclo en SystemVerilog   (Taller 2)
tb/                 testbenches auto-comprobables            (Taller 2)
prog/               programas de prueba en ensamblador       (Taller 2)
tools/              ensamblador (rvasm.py)                   (Taller 2)
taller3-segmentado/ el Taller 3 completo, con la misma estructura
                    más INFORME.txt
```

## Requisitos

- [Icarus Verilog](https://steveicarus.github.io/iverilog/) (`iverilog` y `vvp`)
- Python 3

## Cómo correrlo

### Taller 2

```bash
make            # corre todos los testbenches
make basicos    # sumador y multiplexores
make imm        # generador de inmediatos
make dmem       # memoria de datos
make control    # unidad de control
make cpu        # procesador completo
make clean      # borra build/ y los .hex generados
```

### Taller 3

```bash
cd taller3-segmentado
make            # corre todos los testbenches
make forwarding # unidad de forwarding
make hazard     # unidad de detección de riesgos
make seg        # procesador segmentado contra la referencia ISA
make ciclos     # ciclos que tarda cada programa
make modelo     # modelo en Python y defectos inyectados
make clean      # borra build/ y los .hex generados
```

Cada testbench termina con `PASS` o `FAIL`.
