// =============================================================================
// alu.sv - Unidad aritmetico-logica de 32 bits para RV32I
//
// Los nombres de los puertos son los del diagrama del datapath: SrcA, SrcB y
// ALUResult.
//
// Cubre las diez operaciones de RV32I y produce las tres banderas de
// comparacion que necesita la logica de PCSrc para los seis saltos condicionales.
//
// Las banderas se calculan directamente de los operandos, no del resultado.
// Asi son validas sea cual sea la operacion en curso, y el codigo dice lo que
// significan: eq/lt/ltu, no "el resultado dio cero".
// =============================================================================
module alu
(
    input  logic [31:0] src_a,       // el primer operando
    input  logic [31:0] src_b,       // el segundo operando
    input  logic [3:0]  alu_control,
    output logic [31:0] alu_result,
    output logic        zero,      // src_a == src_b
    output logic        less,      // src_a <  src_b   con signo
    output logic        less_u     // src_a <  src_b   sin signo
);

    import riscv_pkg::*;

    // El desplazamiento usa solo los 5 bits bajos del segundo operando.
    // Es lo que dice la especificacion: shamt = src_b[4:0].
    logic [4:0] shamt;
    assign shamt = src_b[4:0];

    always_comb begin
        // Valor por defecto: sin el, un case incompleto infiere un latch.
        alu_result = 32'd0;

        case (alu_control)
            ALU_ADD  : alu_result = src_a + src_b;
            ALU_SUB  : alu_result = src_a - src_b;
            ALU_SLL  : alu_result = src_a << shamt;
            ALU_SLT  : alu_result = {31'd0, ($signed(src_a) < $signed(src_b))};
            ALU_SLTU : alu_result = {31'd0, (src_a < src_b)};
            ALU_XOR  : alu_result = src_a ^ src_b;
            ALU_SRL  : alu_result = src_a >> shamt;
            // >>> sobre un operando con signo es desplazamiento aritmetico.
            // Sin $signed, >>> se comporta igual que >> y sra queda mal.
            ALU_SRA  : alu_result = $signed(src_a) >>> shamt;
            ALU_OR   : alu_result = src_a | src_b;
            ALU_AND  : alu_result = src_a & src_b;
            ALU_PASSB: alu_result = src_b;
            default  : alu_result = 32'd0;
        endcase
    end

    assign zero   = (src_a == src_b);
    assign less   = ($signed(src_a) < $signed(src_b));
    assign less_u = (src_a < src_b);

endmodule
