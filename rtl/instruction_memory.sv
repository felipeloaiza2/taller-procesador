// =============================================================================
// instruction_memory.sv - Memoria de instrucciones (solo lectura)
//
// La direccion que llega es de BYTE, pero cada posicion guarda una palabra de
// 32 bits: hay que indexar con addr[AW+1:2], no con addr[31:2].
//
// Indexar con addr[31:2] sobre un arreglo de N posiciones es un error real:
// son 30 bits de indice para un arreglo que puede tener 256 entradas.
// =============================================================================
module instruction_memory
#(
    parameter int    DEPTH    = 256,          // numero de palabras
    parameter        INIT_FILE = ""           // .hex para $readmemh
)(
    input  logic [31:0] addr,
    output logic [31:0] instr
);

    import riscv_pkg::*;

    localparam int AW = $clog2(DEPTH);

    logic [31:0] mem [0:DEPTH-1];

    assign instr = mem[addr[AW+1:2]];

    integer i;
    initial begin
        // Rellenar con nop antes de cargar el programa: si el PC se sale del
        // codigo, el procesador ejecuta nop en vez de basura.
        for (i = 0; i < DEPTH; i = i + 1) mem[i] = NOP;
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    // Aviso en simulacion si el PC se sale del rango implementado.
    // synthesis translate_off
    always @(addr) begin
        if (addr[31:2] >= DEPTH) begin
            $display("[imem] AVISO: PC=0x%08h fuera de rango (DEPTH=%0d palabras)", addr, DEPTH);
        end
    end
    // synthesis translate_on

endmodule
