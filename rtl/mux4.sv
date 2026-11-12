// =============================================================================
// mux4.sv - Multiplexor de 4 a 1                   >>> LO ESCRIBEN USTEDES <<<
//
// Parametrizable en ancho, como mux2.
//
//   sel = 00 -> d00     sel = 01 -> d01     sel = 10 -> d10     sel = 11 -> d11
//
// Se escribe con always_comb y un case. Las dos protecciones ya estan puestas:
// la asignacion por defecto antes del case y la rama default. Con sel de 2
// bits las cuatro ramas cubren todos los valores, pero sel puede valer x en
// simulacion, y el default esta para eso.
// =============================================================================
module mux4 #(
    parameter int W = 32
)(
    input  logic [W-1:0] d00,
    input  logic [W-1:0] d01,
    input  logic [W-1:0] d10,
    input  logic [W-1:0] d11,
    input  logic [1:0]   sel,
    output logic [W-1:0] y
);

    always_comb begin
        y = '0;

        case (sel)
            2'b00:   y = d00;
            2'b01:   y = d01;
            2'b10:   y = d10;
            2'b11:   y = d11;
            default: y = '0;
        endcase
    end

endmodule
