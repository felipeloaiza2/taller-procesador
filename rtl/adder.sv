// =============================================================================
// adder.sv - Sumador de 32 bits                    >>> LO ESCRIBEN USTEDES <<<
//
// Sin acarreo de entrada ni de salida: el bit 32 de la suma se pierde, igual
// que en la ALU. Una sola linea.
//
// Se instancia DOS veces en el datapath:
//   - PC + 4            el siguiente secuencial
//   - PC + ImmExt       el destino de un salto
//
// Ninguno de los dos lo calcula la ALU. La ALU esta ocupada con el operando de
// la instruccion, y en un monociclo no se puede usar dos veces en el mismo
// ciclo.
// =============================================================================
module adder (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] y
);

    assign y = a + b;

endmodule
