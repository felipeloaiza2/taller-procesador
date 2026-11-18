// =============================================================================
// riscv_segmentado.sv - El procesador de cinco etapas     >>> TALLER 3, FASE 4 <<<
//
// Parte del riscv_monociclo del Taller 2: las MISMAS cajas (ALU, banco, imm_gen,
// control, las dos memorias, sumadores y muxes), sin tocar una sola. Lo nuevo
// son los cuatro registros de segmentacion, la unidad de forwarding, la unidad
// de deteccion de riesgos, dos muxes de tres entradas delante de la ALU y cables.
//
// CONVENCION DE SUFIJOS: _f IF, _d ID, _e EX, _m MEM, _w WB.
//   rd_m = "el rd de la instruccion que esta ahora en MEM".
//
// NOMBRES DE INSTANCIA QUE EL TESTBENCH NECESITA (igual que en el Taller 2):
//   register_file -> rf        data_memory -> dmem
//
// -----------------------------------------------------------------------------
// TRES DECISIONES DE DISENO QUE NO ESTAN EN LA GUIA (ver INFORME.txt):
//
//  a) El banco de registros del Taller 2 escribe en el flanco de SUBIDA. La guia
//     (seccion 5) asume que escribe en el primer medio ciclo, para resolver la
//     dependencia a distancia 3. Sin tocar register_file.sv, eso se consigue
//     dandole el reloj INVERTIDO: escribe en el flanco de bajada (a mitad de
//     ciclo) y la lectura combinacional de ID ya ve el valor nuevo.
//
//  b) funct3 viaja por ID/EX y EX/MEM: la memoria de datos lo necesita en MEM
//     para elegir el ancho (lb/lh/lw/sb/sh/sw) y el salto lo necesita en EX.
//     La tabla de la seccion 2 no lo lista, pero sin el no hay lb ni bne.
//
//  c) control_unit.sv calcula pc_src a partir de las banderas de la ALU, y esas
//     banderas existen en EX, no en ID. Se usa control_unit en ID para todo lo
//     demas (su pc_src se ignora: banderas atadas a 0) y la decision del salto
//     se toma en EX con la misma tabla del bloque 3 de control_unit.
// =============================================================================
module riscv_segmentado #(
    parameter int IMEM_DEPTH = 256,
    parameter int DMEM_DEPTH = 256,
    parameter     INIT_FILE  = ""
)(
    input logic clk,
    input logic rst,
    input logic en
);

    import riscv_pkg::*;

    // =========================================================================
    // CABLES
    // =========================================================================

    // ---- IF ----
    logic [31:0] pc_f, pc_plus4_f, pc_next, instr_f;

    // ---- ID ----
    logic [31:0] instr_d, pc_d, pc_plus4_d;
    logic [6:0]  opcode_d;
    logic [2:0]  funct3_d;
    logic        funct7b5_d;
    logic [4:0]  rs1_d, rs2_d, rd_d;
    logic [31:0] rd1_d, rd2_d, imm_ext_d;
    logic        reg_write_d, alu_src_a_d, alu_src_b_d, mem_write_d;
    logic        branch_d, jump_d, jalr_d;
    logic [2:0]  imm_src_d;
    logic [1:0]  result_src_d;
    logic [3:0]  alu_control_d;
    logic        pc_src_ignorado;       // salida de control_unit que no se usa en ID

    // ---- EX ----
    logic [31:0] rd1_e, rd2_e, pc_e, pc_plus4_e, imm_ext_e;
    logic [4:0]  rs1_e, rs2_e, rd_e;
    logic [2:0]  funct3_e;
    logic        alu_src_a_e, alu_src_b_e, branch_e, jump_e, jalr_e;
    logic [3:0]  alu_control_e;
    logic        mem_write_e, reg_write_e;
    logic [1:0]  result_src_e;
    logic [1:0]  forward_a_e, forward_b_e;
    logic [31:0] fwd_a_e, fwd_b_e;          // operandos ya adelantados
    logic [31:0] src_a_e, src_b_e;
    logic [31:0] alu_result_e, result_e;
    logic [31:0] pc_plus_imm_e, pc_target_e;
    logic        zero_e, less_e, less_u_e;
    logic        branch_taken_e, pc_src_e;

    // ---- MEM ----
    logic [31:0] result_m, write_data_m, pc_plus4_m, pc_target_m, read_data_m;
    logic [4:0]  rd_m;
    logic [2:0]  funct3_m;
    logic        mem_write_m, reg_write_m;
    logic [1:0]  result_src_m;

    // ---- WB ----
    logic [31:0] read_data_w, exres_w, pc_plus4_w, result_w;
    logic [4:0]  rd_w;
    logic        reg_write_w;
    logic [1:0]  result_src_w;

    // ---- Unidad de riesgos ----
    logic stall_f, stall_d, flush_d, flush_e;

    // =========================================================================
    // ETAPA IF
    // =========================================================================
    pc registro_pc (
        .clk     (clk),
        .rst     (rst),
        .en      (en & ~stall_f),
        .pc_next (pc_next),
        .pc      (pc_f)
    );

    adder add_pc4 (
        .a (pc_f),
        .b (32'd4),
        .y (pc_plus4_f)
    );

    instruction_memory #(
        .DEPTH     (IMEM_DEPTH),
        .INIT_FILE (INIT_FILE)
    ) imem (
        .addr  (pc_f),
        .instr (instr_f)
    );

    // El proximo PC: secuencial, o el destino que decidio EX
    mux2 #(.W(32)) mux_pc (
        .d0  (pc_plus4_f),
        .d1  (pc_target_e),
        .sel (pc_src_e),
        .y   (pc_next)
    );

    // =========================================================================
    // REGISTRO IF/ID   {instr, pc, pc+4}   = 96 bits
    //   en  : se congela con StallD
    //   clr : se vacia con FlushD (y con el reset)
    // =========================================================================
    logic [95:0] if_id_d, if_id_q;
    assign if_id_d = {instr_f, pc_f, pc_plus4_f};
    assign {instr_d, pc_d, pc_plus4_d} = if_id_q;

    pipe_reg #(.W(96)) reg_if_id (
        .clk (clk),
        .en  (en & ~stall_d),
        .clr (rst | flush_d),
        .d   (if_id_d),
        .q   (if_id_q)
    );

    // =========================================================================
    // ETAPA ID
    // =========================================================================
    assign opcode_d   = instr_d[6:0];
    assign rd_d       = instr_d[11:7];
    assign funct3_d   = instr_d[14:12];
    assign rs1_d      = instr_d[19:15];
    assign rs2_d      = instr_d[24:20];
    assign funct7b5_d = instr_d[30];

    // Las banderas de la ALU no existen todavia en ID: se atan a 0 y el pc_src
    // de esta instancia se ignora. El salto se decide en EX.
    control_unit control (
        .opcode      (opcode_d),
        .funct3      (funct3_d),
        .funct7b5    (funct7b5_d),
        .zero        (1'b0),
        .less        (1'b0),
        .less_u      (1'b0),
        .reg_write   (reg_write_d),
        .imm_src     (imm_src_d),
        .alu_src_a   (alu_src_a_d),
        .alu_src_b   (alu_src_b_d),
        .mem_write   (mem_write_d),
        .result_src  (result_src_d),
        .branch      (branch_d),
        .jump        (jump_d),
        .jalr        (jalr_d),
        .alu_control (alu_control_d),
        .pc_src      (pc_src_ignorado)
    );

    // El banco escribe con el reloj INVERTIDO (ver decision a de la cabecera)
    logic clk_n;
    assign clk_n = ~clk;

    register_file rf (
        .clk (clk_n),
        .we  (reg_write_w),
        .rs1 (rs1_d),
        .rs2 (rs2_d),
        .rd  (rd_w),
        .wd3 (result_w),
        .rd1 (rd1_d),
        .rd2 (rd2_d)
    );

    imm_gen ig (
        .instr   (instr_d),
        .imm_src (imm_src_d),
        .imm_ext (imm_ext_d)
    );

    // =========================================================================
    // REGISTRO ID/EX   191 bits
    //   datos   rd1 rd2 pc pc+4 imm                      5 x 32 = 160
    //   regs    rs1 rs2 rd                               3 x 5  =  15
    //   funct3                                                      3
    //   EX      alu_src_a alu_src_b alu_control(4) branch jump jalr = 9
    //   MEM     mem_write                                           1
    //   WB      reg_write result_src(2)                             3
    //   rs1 y rs2 viajan aunque ya se leyeron: el forwarding compara NUMEROS.
    // =========================================================================
    logic [190:0] id_ex_d, id_ex_q;
    assign id_ex_d = {rd1_d, rd2_d, pc_d, pc_plus4_d, imm_ext_d,
        rs1_d, rs2_d, rd_d,
        funct3_d,
        alu_src_a_d, alu_src_b_d, alu_control_d, branch_d, jump_d, jalr_d,
        mem_write_d,
        reg_write_d, result_src_d};
    assign {rd1_e, rd2_e, pc_e, pc_plus4_e, imm_ext_e,
        rs1_e, rs2_e, rd_e,
        funct3_e,
        alu_src_a_e, alu_src_b_e, alu_control_e, branch_e, jump_e, jalr_e,
        mem_write_e,
        reg_write_e, result_src_e} = id_ex_q;

    pipe_reg #(.W(191)) reg_id_ex (
        .clk (clk),
        .en  (en),
        .clr (rst | flush_e),
        .d   (id_ex_d),
        .q   (id_ex_q)
    );

    // =========================================================================
    // ETAPA EX
    // =========================================================================
    forwarding_unit fwd (
        .rs1_e       (rs1_e),
        .rs2_e       (rs2_e),
        .rd_m        (rd_m),
        .rd_w        (rd_w),
        .reg_write_m (reg_write_m),
        .reg_write_w (reg_write_w),
        .forward_a_e (forward_a_e),
        .forward_b_e (forward_b_e)
    );

    // Multiplexor de tres entradas delante de cada operando: 00 banco, 10 EX/MEM,
    // 01 MEM/WB. Se usa mux4; la rama 11 no ocurre y repite la del banco.
    mux4 #(.W(32)) mux_fwd_a (
        .d00 (rd1_e),
        .d01 (result_w),
        .d10 (result_m),
        .d11 (rd1_e),
        .sel (forward_a_e),
        .y   (fwd_a_e)
    );

    mux4 #(.W(32)) mux_fwd_b (
        .d00 (rd2_e),
        .d01 (result_w),
        .d10 (result_m),
        .d11 (rd2_e),
        .sel (forward_b_e),
        .y   (fwd_b_e)
    );

    // Los mux del Taller 2: A elige rs1 o PC (auipc); B elige rs2 o el inmediato.
    // Entran con el valor ya ADELANTADO, no con el del banco.
    mux2 #(.W(32)) mux_a (
        .d0  (fwd_a_e),
        .d1  (pc_e),
        .sel (alu_src_a_e),
        .y   (src_a_e)
    );

    mux2 #(.W(32)) mux_b (
        .d0  (fwd_b_e),
        .d1  (imm_ext_e),
        .sel (alu_src_b_e),
        .y   (src_b_e)
    );

    alu alu_i (
        .src_a       (src_a_e),
        .src_b       (src_b_e),
        .alu_control (alu_control_e),
        .alu_result  (alu_result_e),
        .zero        (zero_e),
        .less        (less_e),
        .less_u      (less_u_e)
    );

    // Destino de salto: PC de ESTA instruccion + inmediato
    adder add_tgt (
        .a (pc_e),
        .b (imm_ext_e),
        .y (pc_plus_imm_e)
    );

    mux2 #(.W(32)) mux_jalr (
        .d0  (pc_plus_imm_e),
        .d1  ({alu_result_e[31:1], 1'b0}),
        .sel (jalr_e),
        .y   (pc_target_e)
    );

    // Decision del salto condicional: la misma tabla del bloque 3 de control_unit
    always_comb begin
        branch_taken_e = 1'b0;
        if (branch_e) begin
            case (funct3_e)
                F3_BEQ:  branch_taken_e = zero_e;
                F3_BNE:  branch_taken_e = ~zero_e;
                F3_BLT:  branch_taken_e = less_e;
                F3_BGE:  branch_taken_e = ~less_e;
                F3_BLTU: branch_taken_e = less_u_e;
                F3_BGEU: branch_taken_e = ~less_u_e;
                default: branch_taken_e = 1'b0;
            endcase
        end
    end

    assign pc_src_e = branch_taken_e | jump_e;

    // El mux de ResultSrc SE MUEVE A EX para los casos que ya tienen su valor
    // aqui (ALU, PC+4, inmediato), de modo que EX/MEM lleve el valor DEFINITIVO
    // de rd y el forwarding no adelante basura tras un lui o un jal.
    // Para un load (01) se deja la direccion: el dato aparece en MEM, y por eso
    // el load es el unico que obliga a parar. Nadie adelanta esa direccion.
    mux4 #(.W(32)) mux_res_ex (
        .d00 (alu_result_e),
        .d01 (alu_result_e),
        .d10 (pc_plus4_e),
        .d11 (imm_ext_e),
        .sel (result_src_e),
        .y   (result_e)
    );

    // =========================================================================
    // REGISTRO EX/MEM   140 bits
    //   result, write_data(rs2 adelantado), pc+4, destino salto   4 x 32 = 128
    //   rd 5, funct3 3, mem_write 1, reg_write 1, result_src 2       = 12
    //   (pc+4 y destino de salto viajan por la tabla de la guia aunque el mux
    //    de EX y la decision del salto en EX ya los consumieron)
    // =========================================================================
    logic [139:0] ex_mem_d, ex_mem_q;
    assign ex_mem_d = {result_e, fwd_b_e, pc_plus4_e, pc_target_e,
        rd_e, funct3_e,
        mem_write_e,
        reg_write_e, result_src_e};
    assign {result_m, write_data_m, pc_plus4_m, pc_target_m,
        rd_m, funct3_m,
        mem_write_m,
        reg_write_m, result_src_m} = ex_mem_q;

    pipe_reg #(.W(140)) reg_ex_mem (
        .clk (clk),
        .en  (en),
        .clr (rst),
        .d   (ex_mem_d),
        .q   (ex_mem_q)
    );

    // =========================================================================
    // ETAPA MEM
    // =========================================================================
    data_memory #(.DEPTH(DMEM_DEPTH)) dmem (
        .clk    (clk),
        .we     (mem_write_m),
        .funct3 (funct3_m),
        .addr   (result_m),
        .wd     (write_data_m),
        .rd     (read_data_m)
    );

    // =========================================================================
    // REGISTRO MEM/WB   104 bits
    //   read_data, result, pc+4 = 96 ; rd 5 ; reg_write 1 ; result_src 2
    // =========================================================================
    logic [103:0] mem_wb_d, mem_wb_q;
    assign mem_wb_d = {read_data_m, result_m, pc_plus4_m,
        rd_m,
        reg_write_m, result_src_m};
    assign {read_data_w, exres_w, pc_plus4_w,
        rd_w,
        reg_write_w, result_src_w} = mem_wb_q;

    pipe_reg #(.W(104)) reg_mem_wb (
        .clk (clk),
        .en  (en),
        .clr (rst),
        .d   (mem_wb_d),
        .q   (mem_wb_q)
    );

    // =========================================================================
    // ETAPA WB: un load escribe lo leido; todo lo demas, el valor de EX
    // =========================================================================
    // La comparacion se hace FUERA de la conexion de puertos: iverilog no
    // resuelve los nombres del paquete (RES_MEM) dentro de una conexion de
    // puerto y los toma por un cable sin driver (Z), lo que llena todo de X.
    logic es_load_w;
    assign es_load_w = (result_src_w == RES_MEM);

    mux2 #(.W(32)) mux_res_wb (
        .d0  (exres_w),
        .d1  (read_data_w),
        .sel (es_load_w),
        .y   (result_w)
    );

    // =========================================================================
    // UNIDAD DE DETECCION DE RIESGOS (vive en ID)
    // =========================================================================
    hazard_unit hazard (
        .rs1_d        (rs1_d),
        .rs2_d        (rs2_d),
        .rd_e         (rd_e),
        .result_src_e (result_src_e),
        .pc_src_e     (pc_src_e),
        .stall_f      (stall_f),
        .stall_d      (stall_d),
        .flush_d      (flush_d),
        .flush_e      (flush_e)
    );

endmodule
