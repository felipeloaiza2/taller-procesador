// =============================================================================
// riscv_monociclo.sv - El procesador entero       >>> LO ESCRIBEN USTEDES <<<
//
// Aqui no se describe logica nueva: se CONECTAN las cajas que ya existen. Todo
// este archivo son declaraciones, cortes, instancias y cables, y lo escriben
// entero: solo la cabecera del modulo viene hecha.
//
// LOS NOMBRES DE LAS INSTANCIAS NO SON LIBRES. El testbench llega a tus
// registros y a tu memoria por referencia jerarquica, asi que necesita
// encontrarlos exactamente asi:
//
//     register_file  ->  rf          (el testbench lee dut.rf.regs[i])
//     data_memory    ->  dmem        (el testbench lee dut.dmem.mem[i])
//
// El resto los eligen ustedes, pero hay una convencion sugerida mas abajo.
//
// Conexion POR NOMBRE siempre: .puerto (senal). La conexion posicional esta
// prohibida en el curso, porque el dia que alguien anada un puerto todas las
// instancias quedan mal conectadas y ninguna herramienta se queja.
//
// -----------------------------------------------------------------------------
// LA LISTA DE CABLES
//
// Cada fila es una declaracion logic con ese ancho. Los campos de la
// instruccion (opcode ... rd) no salen de ninguna caja: son CORTES de instr,
// y se escriben con assign. No son logica.
//
// Senal         Ancho  Sale de                  Entra a
// ------------  -----  -----------------------  ----------------------------
// pc_actual       32   registro_pc.pc           imem.addr, sumadores, mux_a
// pc_plus4        32   add_pc4.y                mux_pc.d0, mux_res.d10
// pc_plus_imm     32   add_tgt.y                mux_jalr.d0
// pc_target       32   mux_jalr.y               mux_pc.d1
// pc_next         32   mux_pc.y                 registro_pc.pc_next
// instr           32   imem.instr               los campos de abajo, ig
// opcode           7   instr[6:0]               control.opcode
// funct3           3   instr[14:12]             control.funct3, dmem.funct3
// funct7b5         1   instr[30]                control.funct7b5
// rs1              5   instr[19:15]             rf.rs1
// rs2              5   instr[24:20]             rf.rs2
// rd               5   instr[11:7]              rf.rd
// rd1             32   rf.rd1                   mux_a.d0
// rd2             32   rf.rd2                   mux_b.d0, dmem.wd
// imm_ext         32   ig.imm_ext               mux_b.d1, add_tgt.b, mux_res.d11
// src_a           32   mux_a.y                  alu.src_a
// src_b           32   mux_b.y                  alu.src_b
// alu_result      32   alu.alu_result           dmem.addr, mux_res.d00, mux_jalr
// read_data       32   dmem.rd                  mux_res.d01
// result          32   mux_res.y                rf.wd3
// zero/less/less_u 1   alu                      control
// las de control        control                 cada caja
//
// Las senales de control, con sus anchos, son los puertos de salida de
// control_unit: copialas de ahi.
// -----------------------------------------------------------------------------
//
// Las CATORCE instancias, en el orden en que conviene escribirlas:
//
//   pc  add_pc4  imem  control  rf  ig  mux_a  mux_b  alu_i  dmem
//   mux_res  add_tgt  mux_jalr  mux_pc
//
// Las catorce son suyas. Pistas de las que suelen salir mal:
//   - imem y dmem llevan parametros: .DEPTH(IMEM_DEPTH) y .INIT_FILE(INIT_FILE)
//     en imem, .DEPTH(DMEM_DEPTH) en dmem.
//   - mux_jalr elige entre pc_plus_imm y {alu_result[31:1], 1'b0}: jalr pone
//     a cero el bit 0 del destino.
//   - El sumador de PC + 4 recibe la constante 32'd4 en su entrada b.
// =============================================================================
module riscv_monociclo #(
    parameter int IMEM_DEPTH = 256,
    parameter int DMEM_DEPTH = 256,
    parameter     INIT_FILE  = ""
)(
    input logic clk,
    input logic rst,
    input logic en
);

    import riscv_pkg::*;

    // -------------------------------------------------------------------------
    // Cables del camino de datos
    // -------------------------------------------------------------------------
    logic [31:0] pc_actual;
    logic [31:0] pc_plus4;
    logic [31:0] pc_plus_imm;
    logic [31:0] pc_target;
    logic [31:0] pc_next;
    logic [31:0] instr;
    logic [31:0] rd1, rd2;
    logic [31:0] imm_ext;
    logic [31:0] src_a, src_b;
    logic [31:0] alu_result;
    logic [31:0] read_data;
    logic [31:0] result;

    // -------------------------------------------------------------------------
    // Campos de la instruccion: son cortes de instr, no logica
    // -------------------------------------------------------------------------
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic       funct7b5;
    logic [4:0] rs1, rs2, rd;

    assign opcode   = instr[6:0];
    assign rd       = instr[11:7];
    assign funct3   = instr[14:12];
    assign rs1      = instr[19:15];
    assign rs2      = instr[24:20];
    assign funct7b5 = instr[30];

    // -------------------------------------------------------------------------
    // Senales de control (salen de control_unit) y banderas (salen de la ALU)
    // -------------------------------------------------------------------------
    logic       reg_write;
    logic [2:0] imm_src;
    logic       alu_src_a;
    logic       alu_src_b;
    logic       mem_write;
    logic [1:0] result_src;
    logic       branch;
    logic       jump;
    logic       jalr;
    logic [3:0] alu_control;
    logic       pc_src;

    logic       zero, less, less_u;

    // -------------------------------------------------------------------------
    // Las catorce instancias
    // -------------------------------------------------------------------------

    // 1. Contador de programa
    pc registro_pc (
        .clk     (clk),
        .rst     (rst),
        .en      (en),
        .pc_next (pc_next),
        .pc      (pc_actual)
    );

    // 2. Sumador del PC + 4
    adder add_pc4 (
        .a (pc_actual),
        .b (32'd4),
        .y (pc_plus4)
    );

    // 3. Memoria de instrucciones
    instruction_memory #(
        .DEPTH     (IMEM_DEPTH),
        .INIT_FILE (INIT_FILE)
    ) imem (
        .addr  (pc_actual),
        .instr (instr)
    );

    // 4. Unidad de control
    control_unit control (
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

    // 5. Banco de registros (el testbench lo busca como "rf")
    register_file rf (
        .clk (clk),
        .we  (reg_write),
        .rs1 (rs1),
        .rs2 (rs2),
        .rd  (rd),
        .wd3 (result),
        .rd1 (rd1),
        .rd2 (rd2)
    );

    // 6. Generador de inmediatos
    imm_gen ig (
        .instr   (instr),
        .imm_src (imm_src),
        .imm_ext (imm_ext)
    );

    // 7. Mux del operando A: rs1 o PC (este ultimo solo en auipc)
    mux2 #(.W(32)) mux_a (
        .d0  (rd1),
        .d1  (pc_actual),
        .sel (alu_src_a),
        .y   (src_a)
    );

    // 8. Mux del operando B: rs2 o el inmediato
    mux2 #(.W(32)) mux_b (
        .d0  (rd2),
        .d1  (imm_ext),
        .sel (alu_src_b),
        .y   (src_b)
    );

    // 9. ALU
    alu alu_i (
        .src_a       (src_a),
        .src_b       (src_b),
        .alu_control (alu_control),
        .alu_result  (alu_result),
        .zero        (zero),
        .less        (less),
        .less_u      (less_u)
    );

    // 10. Memoria de datos (el testbench la busca como "dmem")
    data_memory #(.DEPTH(DMEM_DEPTH)) dmem (
        .clk    (clk),
        .we     (mem_write),
        .funct3 (funct3),
        .addr   (alu_result),
        .wd     (rd2),
        .rd     (read_data)
    );

    // 11. Mux de lo que se escribe en rd
    mux4 #(.W(32)) mux_res (
        .d00 (alu_result),
        .d01 (read_data),
        .d10 (pc_plus4),
        .d11 (imm_ext),
        .sel (result_src),
        .y   (result)
    );

    // 12. Sumador del destino de salto: PC + ImmExt
    adder add_tgt (
        .a (pc_actual),
        .b (imm_ext),
        .y (pc_plus_imm)
    );

    // 13. Mux del destino: branch/jal usan el sumador, jalr usa la ALU con el bit 0 en cero
    mux2 #(.W(32)) mux_jalr (
        .d0  (pc_plus_imm),
        .d1  ({alu_result[31:1], 1'b0}),
        .sel (jalr),
        .y   (pc_target)
    );

    // 14. Mux del proximo PC
    mux2 #(.W(32)) mux_pc (
        .d0  (pc_plus4),
        .d1  (pc_target),
        .sel (pc_src),
        .y   (pc_next)
    );

endmodule
