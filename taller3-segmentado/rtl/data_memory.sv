// =============================================================================
// data_memory.sv - Memoria de datos                >>> LO ESCRIBEN USTEDES <<<
//
// Una palabra de 32 bits por fila, con acceso de byte, media palabra y
// palabra. Lo primero que hay que tener claro: la direccion que llega es de
// BYTE y el arreglo es de PALABRAS, asi que addr y el indice de fila no son
// lo mismo.
//
// El ancho del acceso lo decide funct3, que llega directo desde la instruccion:
// NO es una senal del control principal. Las senales de control de lb, lh y lw
// son identicas; lo unico que cambia es funct3.
//
//   funct3  000 = lb  (con signo)    000 = sb
//           001 = lh  (con signo)    001 = sh
//           010 = lw                 010 = sw
//           100 = lbu (sin signo)
//           101 = lhu (sin signo)
//
// Lo que falta, en este orden:
//   1. El indice de fila y el byte dentro de la fila.
//   2. La lectura: combinacional, con la extension que pide funct3.
//   3. La escritura: sincrona, y en sb y sh SIN pisar los bytes vecinos.
//
// Las constantes F3_BYTE, F3_HALF, ... estan en riscv_pkg.
// =============================================================================
module data_memory
#(
    parameter int DEPTH = 256                 // numero de palabras
)(
    input  logic        clk,
    input  logic        we,                   // MemWrite
    input  logic [2:0]  funct3,
    input  logic [31:0] addr,
    input  logic [31:0] wd,
    output logic [31:0] rd
);

    import riscv_pkg::*;

    // Bits de indice que hacen falta: 8 para 256 filas
    localparam int AW = $clog2(DEPTH);

    // El testbench lee este arreglo por su nombre: no lo renombren
    logic [31:0] mem [0:DEPTH-1];

    logic [AW-1:0] word_idx;   // que fila
    logic [1:0]    byte_off;   // que byte dentro de la fila

    // -------------------------------------------------------------------------
    // 1. El corte de la direccion
    //
    // Ni addr (cae en la fila equivocada) ni addr[31:2] (treinta bits de
    // indice para un arreglo de DEPTH filas). Son AW bits, justo encima de los
    // dos que eligen el byte.
    // -------------------------------------------------------------------------
    assign word_idx = addr[AW+1:2];
    assign byte_off = addr[1:0];

    // -------------------------------------------------------------------------
    // 2. Lectura combinacional, con extension segun funct3
    //
    // Conviene sacar primero la palabra, el byte y la media palabra, y despues
    // elegir en el case. Para el byte hace falta un part-select de base
    // variable:   palabra[8*byte_off +: 8]
    //
    // lb y lh extienden el SIGNO; lbu y lhu rellenan con ceros. Cada
    // concatenacion tiene que sumar 32 bits.
    // -------------------------------------------------------------------------
    logic [31:0] palabra;     // la fila completa que apunta addr
    logic [7:0]  dato_byte;   // el byte que eligio byte_off
    logic [15:0] dato_half;   // la media palabra (baja o alta)

    assign palabra   = mem[word_idx];
    assign dato_byte = palabra[8*byte_off +: 8];
    assign dato_half = byte_off[1] ? palabra[31:16] : palabra[15:0];

    always_comb begin
        rd = 32'd0;

        case (funct3)
            F3_BYTE:  rd = {{24{dato_byte[7]}},  dato_byte};   // lb  con signo
            F3_HALF:  rd = {{16{dato_half[15]}}, dato_half};   // lh  con signo
            F3_WORD:  rd = palabra;                            // lw
            F3_BYTEU: rd = {24'd0, dato_byte};                 // lbu sin signo
            F3_HALFU: rd = {16'd0, dato_half};                 // lhu sin signo
            default: rd = 32'd0;
        endcase
    end

    // -------------------------------------------------------------------------
    // 3. Escritura sincrona, respetando el ancho del acceso
    //
    // sw escribe la fila entera. sb y sh escriben SOLO su trozo:
    //
    //     mem[word_idx][8*byte_off +: 8] <= wd[7:0];
    //
    // Si escriben la fila entera en un sb, pisan los otros tres bytes y nada
    // se queja. tb_data_memory y prog/bytes.s estan hechos para delatarlo.
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (we) begin
            case (funct3)
                F3_BYTE: mem[word_idx][8*byte_off +: 8] <= wd[7:0];            // sb
                F3_HALF: begin                                                  // sh
                    if (byte_off[1]) mem[word_idx][31:16] <= wd[15:0];
                    else             mem[word_idx][15:0]  <= wd[15:0];
                end
                F3_WORD: mem[word_idx] <= wd;                                   // sw
                default: ;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Esto ya esta hecho, no lo toquen
    // -------------------------------------------------------------------------
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) mem[i] = 32'd0;
    end

    // Aviso de acceso desalineado. La especificacion RV32I permite que un
    // acceso desalineado genere una excepcion; este procesador no las
    // implementa, asi que al menos hay que verlo en simulacion.
    // synthesis translate_off
    always @(posedge clk) begin
        if (we || (funct3 == F3_WORD)) begin
            if ((funct3 == F3_WORD) && (byte_off != 2'b00))
                $display("[dmem] AVISO: acceso de palabra desalineado en 0x%08h", addr);
            if (((funct3 == F3_HALF) || (funct3 == F3_HALFU)) && (byte_off[0] != 1'b0))
                $display("[dmem] AVISO: acceso de media palabra desalineado en 0x%08h", addr);
        end
    end
    // synthesis translate_on

endmodule
