// =============================================================================
// mux2.sv - Multiplexor de 2 a 1                   >>> LO ESCRIBEN USTEDES <<<
//
// Parametrizable en ancho: el mismo modulo sirve para 32 bits o para 5. Por
// eso los puertos se declaran con W y no con un numero. No cambien la cabecera.
//
//   sel = 0  ->  y = d0
//   sel = 1  ->  y = d1
//
// Una sola linea.
// =============================================================================
module mux2 #(
    parameter int W = 32
)(
    input  logic [W-1:0] d0,
    input  logic [W-1:0] d1,
    input  logic         sel,
    output logic [W-1:0] y
);

    assign y = sel ? d1 : d0;

endmodule
