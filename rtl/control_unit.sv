// =============================================================================
// control_unit.sv - Unidad de control principal    >>> LO ESCRIBEN USTEDES <<<
//
// Mira el opcode (y a veces funct3 e instr[30]) y produce todas las senales
// que gobiernan el datapath. No toca datos: solo decide.
//
// Son TRES bloques independientes, y conviene escribirlos en este orden:
//
//   1. Decodificador principal   case (opcode) -> las nueve filas de la tabla
//   2. Decodificador de la ALU   alu_op + funct3 + instr[30] -> alu_control
//   3. Logica de pc_src          branch + funct3 + banderas  -> pc_src
//
// La tabla de las nueve filas esta en docs/cheat-sheet-datapath.html, cara 2.
// Esta unidad NO recibe el reloj: es combinacional pura.
// =============================================================================
module control_unit (
    // --- Entradas: lo que dice la instruccion ---
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic       funct7b5,     // instr[30]

    // --- Entradas: lo que dice la ALU sobre los operandos ---
    input  logic       zero,         // rs1 == rs2
    input  logic       less,         // rs1 <  rs2   con signo
    input  logic       less_u,       // rs1 <  rs2   sin signo

    // --- Salidas: las senales de control ---
    output logic       reg_write,
    output logic [2:0] imm_src,
    output logic       alu_src_a,    // 0 = rs1, 1 = PC   (solo auipc)
    output logic       alu_src_b,    // 0 = rs2, 1 = ImmExt
    output logic       mem_write,
    output logic [1:0] result_src,
    output logic       branch,
    output logic       jump,
    output logic       jalr,         // el destino viene de la ALU, no del sumador
    output logic [3:0] alu_control,
    output logic       pc_src
);

    import riscv_pkg::*;

    // alu_op es interna: la produce el bloque 1 y la consume el bloque 2.
    // Nunca sale del modulo.
    logic [1:0] alu_op;

    // -------------------------------------------------------------------------
    // BLOQUE 1 - Decodificador principal
    //
    // Empieza SIEMPRE con las asignaciones por defecto, antes del case. Son la
    // primera de las dos protecciones: sin ellas, cada rama que se olvide de
    // asignar una senal infiere un latch, y ninguna herramienta te avisa.
    //
    // Las nueve ramas, con sus constantes del paquete:
    //   OP_R      OP_IMM    OP_LOAD   OP_STORE   OP_BRANCH
    //   OP_JAL    OP_JALR   OP_LUI    OP_AUIPC
    //
    // Pistas de las tres que suelen salir mal:
    //   - OP_LUI no usa la ALU: result_src = RES_IMM, y alu_op se queda en su
    //     valor por defecto.
    //   - OP_AUIPC es el unico que pone alu_src_a = 1.
    //   - OP_JALR es el unico que pone jalr = 1.
    // -------------------------------------------------------------------------
    always_comb begin
        reg_write  = 1'b0;
        imm_src    = IMM_I;
        alu_src_a  = 1'b0;
        alu_src_b  = 1'b0;
        mem_write  = 1'b0;
        result_src = RES_ALU;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        alu_op     = ALUOP_ADD;

        case (opcode)
            OP_R: begin
                reg_write = 1'b1;
                alu_op    = ALUOP_FUNCT;
            end

            OP_IMM: begin
                reg_write = 1'b1;
                imm_src   = IMM_I;
                alu_src_b = 1'b1;
                alu_op    = ALUOP_FUNCT;
            end

            OP_LOAD: begin
                reg_write  = 1'b1;
                imm_src    = IMM_I;
                alu_src_b  = 1'b1;
                result_src = RES_MEM;
                alu_op     = ALUOP_ADD;
            end

            OP_STORE: begin
                imm_src   = IMM_S;
                alu_src_b = 1'b1;
                mem_write = 1'b1;
                alu_op    = ALUOP_ADD;
            end

            OP_BRANCH: begin
                imm_src = IMM_B;
                branch  = 1'b1;
                alu_op  = ALUOP_SUB;
            end

            OP_JAL: begin
                reg_write  = 1'b1;
                imm_src    = IMM_J;
                result_src = RES_PC4;
                jump       = 1'b1;
            end

            OP_JALR: begin
                reg_write  = 1'b1;
                imm_src    = IMM_I;
                alu_src_b  = 1'b1;
                result_src = RES_PC4;
                jump       = 1'b1;
                jalr       = 1'b1;
                alu_op     = ALUOP_ADD;
            end

            OP_LUI: begin
                reg_write  = 1'b1;
                imm_src    = IMM_U;
                result_src = RES_IMM;
            end

            OP_AUIPC: begin
                reg_write = 1'b1;
                imm_src   = IMM_U;
                alu_src_a = 1'b1;
                alu_src_b = 1'b1;
                alu_op    = ALUOP_ADD;
            end

            default: ;
        endcase
    end

    // -------------------------------------------------------------------------
    // BLOQUE 2 - Decodificador de la ALU
    //
    // alu_control = {mod, funct3}, porque los tres bits de abajo de
    // ALUControl SON funct3. El decodificador es casi un cable.
    //
    // El bit mod distingue las parejas que comparten funct3:
    //   add / sub        funct3 = 000
    //   srl / sra        funct3 = 101
    //
    // Y aqui esta la trampa del curso. mod NO es simplemente instr[30]:
    //
    //   addi x1, x0, -5   es   0xFFB00093   ->   instr[30] = 1
    //
    // Si mod = funct7b5 a secas, ese addi se ejecuta como SUB y x1 queda en 5
    // en vez de -5. El programa de prueba lo detecta en el registro x15.
    // Hay que anadir el termino que distingue tipo R de tipo I, mas la
    // excepcion de srai, que SI es tipo I y SI necesita mod = 1.
    // -------------------------------------------------------------------------
    logic mod;

    assign mod = funct7b5 & (opcode[5] | ((opcode == OP_IMM) & (funct3 == 3'b101)));

    always_comb begin
        alu_control = ALU_ADD;

        case (alu_op)
            ALUOP_ADD:   alu_control = ALU_ADD;
            ALUOP_SUB:   alu_control = ALU_SUB;
            ALUOP_FUNCT: alu_control = {mod, funct3};
            ALUOP_PASSB: alu_control = ALU_PASSB;
            default: alu_control = ALU_ADD;
        endcase
    end

    // -------------------------------------------------------------------------
    // BLOQUE 3 - Logica de pc_src
    //
    // Un salto condicional se toma cuando la comparacion que pide su funct3 da
    // verdadero. Las banderas vienen de la ALU y se calculan de los OPERANDOS,
    // no del resultado, asi que son validas siempre.
    //
    //   F3_BEQ   se toma si  zero          F3_BNE    si  ~zero
    //   F3_BLT   se toma si  less          F3_BGE    si  ~less
    //   F3_BLTU  se toma si  less_u        F3_BGEU   si  ~less_u
    //
    // Un salto incondicional (jal, jalr) se toma siempre.
    // -------------------------------------------------------------------------
    logic branch_taken;

    always_comb begin
        branch_taken = 1'b0;

        if (branch) begin
            case (funct3)
                F3_BEQ:  branch_taken = zero;
                F3_BNE:  branch_taken = ~zero;
                F3_BLT:  branch_taken = less;
                F3_BGE:  branch_taken = ~less;
                F3_BLTU: branch_taken = less_u;
                F3_BGEU: branch_taken = ~less_u;
                default: branch_taken = 1'b0;
            endcase
        end
    end

    assign pc_src = branch_taken | jump;

endmodule
