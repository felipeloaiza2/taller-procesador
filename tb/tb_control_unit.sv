// =============================================================================
// tb_control_unit.sv - Banco de pruebas de la unidad de control
//
// Se entrega hecho. No hay que tocarlo: hay que hacer que pase.
//
// Las dieciocho filas cubren las nueve familias del opcode, las tres parejas
// que comparten funct3 y los cuatro saltos con su bandera en los dos sentidos.
//
// Los valores esperados salen de la tabla de docs/cheat-sheet-datapath.html,
// cara 2. Si una fila falla, el mensaje imprime los diecisiete bits esperados y
// los obtenidos, uno debajo del otro, con la leyenda de los campos arriba.
// =============================================================================
`timescale 1ns/1ps

module tb_control_unit;
    import riscv_pkg::*;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic       funct7b5;
    logic       zero, less, less_u;

    logic       reg_write;
    logic [2:0] imm_src;
    logic       alu_src_a, alu_src_b;
    logic       mem_write;
    logic [1:0] result_src;
    logic       branch, jump, jalr;
    logic [3:0] alu_control;
    logic       pc_src;

    int pruebas;
    int errores;

    control_unit dut (
        .opcode      (opcode),
        .funct3      (funct3),
        .funct7b5    (funct7b5),
        .zero        (zero),
        .less        (less),
        .less_u      (less_u),
        .reg_write   (reg_write),
        .imm_src     (imm_src),
        .alu_src_a   (alu_src_a),
        .alu_src_b   (alu_src_b),
        .mem_write   (mem_write),
        .result_src  (result_src),
        .branch      (branch),
        .jump        (jump),
        .jalr        (jalr),
        .alu_control (alu_control),
        .pc_src      (pc_src)
    );

    // Las diecisiete salidas, empaquetadas en el orden de la leyenda:
    //
    //   rw  isrc  asa asb mw  rsrc  br jm jr  aluctrl  pcs
    //   16  15:13  12  11  10  9:8   7  6  5     4:1     0
    logic [16:0] obtenido;
    assign obtenido = {reg_write, imm_src, alu_src_a, alu_src_b, mem_write,
                       result_src, branch, jump, jalr, alu_control, pc_src};

    task automatic caso(input string       nombre,
                        input logic [6:0]  op,
                        input logic [2:0]  f3,
                        input logic        f7b5,
                        input logic        z,
                        input logic        l,
                        input logic        lu,
                        input logic [16:0] esperado);
        opcode = op;  funct3 = f3;  funct7b5 = f7b5;
        zero = z;  less = l;  less_u = lu;
        #1;
        pruebas = pruebas + 1;
        if (obtenido !== esperado) begin
            errores = errores + 1;
            $display("  FALLO %s", nombre);
            $display("        rw isrc asa asb mw rsrc br jm jr aluctrl pcs");
            $display("        esperado  %b", esperado);
            $display("        obtenido  %b", obtenido);
        end
    endtask

    initial begin
        $dumpfile("build/tb_control_unit.vcd");
        $dumpvars(0, tb_control_unit);

        pruebas = 0;
        errores = 0;

        // --- Tipo R y tipo I: la pareja que comparte funct3 ---
        caso("add",            OP_R,      3'b000, 1'b0,  1'b0, 1'b0, 1'b0,  17'b10000000000000000);
        caso("sub",            OP_R,      3'b000, 1'b1,  1'b0, 1'b0, 1'b0,  17'b10000000000010000);

        // La fila que detecta el bug del termino op[5]: addi x1, x0, -5 trae
        // instr[30] = 1, y si mod no mira el opcode se ejecuta como SUB.
        caso("addi negativo",  OP_IMM,    3'b000, 1'b1,  1'b0, 1'b0, 1'b0,  17'b10000100000000000);

        // La excepcion: srai SI es tipo I y SI necesita mod = 1.
        caso("srli",           OP_IMM,    3'b101, 1'b0,  1'b0, 1'b0, 1'b0,  17'b10000100000001010);
        caso("srai",           OP_IMM,    3'b101, 1'b1,  1'b0, 1'b0, 1'b0,  17'b10000100000011010);

        // --- Memoria ---
        caso("lw",             OP_LOAD,   3'b010, 1'b0,  1'b0, 1'b0, 1'b0,  17'b10000100100000000);

        // sw y sb dan el MISMO control. Lo unico que cambia es funct3, que no
        // es una senal de control: va directo de la instruccion a la memoria.
        caso("sw",             OP_STORE,  3'b010, 1'b0,  1'b0, 1'b0, 1'b0,  17'b00010110000000000);
        caso("sb",             OP_STORE,  3'b000, 1'b0,  1'b0, 1'b0, 1'b0,  17'b00010110000000000);

        // --- Los saltos condicionales, con la bandera en los dos sentidos ---
        caso("beq tomado",     OP_BRANCH, 3'b000, 1'b0,  1'b1, 1'b0, 1'b0,  17'b00100000010010001);
        caso("beq no tomado",  OP_BRANCH, 3'b000, 1'b0,  1'b0, 1'b0, 1'b0,  17'b00100000010010000);
        caso("bne tomado",     OP_BRANCH, 3'b001, 1'b0,  1'b0, 1'b0, 1'b0,  17'b00100000010010001);
        caso("blt tomado",     OP_BRANCH, 3'b100, 1'b0,  1'b0, 1'b1, 1'b0,  17'b00100000010010001);
        caso("blt no tomado",  OP_BRANCH, 3'b100, 1'b0,  1'b0, 1'b0, 1'b0,  17'b00100000010010000);
        caso("bltu tomado",    OP_BRANCH, 3'b110, 1'b0,  1'b0, 1'b0, 1'b1,  17'b00100000010010001);

        // --- Los saltos incondicionales y los dos de parte alta ---
        caso("jal",            OP_JAL,    3'b000, 1'b0,  1'b0, 1'b0, 1'b0,  17'b10110001001000001);
        caso("jalr",           OP_JALR,   3'b000, 1'b0,  1'b0, 1'b0, 1'b0,  17'b10000101001100001);
        caso("lui",            OP_LUI,    3'b000, 1'b0,  1'b0, 1'b0, 1'b0,  17'b11000001100000000);
        caso("auipc",          OP_AUIPC,  3'b000, 1'b0,  1'b0, 1'b0, 1'b0,  17'b11001100000000000);

        $display("--------------------------------------------------");
        $display("pruebas: %0d    errores: %0d", pruebas, errores);
        if (errores == 0) $display("tb_control_unit: PASS");
        else              $display("tb_control_unit: FAIL");
        $display("--------------------------------------------------");

        $finish;
    end

endmodule
