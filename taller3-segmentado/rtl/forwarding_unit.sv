// =============================================================================
// forwarding_unit.sv - Unidad de forwarding     >>> TALLER 3, FASE 2 <<<
//
// Vive en EX. Es combinacional pura: sin reloj, sin estado. NO ve datos: solo
// numeros de registro y dos bits de control.
//
// Para cada operando de la ALU decide de donde sacar el valor bueno:
//
//   forward = 2'b00   del banco de registros (RD1E / RD2E), como siempre
//   forward = 2'b10   del registro EX/MEM  (la instruccion una posicion por delante)
//   forward = 2'b01   del registro MEM/WB  (la instruccion dos posiciones por delante)
//
// La regla: si el registro que voy a leer coincide con el que escribe una
// instruccion que llevo delante, tomo su valor; si coinciden las dos, gana la
// MAS CERCANA (EX/MEM). El orden if / else if ES la prioridad.
//
// Los tres detalles que no se pueden omitir (seccion 7 de la guia):
//   1. rs != 0   x0 nunca se adelanta (un nop o cualquier rd = x0 mentiria).
//   2. RegWrite  la de delante tiene que escribir DE VERDAD. En un sw/beq los
//                bits 11:7 son del inmediato y parecen un rd.
//   3. prioridad EX/MEM antes que MEM/WB.
//
// ForwardBE es la MISMA logica con rs2E: por eso hay dos bloques identicos.
// =============================================================================
module forwarding_unit (
    input  logic [4:0] rs1_e,
    input  logic [4:0] rs2_e,
    input  logic [4:0] rd_m,
    input  logic [4:0] rd_w,
    input  logic       reg_write_m,
    input  logic       reg_write_w,
    output logic [1:0] forward_a_e,
    output logic [1:0] forward_b_e
);

    // Operando A (rs1)
    always_comb begin
        forward_a_e = 2'b00;
        if      ((rs1_e != 5'd0) && reg_write_m && (rd_m == rs1_e)) forward_a_e = 2'b10;
        else if ((rs1_e != 5'd0) && reg_write_w && (rd_w == rs1_e)) forward_a_e = 2'b01;
    end

    // Operando B (rs2): identico, cambiando rs1_e por rs2_e
    always_comb begin
        forward_b_e = 2'b00;
        if      ((rs2_e != 5'd0) && reg_write_m && (rd_m == rs2_e)) forward_b_e = 2'b10;
        else if ((rs2_e != 5'd0) && reg_write_w && (rd_w == rs2_e)) forward_b_e = 2'b01;
    end

endmodule
