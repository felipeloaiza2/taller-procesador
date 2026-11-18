// =============================================================================
// pipe_reg.sv - Registro de segmentacion     >>> TALLER 3, FASE 1 <<<
//
// Un flip-flop D de ancho W con los TRES puertos que hacen falta para segmentar:
//
//   d / q  carga sincrona: en el flanco, q toma d.
//   en     habilitacion: con en = 0 el registro se queda quieto. Sin esto no se
//          puede parar el frente del pipeline (StallF / StallD).
//   clr    borrado sincrono: en el flanco, q pasa a cero. Sin esto no se puede
//          meter una burbuja (FlushD / FlushE) ni matar una instruccion.
//
// PRIORIDAD: clr gana sobre en. Un borrado siempre debe ejecutarse, incluso si
// ese mismo ciclo el registro esta "parado".
//
// El reset del procesador entra por clr (el nivel superior hace rst | flush):
// asi el registro arranca en cero y las senales de control arrancan en 0, que
// es una burbuja, no en X.
//
// Es el mismo modulo para los cuatro registros: IF/ID, ID/EX, EX/MEM, MEM/WB.
// Cambia W y lo que se concatena en d.
// =============================================================================
module pipe_reg #(
    parameter int W = 32
)(
    input  logic         clk,
    input  logic         en,
    input  logic         clr,
    input  logic [W-1:0] d,
    output logic [W-1:0] q
);

    always_ff @(posedge clk) begin
        if (clr)     q <= '0;
        else if (en) q <= d;
    end

endmodule
