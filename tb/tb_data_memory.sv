// =============================================================================
// tb_data_memory.sv - Banco de pruebas de la memoria de datos
//
// Se entrega hecho. No hay que tocarlo: hay que hacer que pase.
//
// La memoria se instancia con DEPTH = 16, asi que el indice de fila tiene
// cuatro bits: addr[5:2].
//
// Dieciseis comprobaciones, en cuatro grupos. Cada uno caza un error concreto:
//
//   1. Palabras. sw en 0 y en 4, mirando el ARREGLO por dentro con dut.mem[i].
//      Si indexas con addr, la palabra del byte 4 cae en la fila 4 y no en
//      la 1. Por eso tu arreglo se tiene que llamar mem.
//   2. Un sb en medio de una palabra. Despues se relee la palabra entera: los
//      otros tres bytes tienen que seguir ahi. El dato lleva basura en los
//      24 bits de arriba, asi que escribir wd entero tambien se nota.
//   3. Las cinco lecturas, sobre la palabra del grupo 2. El byte escrito es
//      0x80, negativo: lb y lbu NO pueden dar lo mismo. Igual lh y lhu.
//   4. sh en las dos mitades de una palabra, y una escritura con we = 0 que
//      no debe hacer nada.
//
// El estado de la memoria se arrastra de un grupo al siguiente: si falla el
// grupo 1, lo que falle despues puede ser consecuencia. Arregla de arriba
// abajo.
// =============================================================================
`timescale 1ns/1ps

module tb_data_memory;
    import riscv_pkg::*;

    logic        clk;
    logic        we;
    logic [2:0]  funct3;
    logic [31:0] addr, wd, rd;

    int pruebas;
    int errores;

    data_memory #(.DEPTH (16)) dut (
        .clk    (clk),
        .we     (we),
        .funct3 (funct3),
        .addr   (addr),
        .wd     (wd),
        .rd     (rd)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Una escritura: se preparan las entradas, pasa un flanco y se baja we
    task automatic escribe(input logic [2:0]  f3,
                           input logic [31:0] a,
                           input logic [31:0] dato,
                           input logic        habilita);
        @(negedge clk);
        we = habilita;  funct3 = f3;  addr = a;  wd = dato;
        @(negedge clk);
        we = 1'b0;
    endtask

    task automatic comprueba(input string       nombre,
                             input logic [31:0] obtenido,
                             input logic [31:0] esperado);
        pruebas = pruebas + 1;
        if (obtenido !== esperado) begin
            errores = errores + 1;
            $display("  FALLO %-26s obtenido=%h  esperado=%h", nombre, obtenido, esperado);
        end
    endtask

    // Una lectura es combinacional: basta con esperar a que se asiente
    task automatic lee(input string       nombre,
                       input logic [2:0]  f3,
                       input logic [31:0] a,
                       input logic [31:0] esperado);
        funct3 = f3;  addr = a;
        #1;
        comprueba(nombre, rd, esperado);
    endtask

    initial begin
        $dumpfile("build/tb_data_memory.vcd");
        $dumpvars(0, tb_data_memory);

        pruebas = 0;
        errores = 0;
        we = 1'b0;  funct3 = F3_WORD;  addr = 32'd0;  wd = 32'd0;

        // --- 1. Palabras: la direccion es de byte, la fila es de palabra ---
        escribe(F3_WORD, 32'h0, 32'h1122_3344, 1'b1);       // sw en el byte 0
        escribe(F3_WORD, 32'h4, 32'hcafe_f00d, 1'b1);       // sw en el byte 4
        comprueba("sw 0x0 cae en la fila 0",  dut.mem[0], 32'h1122_3344);
        comprueba("sw 0x4 cae en la fila 1",  dut.mem[1], 32'hcafe_f00d);
        lee("lw 0x0",  F3_WORD, 32'h0, 32'h1122_3344);
        lee("lw 0x4",  F3_WORD, 32'h4, 32'hcafe_f00d);

        // --- 2. sb en el byte 5 = fila 1, byte 1. Los vecinos no se tocan ---
        escribe(F3_BYTE, 32'h5, 32'hffff_ff80, 1'b1);       // solo vale el 0x80
        lee("sb 0x5 respeta vecinos", F3_WORD, 32'h4, 32'hcafe_800d);

        // --- 3. Las cinco lecturas sobre la fila 1 = 0xCAFE800D ---
        lee("lb  0x5 (0x80, negativo)", F3_BYTE,  32'h5, 32'hffff_ff80);
        lee("lbu 0x5 (0x80, sin signo)", F3_BYTEU, 32'h5, 32'h0000_0080);
        lee("lb  0x4 (0x0D, positivo)", F3_BYTE,  32'h4, 32'h0000_000d);
        lee("lbu 0x7 (0xCA)",           F3_BYTEU, 32'h7, 32'h0000_00ca);
        lee("lh  0x4 (0x800D)",         F3_HALF,  32'h4, 32'hffff_800d);
        lee("lhu 0x4 (0x800D)",         F3_HALFU, 32'h4, 32'h0000_800d);
        lee("lh  0x6 (0xCAFE)",         F3_HALF,  32'h6, 32'hffff_cafe);
        lee("lhu 0x6 (0xCAFE)",         F3_HALFU, 32'h6, 32'h0000_cafe);

        // --- 4. sh en las dos mitades de la fila 0 = 0x11223344 ---
        escribe(F3_HALF, 32'h2, 32'habcd_1234, 1'b1);       // mitad alta
        lee("sh 0x2 (mitad alta)",  F3_WORD, 32'h0, 32'h1234_3344);
        escribe(F3_HALF, 32'h0, 32'habcd_5678, 1'b1);       // mitad baja
        lee("sh 0x0 (mitad baja)",  F3_WORD, 32'h0, 32'h1234_5678);

        // Con we = 0 no se escribe nada, aunque haya flanco y dato
        escribe(F3_WORD, 32'h0, 32'hdead_beef, 1'b0);
        lee("we = 0 no escribe",    F3_WORD, 32'h0, 32'h1234_5678);

        $display("--------------------------------------------------");
        $display("pruebas: %0d    errores: %0d", pruebas, errores);
        if (errores == 0) $display("tb_data_memory: PASS");
        else              $display("tb_data_memory: FAIL");
        $display("--------------------------------------------------");

        $finish;
    end

endmodule
