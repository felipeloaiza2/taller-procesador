// =============================================================================
// pc.sv - El registro del contador de programa
//
// Es un flip-flop D de 32 bits con dos anadidos:
//   - rst: reset SINCRONO y activo en ALTO. Pone el PC en 0 en el flanco.
//   - en:  habilitacion. Con en = 0 el PC se queda quieto, que es lo que
//          permite parar el procesador sin tocar el reloj.
//
// Es la unica caja con estado del datapath, aparte del banco de registros y la
// memoria de datos.
// =============================================================================
module pc (
    input  logic        clk,
    input  logic        rst,
    input  logic        en,
    input  logic [31:0] pc_next,
    output logic [31:0] pc
);

    always_ff @(posedge clk) begin
        if (rst)      pc <= 32'd0;
        else if (en)  pc <= pc_next;
    end

endmodule
