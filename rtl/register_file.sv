// =============================================================================
// register_file.sv - Banco de 32 registros de 32 bits
//
// Asimetria fundamental:
//   - Lectura  COMBINACIONAL: el datapath necesita los operandos en el mismo
//     ciclo en que decodifica la instruccion.
//   - Escritura SINCRONA: el resultado se guarda en el flanco de reloj.
//
// Los nombres de los puertos son los del diagrama del datapath: rs1, rs2 y rd
// son los tres campos de registro de la instruccion, y wd3 el dato que entra.
//
// x0 esta cableado a cero. Se protege en los DOS lados:
//   - en escritura, para que nunca se modifique;
//   - en lectura, para que devuelva 0 aunque el arreglo tenga basura.
// La proteccion en lectura no es redundante: en simulacion el arreglo arranca
// con valores X, y sin ella una asercion sobre x0 fallaria siempre.
// =============================================================================
module register_file (
    input  logic        clk,
    input  logic        we,       // habilitacion de escritura (RegWrite)
    input  logic [4:0]  rs1,      // direccion de lectura 1
    input  logic [4:0]  rs2,      // direccion de lectura 2
    input  logic [4:0]  rd,       // direccion de escritura
    input  logic [31:0] wd3,      // dato a escribir
    output logic [31:0] rd1,
    output logic [31:0] rd2
);

    logic [31:0] regs [0:31];

    always_ff @(posedge clk) begin
        if (we && (rd != 5'd0)) begin
            regs[rd] <= wd3;
        end
    end

    assign rd1 = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

    // Inicializacion solo para simulacion. En la FPGA los registros arrancan
    // segun el bitstream, no segun un initial: el diseno depende del reset,
    // no de este bloque.
    // synthesis translate_off
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) regs[i] = 32'd0;
    end
    // synthesis translate_on

endmodule
