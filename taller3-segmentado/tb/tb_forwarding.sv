// =============================================================================
// tb_forwarding.sv - Prueba de la unidad de forwarding, ella sola
//
// 1. Las ocho filas de la tabla de la seccion 6, para el operando A y para el B.
// 2. Un barrido exhaustivo (1600 combinaciones) contra un modelo de referencia
//    escrito aparte, que comprueba A y B a la vez con registros DISTINTOS en
//    rs1 y rs2 (asi se delata que A y B esten cruzados o que falte uno).
// =============================================================================
`timescale 1ns/1ps

module tb_forwarding;

    logic [4:0] rs1_e, rs2_e, rd_m, rd_w;
    logic       reg_write_m, reg_write_w;
    logic [1:0] forward_a_e, forward_b_e;

    int pruebas, errores;

    forwarding_unit dut (
        .rs1_e       (rs1_e),
        .rs2_e       (rs2_e),
        .rd_m        (rd_m),
        .rd_w        (rd_w),
        .reg_write_m (reg_write_m),
        .reg_write_w (reg_write_w),
        .forward_a_e (forward_a_e),
        .forward_b_e (forward_b_e)
    );

    task automatic comprobar(input string nota, input logic [1:0] obtenido, input logic [1:0] esperado);
        pruebas++;
        if (obtenido !== esperado) begin
            errores++;
            $display("  FALLO %-44s obtenido=%02b  esperado=%02b", nota, obtenido, esperado);
        end
    endtask

    // Una fila de la tabla: el mismo registro fuente en rs1 y en rs2
    task automatic fila(input string nota, input logic [4:0] rs, input logic [4:0] rdm, input logic rwm,
                        input logic [4:0] rdw, input logic rww, input logic [1:0] esperado);
        rs1_e = rs; rs2_e = rs; rd_m = rdm; reg_write_m = rwm; rd_w = rdw; reg_write_w = rww;
        #1;
        comprobar($sformatf("%s (A)", nota), forward_a_e, esperado);
        comprobar($sformatf("%s (B)", nota), forward_b_e, esperado);
    endtask

    // Modelo de referencia, escrito por separado
    function automatic logic [1:0] gold(input logic [4:0] rs, input logic [4:0] rdm, input logic rwm,
                                        input logic [4:0] rdw, input logic rww);
        logic coincide_m, coincide_w;
        coincide_m = (rs != 5'd0) && rwm && (rdm == rs);
        coincide_w = (rs != 5'd0) && rww && (rdw == rs);
        if (coincide_m)      return 2'b10;
        else if (coincide_w) return 2'b01;
        else                 return 2'b00;
    endfunction

    logic [4:0] regs [0:3];
    logic [4:0] dst  [0:4];

    initial begin
        pruebas = 0; errores = 0;

        //   nota                                      rs  rdM rwM  rdW rwW  salida
        fila("nadie escribe ese registro",             5,  7,  1,   8,  1,   2'b00);
        fila("la de delante escribe x5",               5,  5,  1,   8,  1,   2'b10);
        fila("la de dos por delante escribe x5",       5,  7,  1,   5,  1,   2'b01);
        fila("las dos: gana la mas cercana",           5,  5,  1,   5,  1,   2'b10);
        fila("coincide pero no escribe (sw)",          5,  5,  0,   8,  1,   2'b00);
        fila("coincide pero no escribe (branch)",      5,  7,  1,   5,  0,   2'b00);
        fila("el operando es x0: nunca se adelanta",   0,  0,  1,   0,  1,   2'b00);
        fila("x31: se comparan los cinco bits",       31, 31,  1,   8,  1,   2'b10);

        // Casos extra que la tabla no escribe pero la seccion 7 exige
        fila("M no escribe y W si: cae a W",           5,  5,  0,   5,  1,   2'b01);
        fila("W escribe x0 y rs es x0",                0,  7,  1,   0,  1,   2'b00);
        fila("solo difiere el bit 4",                 21,  5,  1,   5,  1,   2'b00);
        fila("solo difiere el bit 0",                  4,  5,  1,   5,  1,   2'b00);

        // A y B con registros distintos: no pueden estar cruzados
        rs1_e = 5'd5; rs2_e = 5'd6; rd_m = 5'd5; reg_write_m = 1; rd_w = 5'd6; reg_write_w = 1; #1;
        comprobar("A=EX/MEM, B=MEM/WB a la vez (A)", forward_a_e, 2'b10);
        comprobar("A=EX/MEM, B=MEM/WB a la vez (B)", forward_b_e, 2'b01);
        rs1_e = 5'd6; rs2_e = 5'd5; #1;
        comprobar("A=MEM/WB, B=EX/MEM a la vez (A)", forward_a_e, 2'b01);
        comprobar("A=MEM/WB, B=EX/MEM a la vez (B)", forward_b_e, 2'b10);
        rs1_e = 5'd5; rs2_e = 5'd9; #1;
        comprobar("solo A coincide (B se queda en 00)", forward_b_e, 2'b00);
        rs1_e = 5'd9; rs2_e = 5'd5; #1;
        comprobar("solo B coincide (A se queda en 00)", forward_a_e, 2'b00);

        // Barrido exhaustivo
        regs[0] = 0; regs[1] = 5; regs[2] = 7; regs[3] = 31;
        dst[0] = 0; dst[1] = 5; dst[2] = 7; dst[3] = 8; dst[4] = 31;
        for (int a = 0; a < 4; a++)
        for (int b = 0; b < 4; b++)
        for (int m = 0; m < 5; m++)
        for (int w = 0; w < 5; w++)
        for (int rm = 0; rm < 2; rm++)
        for (int rw = 0; rw < 2; rw++) begin
            rs1_e = regs[a]; rs2_e = regs[b]; rd_m = dst[m]; rd_w = dst[w];
            reg_write_m = (rm == 1); reg_write_w = (rw == 1);
            #1;
            comprobar($sformatf("barrido A rs=%0d rdM=%0d/%0d rdW=%0d/%0d", regs[a], dst[m], rm, dst[w], rw),
                      forward_a_e, gold(regs[a], dst[m], (rm == 1), dst[w], (rw == 1)));
            comprobar($sformatf("barrido B rs=%0d rdM=%0d/%0d rdW=%0d/%0d", regs[b], dst[m], rm, dst[w], rw),
                      forward_b_e, gold(regs[b], dst[m], (rm == 1), dst[w], (rw == 1)));
        end

        $display("--------------------------------------------------");
        $display("pruebas: %0d    errores: %0d", pruebas, errores);
        if (errores == 0) $display("tb_forwarding: PASS");
        else              $display("tb_forwarding: FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
