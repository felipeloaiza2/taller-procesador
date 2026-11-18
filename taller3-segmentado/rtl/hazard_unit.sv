// =============================================================================
// hazard_unit.sv - Unidad de deteccion de riesgos     >>> TALLER 3, FASE 3 <<<
//
// Vive en ID (mira IF/ID e ID/EX). Combinacional pura. Hace DOS trabajos:
//
//  1. load-use: la de EX es un load y la de ID lee el registro que ese load va
//     a escribir (por rs1 o por rs2). El dato sale de la memoria al final de
//     MEM y la ALU lo necesita al principio de EX: ningun cable lo arregla.
//     Se retrasa UN ciclo a la dependiente y despues el forwarding de siempre
//     (camino 01 desde MEM/WB) la cubre.
//        StallF  congela el PC          (se vuelve a buscar la misma instruccion)
//        StallD  congela IF/ID          (la dependiente se queda en ID)
//        FlushE  vacia ID/EX            (entra una burbuja en EX)
//     Las TRES van juntas: cada una sin las otras rompe el programa.
//
//  2. salto tomado: PCSrcE = 1 en EX. Las dos instrucciones que entraron detras
//     sobran:
//        FlushD  vacia IF/ID            (mata la que venia en IF)
//        FlushE  vacia ID/EX            (mata la que estaba en ID)
//
// Las dos causas NO pueden coincidir: una exige un load en EX, la otra un salto.
//
// CUIDADO con la condicion del load. Harris & Harris comparan solo el bit 0 de
// ResultSrcE. Aqui ResultSrc tambien vale 11 (lui), que tiene el bit 0 a uno:
// con la version del libro, lui seguido de un uso de su rd pararia de mas.
// Se comparan los DOS bits contra 01 (RES_MEM).
// =============================================================================
module hazard_unit (
    input  logic [4:0] rs1_d,
    input  logic [4:0] rs2_d,
    input  logic [4:0] rd_e,
    input  logic [1:0] result_src_e,
    input  logic       pc_src_e,

    output logic       stall_f,
    output logic       stall_d,
    output logic       flush_d,
    output logic       flush_e
);

    import riscv_pkg::*;

    logic lw_stall;

    assign lw_stall = (result_src_e == RES_MEM) && ((rs1_d == rd_e) || (rs2_d == rd_e));

    assign stall_f = lw_stall;
    assign stall_d = lw_stall;
    assign flush_d = pc_src_e;
    assign flush_e = lw_stall | pc_src_e;

endmodule
