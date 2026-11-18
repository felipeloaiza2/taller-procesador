// =============================================================================
// imm_gen.sv - Generador de inmediatos            >>> LO ESCRIBEN USTEDES <<<
//
// No es "un extensor de signo". Hace dos cosas:
//   1. REORDENA los bits, porque en los formatos B y J el inmediato esta
//      troceado y desordenado dentro de la instruccion.
//   2. Extiende el signo a 32 bits.
//
// Esta escrito de forma ESTRUCTURAL: un submodulo por formato y un multiplexor
// que elige cual sale. Los cinco submodulos trabajan siempre, a la vez, sobre
// la misma instruccion; imm_src solo decide a cual se le hace caso.
//
// Lo que falta: el assign de cada submodulo. El multiplexor ya esta hecho.
//
// Cada concatenacion tiene que sumar 32 bits. Cuentalos antes de compilar.
// La tabla de donde salen los bits esta en docs/cheat-sheet-datapath.html,
// cara 1, "imm_gen - que bits recoge segun ImmSrc".
// =============================================================================

// Tipo I: instr[31:20] de una pieza          (addi, lw, jalr, ...)
//         20 + 12 = 32 bits
module imm_i (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    assign imm = {{20{instr[31]}}, instr[31:20]};
endmodule


// Tipo S: instr[31:25] | instr[11:7]         (sw, sh, sb)
//         20 + 7 + 5 = 32 bits
module imm_s (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    assign imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
endmodule


// Tipo B: instr[31] | instr[7] | instr[30:25] | instr[11:8] | 0
//         20 + 1 + 6 + 4 + 1 = 32 bits
//
// Ese ultimo 1'b0 no es relleno: es el bit 0 del inmediato, que en un salto
// SIEMPRE es cero y por eso no se guarda en la instruccion. Si lo olvidas, el
// salto cae a la mitad de la distancia.
module imm_b (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    assign imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
endmodule


// Tipo J: instr[31] | instr[19:12] | instr[20] | instr[30:21] | 0
//         12 + 8 + 1 + 10 + 1 = 32 bits
//
// El relleno es de 12 bits y no de 20: el inmediato de J tiene 20 bits utiles
// contra los 12 de I. Por eso jal llega mucho mas lejos que un beq.
module imm_j (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    assign imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
endmodule


// Tipo U: instr[31:12] en la parte alta, ceros abajo   (lui, auipc)
//
// El unico formato donde el inmediato NO se extiende: llena la parte alta de
// la palabra, asi que no queda nada arriba que rellenar.
module imm_u (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    assign imm = {instr[31:12], 12'd0};
endmodule


// -----------------------------------------------------------------------------
// El multiplexor: esto ya esta hecho, no lo toquen
// -----------------------------------------------------------------------------
module imm_gen (
    input  logic [31:0] instr,
    input  logic [2:0]  imm_src,
    output logic [31:0] imm_ext
);

    import riscv_pkg::*;

    logic [31:0] tipo_i, tipo_s, tipo_b, tipo_j, tipo_u;

    imm_i gen_i (.instr (instr), .imm (tipo_i));
    imm_s gen_s (.instr (instr), .imm (tipo_s));
    imm_b gen_b (.instr (instr), .imm (tipo_b));
    imm_j gen_j (.instr (instr), .imm (tipo_j));
    imm_u gen_u (.instr (instr), .imm (tipo_u));

    always_comb begin
        imm_ext = 32'd0;

        case (imm_src)
            IMM_I: imm_ext = tipo_i;
            IMM_S: imm_ext = tipo_s;
            IMM_B: imm_ext = tipo_b;
            IMM_J: imm_ext = tipo_j;
            IMM_U: imm_ext = tipo_u;
            default: imm_ext = 32'd0;
        endcase
    end

endmodule
