// =============================================================================
// tb_hazard.sv - Prueba de la unidad de deteccion de riesgos, ella sola
//
// 1. Las ocho filas de la tabla de la seccion 12.
// 2. El caso que NINGUN programa delata: ResultSrcE = 11 (lui) con una
//    dependencia NO debe parar. Una parada de mas no cambia el resultado de un
//    programa; solo esta prueba, dirigida a la unidad, lo caza.
// 3. Un barrido exhaustivo (512 combinaciones) y las invariantes: StallF y
//    StallD siempre iguales; FlushD solo por salto; las dos causas no coinciden.
// =============================================================================
`timescale 1ns/1ps

module tb_hazard;

    logic [4:0] rs1_d, rs2_d, rd_e;
    logic [1:0] result_src_e;
    logic       pc_src_e;
    logic       stall_f, stall_d, flush_d, flush_e;

    int pruebas, errores;

    hazard_unit dut (
        .rs1_d        (rs1_d),
        .rs2_d        (rs2_d),
        .rd_e         (rd_e),
        .result_src_e (result_src_e),
        .pc_src_e     (pc_src_e),
        .stall_f      (stall_f),
        .stall_d      (stall_d),
        .flush_d      (flush_d),
        .flush_e      (flush_e)
    );

    task automatic comprobar(input string nota, input logic obtenido, input logic esperado);
        pruebas++;
        if (obtenido !== esperado) begin
            errores++;
            $display("  FALLO %-50s obtenido=%0b  esperado=%0b", nota, obtenido, esperado);
        end
    endtask

    task automatic fila(input string nota, input logic [4:0] r1, input logic [4:0] r2, input logic [4:0] re,
                        input logic [1:0] rs, input logic pc, input logic sf, input logic sd,
                        input logic fd, input logic fe);
        rs1_d = r1; rs2_d = r2; rd_e = re; result_src_e = rs; pc_src_e = pc;
        #1;
        comprobar($sformatf("%s StallF", nota), stall_f, sf);
        comprobar($sformatf("%s StallD", nota), stall_d, sd);
        comprobar($sformatf("%s FlushD", nota), flush_d, fd);
        comprobar($sformatf("%s FlushE", nota), flush_e, fe);
    endtask

    logic [4:0] reg5 [0:3];

    initial begin
        pruebas = 0; errores = 0;

        //   nota                                  rs1 rs2 rdE  res  pc   sF sD fD fE
        fila("nada que detectar",                   5,  6,  7, 2'b00, 0,   0, 0, 0, 0);
        fila("depende de un add: lo cubre fwd",     5,  6,  5, 2'b00, 0,   0, 0, 0, 0);
        fila("load-use por rs1",                    5,  6,  5, 2'b01, 0,   1, 1, 0, 1);
        fila("load-use por rs2",                    5,  6,  6, 2'b01, 0,   1, 1, 0, 1);
        fila("un lw pero a otro registro",          5,  6,  7, 2'b01, 0,   0, 0, 0, 0);
        fila("jal: su PC+4 ya existe",              5,  6,  5, 2'b10, 0,   0, 0, 0, 0);
        fila("lui: mirar solo el bit 0 pararia",    5,  6,  5, 2'b11, 0,   0, 0, 0, 0);
        fila("salto tomado",                        5,  6,  7, 2'b00, 1,   0, 0, 1, 1);

        // Extras
        fila("lui con dependencia por rs2",         5,  6,  6, 2'b11, 0,   0, 0, 0, 0);
        fila("load-use con los dos operandos",      5,  5,  5, 2'b01, 0,   1, 1, 0, 1);
        fila("salto tomado con dependencia de add", 5,  6,  5, 2'b00, 1,   0, 0, 1, 1);
        fila("jal tomado (res=10, pc_src=1)",       5,  6,  7, 2'b10, 1,   0, 0, 1, 1);

        // Barrido exhaustivo
        reg5[0] = 0; reg5[1] = 5; reg5[2] = 6; reg5[3] = 7;
        for (int a = 0; a < 4; a++)
        for (int b = 0; b < 4; b++)
        for (int c = 0; c < 4; c++)
        for (int s = 0; s < 4; s++)
        for (int p = 0; p < 2; p++) begin
            logic lw;
            rs1_d = reg5[a]; rs2_d = reg5[b]; rd_e = reg5[c]; result_src_e = s[1:0]; pc_src_e = (p == 1);
            #1;
            lw = (s == 1) && ((reg5[a] == reg5[c]) || (reg5[b] == reg5[c]));
            comprobar($sformatf("barrido StallF a=%0d b=%0d c=%0d s=%0d p=%0d", reg5[a], reg5[b], reg5[c], s, p), stall_f, lw);
            comprobar($sformatf("barrido StallD a=%0d b=%0d c=%0d s=%0d p=%0d", reg5[a], reg5[b], reg5[c], s, p), stall_d, lw);
            comprobar($sformatf("barrido FlushD a=%0d b=%0d c=%0d s=%0d p=%0d", reg5[a], reg5[b], reg5[c], s, p), flush_d, (p == 1));
            comprobar($sformatf("barrido FlushE a=%0d b=%0d c=%0d s=%0d p=%0d", reg5[a], reg5[b], reg5[c], s, p), flush_e, lw | (p == 1));
        end

        $display("--------------------------------------------------");
        $display("pruebas: %0d    errores: %0d", pruebas, errores);
        if (errores == 0) $display("tb_hazard: PASS");
        else              $display("tb_hazard: FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
