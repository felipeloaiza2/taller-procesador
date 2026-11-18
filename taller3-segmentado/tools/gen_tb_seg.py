#!/usr/bin/env python3
"""gen_tb_seg.py - Regenera tb/tb_segmentado.sv con el estado esperado de la
referencia ISA (tools/modelo.py). Correr desde la raiz del repo tras cambiar un .s:
    python3 tools/gen_tb_seg.py
"""
import os, subprocess, sys
sys.path.insert(0, os.path.dirname(__file__))
import modelo

PROGS = ["humo", "completo", "bytes", "seg_fwd", "seg_carga", "seg_saltos"]
o = ['''// =============================================================================
// tb_segmentado.sv - El procesador segmentado contra la referencia ISA
//
// GENERADO con tools/gen_tb_seg.py (referencia: tools/modelo.py, una instruccion
// por paso). Para cada programa compara los 32 registros y las 16 primeras
// palabras de memoria con lo que deja la ejecucion instruccion a instruccion.
// Los tres primeros son los del Taller 2 (regresion: el segmentado tiene que
// hacer lo mismo que el monociclo); los otros tres son los dirigidos del Taller 3.
// =============================================================================
`timescale 1ns/1ps

module tb_segmentado;

    localparam int CICLOS = 300;

    logic clk, rst, en;
    int pruebas, errores;
''']
for p in PROGS:
    o.append(f'    riscv_segmentado #(.INIT_FILE("prog/{p}.hex")) cpu_{p} (.clk(clk), .rst(rst), .en(en));')
o.append('''
    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic comprobar(input string programa, input string nota,
                             input logic [31:0] obtenido, input logic [31:0] esperado);
        pruebas++;
        if (obtenido !== esperado) begin
            errores++;
            $display("  FALLO [%-9s] %-10s obtenido=0x%08h  esperado=0x%08h", programa, nota, obtenido, esperado);
        end
    endtask

    initial begin
        $dumpfile("build/tb_segmentado.vcd");
        $dumpvars(0, tb_segmentado);
        pruebas = 0; errores = 0;
        en = 1'b1; rst = 1'b1;
        repeat (2) @(posedge clk);
        rst = 1'b0;
        repeat (CICLOS) @(posedge clk);
        #1;
''')
for p in PROGS:
    h = f"prog/{p}.hex"
    subprocess.run([sys.executable, "tools/rvasm.py", f"prog/{p}.s", "-o", h], capture_output=True, check=True)
    x, m, _ = modelo.correr_isa(modelo.cargar(h))
    o.append(f"        // ---- {p} ----")
    for i in range(32): o.append(f'        comprobar("{p}", "x{i}", cpu_{p}.rf.regs[{i}], 32\'h{x[i]:08x});')
    for i in range(16): o.append(f'        comprobar("{p}", "mem[{i}]", cpu_{p}.dmem.mem[{i}], 32\'h{m[i]:08x});')
o.append('''
        $display("--------------------------------------------------");
        $display("pruebas: %0d    errores: %0d", pruebas, errores);
        if (errores == 0) $display("tb_segmentado: PASS");
        else              $display("tb_segmentado: FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule''')
open("tb/tb_segmentado.sv", "w").write("\n".join(o) + "\n")
print("tb/tb_segmentado.sv regenerado")


# ---------------------------------------------------------------------------
# tb_ciclos.sv: mide cuantos ciclos tarda cada programa en el segmentado
# ---------------------------------------------------------------------------
ESPERADO = {}
for p in PROGS:
    h = f"prog/{p}.hex"
    im = modelo.cargar(h)
    _, _, n = modelo.correr_isa(im)
    _, _, c, _ = modelo.correr_pipe(im)
    ESPERADO[p] = (n, c, im.index(0x00000063) * 4)

o = ['''// =============================================================================
// tb_ciclos.sv - Cuantos ciclos tarda cada programa en el segmentado
//
// GENERADO con tools/gen_tb_seg.py. Cuenta ciclos desde que se suelta el reset
// (el ciclo 1 es aquel en que se busca la instruccion de la direccion 0) hasta
// que el beq final del programa ("fin: beq x0, x0, fin") se retira.
//
// Ese beq esta en EX cuando pc_e vale la direccion de "fin" (en EX no puede
// haber instrucciones del camino equivocado: ya se vaciaron). Le faltan dos
// ciclos (MEM y WB) para retirarse, y por eso el total es ciclo_en_EX + 2.
//
// Compara contra lo que predice el modelo de Python y contra el monociclo
// (que tarda un ciclo por instruccion ejecutada).
// =============================================================================
`timescale 1ns/1ps

module tb_ciclos;

    logic clk, rst, en;
''']
for p in PROGS:
    o.append(f'    riscv_segmentado #(.INIT_FILE("prog/{p}.hex")) cpu_{p} (.clk(clk), .rst(rst), .en(en));')
    o.append(f'    int c_{p}, tot_{p};  bit hecho_{p};')
o.append('''
    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
''')
for p in PROGS: o.append(f'        c_{p} = 0; tot_{p} = 0; hecho_{p} = 1\'b0;')
o.append('''    end

    // Un contador por programa: cuenta el ciclo que acaba de terminar
    always @(posedge clk) begin
        if (!rst) begin''')
for p in PROGS:
    fin = ESPERADO[p][2]
    o.append(f'''            if (!hecho_{p}) begin
                c_{p} = c_{p} + 1;
                if (cpu_{p}.pc_e === 32'h{fin:08x}) begin hecho_{p} = 1'b1; tot_{p} = c_{p} + 2; end
            end''')
o.append('''        end
    end

    task automatic informar(input string nombre, input int mono, input int modelo_c, input int medido, input bit hecho);
        $display("  %-11s %9d %11d %9d    %s", nombre, mono, medido, modelo_c,
                 (!hecho) ? "NO TERMINO" : (medido == modelo_c) ? "coincide" : "DIFERENTE");
    endtask

    initial begin
        en = 1'b1; rst = 1'b1;
        repeat (2) @(posedge clk);
        #1 rst = 1'b0;
        repeat (300) @(posedge clk);
        #1;
        $display("--------------------------------------------------------");
        $display("  programa    monociclo  segmentado    modelo    estado");''')
for p in PROGS:
    n, c, _ = ESPERADO[p]
    o.append(f'        informar("{p}", {n}, {c}, tot_{p}, hecho_{p});')
o.append('''        $display("--------------------------------------------------------");
        $display("  monociclo = instrucciones ejecutadas (1 ciclo cada una)");
        $finish;
    end

endmodule''')
open("tb/tb_ciclos.sv", "w").write("\n".join(o) + "\n")
print("tb/tb_ciclos.sv generado:", {k: v[1] for k, v in ESPERADO.items()})
