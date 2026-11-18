// =============================================================================
// riscv_pkg.sv - Constantes compartidas del procesador RV32I
//
// Todos los modulos importan este paquete para no repetir codigos magicos.
// La convencion de senales esta documentada en docs/05_monociclo.md.
// =============================================================================
package riscv_pkg;

    // -------------------------------------------------------------------------
    // Opcodes RV32I (instr[6:0])
    // -------------------------------------------------------------------------
    localparam logic [6:0] OP_R      = 7'b0110011;  // add, sub, and, or, ...
    localparam logic [6:0] OP_IMM    = 7'b0010011;  // addi, andi, slli, ...
    localparam logic [6:0] OP_LOAD   = 7'b0000011;  // lb, lh, lw, lbu, lhu
    localparam logic [6:0] OP_STORE  = 7'b0100011;  // sb, sh, sw
    localparam logic [6:0] OP_BRANCH = 7'b1100011;  // beq, bne, blt, bge, ...
    localparam logic [6:0] OP_JAL    = 7'b1101111;  // jal
    localparam logic [6:0] OP_JALR   = 7'b1100111;  // jalr
    localparam logic [6:0] OP_LUI    = 7'b0110111;  // lui
    localparam logic [6:0] OP_AUIPC  = 7'b0010111;  // auipc

    // -------------------------------------------------------------------------
    // ImmSrc - formato del inmediato que debe extraer el generador (3 bits)
    // -------------------------------------------------------------------------
    localparam logic [2:0] IMM_I = 3'b000;
    localparam logic [2:0] IMM_S = 3'b001;
    localparam logic [2:0] IMM_B = 3'b010;
    localparam logic [2:0] IMM_J = 3'b011;
    localparam logic [2:0] IMM_U = 3'b100;

    // -------------------------------------------------------------------------
    // ResultSrc - que valor se escribe en rd (2 bits)
    //
    // Con 1 bit (el "MemtoReg" clasico) es IMPOSIBLE escribir PC+4 en rd, que
    // es justo lo que necesitan jal y jalr.
    // -------------------------------------------------------------------------
    localparam logic [1:0] RES_ALU  = 2'b00;   // resultado de la ALU
    localparam logic [1:0] RES_MEM  = 2'b01;   // dato leido de memoria
    localparam logic [1:0] RES_PC4  = 2'b10;   // PC+4  (jal, jalr)
    localparam logic [1:0] RES_IMM  = 2'b11;   // ImmExt (lui)

    // -------------------------------------------------------------------------
    // ALUOp - salida del control principal hacia el decodificador de la ALU
    // -------------------------------------------------------------------------
    localparam logic [1:0] ALUOP_ADD   = 2'b00;  // forzar suma (loads/stores/auipc/jalr)
    localparam logic [1:0] ALUOP_SUB   = 2'b01;  // forzar resta (branches)
    localparam logic [1:0] ALUOP_FUNCT = 2'b10;  // depende de funct3 / instr[30]
    localparam logic [1:0] ALUOP_PASSB = 2'b11;  // pasar el operando B (lui por ALU)

    // -------------------------------------------------------------------------
    // ALUControl = {mod, funct3}  (4 bits)
    //
    // ALUControl[2:0] ES funct3, asi que el decodificador es casi un cable.
    // mod = instr[30] AND ( op[5] OR (opcode == OP_IMM AND funct3 == 101) )
    //
    // El termino op[5] es OBLIGATORIO: en una instruccion tipo I, instr[30] es
    // un bit del INMEDIATO, no funct7[5]. Sin el, addi x1, x0, -5 (0xFFB00093,
    // instr[30]=1) se ejecutaria como SUB y calcularia +5.
    // La unica excepcion es srai, que si usa instr[30] siendo tipo I.
    // -------------------------------------------------------------------------
    localparam logic [3:0] ALU_ADD   = 4'b0000;
    localparam logic [3:0] ALU_SLL   = 4'b0001;
    localparam logic [3:0] ALU_SLT   = 4'b0010;
    localparam logic [3:0] ALU_SLTU  = 4'b0011;
    localparam logic [3:0] ALU_XOR   = 4'b0100;
    localparam logic [3:0] ALU_SRL   = 4'b0101;
    localparam logic [3:0] ALU_OR    = 4'b0110;
    localparam logic [3:0] ALU_AND   = 4'b0111;
    localparam logic [3:0] ALU_SUB   = 4'b1000;
    localparam logic [3:0] ALU_SRA   = 4'b1101;
    localparam logic [3:0] ALU_PASSB = 4'b1111;  // no colisiona con ningun {mod,funct3}

    // -------------------------------------------------------------------------
    // funct3 de las instrucciones de salto condicional
    // -------------------------------------------------------------------------
    localparam logic [2:0] F3_BEQ  = 3'b000;
    localparam logic [2:0] F3_BNE  = 3'b001;
    localparam logic [2:0] F3_BLT  = 3'b100;
    localparam logic [2:0] F3_BGE  = 3'b101;
    localparam logic [2:0] F3_BLTU = 3'b110;
    localparam logic [2:0] F3_BGEU = 3'b111;

    // -------------------------------------------------------------------------
    // funct3 de loads y stores: selecciona el ancho del acceso
    // -------------------------------------------------------------------------
    localparam logic [2:0] F3_BYTE  = 3'b000;  // lb  / sb
    localparam logic [2:0] F3_HALF  = 3'b001;  // lh  / sh
    localparam logic [2:0] F3_WORD  = 3'b010;  // lw  / sw
    localparam logic [2:0] F3_BYTEU = 3'b100;  // lbu
    localparam logic [2:0] F3_HALFU = 3'b101;  // lhu

    // Instruccion nop canonica: addi x0, x0, 0
    localparam logic [31:0] NOP = 32'h0000_0013;

endpackage
