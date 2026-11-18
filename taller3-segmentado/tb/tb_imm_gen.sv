// =============================================================================
// tb_imm_gen.sv - Banco de pruebas del generador de inmediatos
//
// Se entrega hecho. No hay que tocarlo: hay que hacer que pase.
//
// Diez vectores, dos por formato: uno positivo y uno negativo. Los negativos
// son los que importan, porque un error en la extension de signo solo se ve
// con el bit 31 a uno.
//
// Los diez hexadecimales estan verificados con
//     python3 tools/rvasm.py --check 0xHEX "asm"
// Nadie escribe un hexadecimal a mano.
//
// La segunda tabla pasa la MISMA instruccion por los ocho valores de imm_src.
// No comprueba nada: esta para que mires la salida y veas que los mismos 32
// bits dan cuatro inmediatos distintos segun el formato con que se lean.
// =============================================================================
`timescale 1ns/1ps

module tb_imm_gen;
    import riscv_pkg::*;

    logic [31:0] instr;
    logic [2:0]  imm_src;
    logic [31:0] imm_ext;

    int pruebas;
    int errores;

    imm_gen dut (
        .instr   (instr),
        .imm_src (imm_src),
        .imm_ext (imm_ext)
    );

    task automatic caso(input logic [31:0] i,
                        input logic [2:0]  src,
                        input logic [31:0] esperado,
                        input string       asm);
        instr = i;  imm_src = src;
        #1;
        pruebas = pruebas + 1;
        if (imm_ext !== esperado) begin
            errores = errores + 1;
            $display("  FALLO %-22s instr=%h  imm_ext=%h  esperado=%h  (%0d en vez de %0d)",
                     asm, i, imm_ext, esperado, $signed(imm_ext), $signed(esperado));
        end
    endtask

    initial begin
        $dumpfile("build/tb_imm_gen.vcd");
        $dumpvars(0, tb_imm_gen);

        pruebas = 0;
        errores = 0;

        caso(32'hffb00093, IMM_I, 32'hfffffffb, "addi x1, x0, -5");
        caso(32'h7ff00113, IMM_I, 32'h000007ff, "addi x2, x0, 2047");

        caso(32'h00312423, IMM_S, 32'h00000008, "sw x3, 8(x2)");
        caso(32'hfe311a23, IMM_S, 32'hfffffff4, "sh x3, -12(x2)");

        caso(32'hfe208ce3, IMM_B, 32'hfffffff8, "beq x1, x2, -8");
        caso(32'h7e209e63, IMM_B, 32'h000007fc, "bne x1, x2, 2044");

        caso(32'h010000ef, IMM_J, 32'h00000010, "jal x1, 16");
        caso(32'h801ff0ef, IMM_J, 32'hfffff800, "jal x1, -2048");

        caso(32'h123452b7, IMM_U, 32'h12345000, "lui x5, 0x12345");
        caso(32'hfffff317, IMM_U, 32'hfffff000, "auipc x6, 0xFFFFF");

        $display("--------------------------------------------------");
        $display("pruebas: %0d    errores: %0d", pruebas, errores);
        if (errores == 0) $display("tb_imm_gen: PASS");
        else              $display("tb_imm_gen: FAIL");
        $display("--------------------------------------------------");

        $display("");
        $display("la misma instruccion beq x1, x2, -8 leida con cada imm_src");
        $display("imm_src   imm_ext    decimal");
        $display("-------   --------   -------");
        instr = 32'hfe208ce3;
        for (int s = 0; s < 8; s = s + 1) begin
            imm_src = s[2:0];
            #1;
            $display("  %b     %h   %0d", imm_src, imm_ext, $signed(imm_ext));
        end

        $finish;
    end

endmodule
