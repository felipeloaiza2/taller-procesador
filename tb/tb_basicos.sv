// =============================================================================
// tb_basicos.sv - Banco de pruebas del sumador y los dos multiplexores
//
// Se entrega hecho. No hay que tocarlo: hay que hacer que pase.
//
// Doce comprobaciones:
//   adder   cuatro sumas, una de ellas con desborde: 0xFFFFFFFF + 2 da 1,
//           porque el acarreo de salida no existe.
//   mux2    las dos entradas, en DOS instancias: una de 32 bits y otra de 5.
//           La de 5 bits comprueba que el parametro W de verdad cambia el
//           ancho, que es para lo que existe.
//   mux4    las cuatro entradas.
//
// Todos los datos son distintos de cero y distintos entre si: un modulo que
// saque siempre cero, o siempre la misma entrada, no puede pasar.
// =============================================================================
`timescale 1ns/1ps

module tb_basicos;

    // --- adder ---
    logic [31:0] a, b, suma;

    // --- mux2 de 32 bits ---
    logic [31:0] m2_d0, m2_d1, m2_y;
    logic        m2_sel;

    // --- mux2 de 5 bits, como el que eligiria un numero de registro ---
    logic [4:0]  m5_d0, m5_d1, m5_y;
    logic        m5_sel;

    // --- mux4 ---
    logic [31:0] m4_d00, m4_d01, m4_d10, m4_d11, m4_y;
    logic [1:0]  m4_sel;

    int pruebas;
    int errores;

    adder dut_adder (
        .a (a),
        .b (b),
        .y (suma)
    );

    mux2 #(.W (32)) dut_mux2 (
        .d0  (m2_d0),
        .d1  (m2_d1),
        .sel (m2_sel),
        .y   (m2_y)
    );

    mux2 #(.W (5)) dut_mux2_5 (
        .d0  (m5_d0),
        .d1  (m5_d1),
        .sel (m5_sel),
        .y   (m5_y)
    );

    mux4 #(.W (32)) dut_mux4 (
        .d00 (m4_d00),
        .d01 (m4_d01),
        .d10 (m4_d10),
        .d11 (m4_d11),
        .sel (m4_sel),
        .y   (m4_y)
    );

    task automatic comprueba(input string       nombre,
                             input logic [31:0] obtenido,
                             input logic [31:0] esperado);
        pruebas = pruebas + 1;
        if (obtenido !== esperado) begin
            errores = errores + 1;
            $display("  FALLO %-24s obtenido=%h  esperado=%h", nombre, obtenido, esperado);
        end
    endtask

    initial begin
        $dumpfile("build/tb_basicos.vcd");
        $dumpvars(0, tb_basicos);

        pruebas = 0;
        errores = 0;

        // --- adder ---
        a = 32'd5;          b = 32'd7;           #1;
        comprueba("adder 5 + 7",          suma, 32'd12);
        a = 32'd10;         b = -32'sd3;         #1;
        comprueba("adder 10 + (-3)",      suma, 32'd7);
        a = 32'h7fffffff;   b = 32'd1;           #1;
        comprueba("adder 0x7FFFFFFF + 1", suma, 32'h80000000);
        a = 32'hffffffff;   b = 32'd2;           #1;
        comprueba("adder desborde",       suma, 32'h00000001);

        // --- mux2 de 32 bits ---
        m2_d0 = 32'h0000_0a0a;  m2_d1 = 32'hb0b0_0000;
        m2_sel = 1'b0;  #1;
        comprueba("mux2 sel=0",           m2_y, 32'h0000_0a0a);
        m2_sel = 1'b1;  #1;
        comprueba("mux2 sel=1",           m2_y, 32'hb0b0_0000);

        // --- mux2 de 5 bits ---
        m5_d0 = 5'b10101;  m5_d1 = 5'b01110;
        m5_sel = 1'b0;  #1;
        comprueba("mux2 W=5 sel=0",       {27'd0, m5_y}, 32'h15);
        m5_sel = 1'b1;  #1;
        comprueba("mux2 W=5 sel=1",       {27'd0, m5_y}, 32'h0e);

        // --- mux4 ---
        m4_d00 = 32'h1111_0000;  m4_d01 = 32'h0000_2222;
        m4_d10 = 32'h3300_0033;  m4_d11 = 32'h0044_4400;
        m4_sel = 2'b00;  #1;
        comprueba("mux4 sel=00",          m4_y, 32'h1111_0000);
        m4_sel = 2'b01;  #1;
        comprueba("mux4 sel=01",          m4_y, 32'h0000_2222);
        m4_sel = 2'b10;  #1;
        comprueba("mux4 sel=10",          m4_y, 32'h3300_0033);
        m4_sel = 2'b11;  #1;
        comprueba("mux4 sel=11",          m4_y, 32'h0044_4400);

        $display("--------------------------------------------------");
        $display("pruebas: %0d    errores: %0d", pruebas, errores);
        if (errores == 0) $display("tb_basicos: PASS");
        else              $display("tb_basicos: FAIL");
        $display("--------------------------------------------------");

        $finish;
    end

endmodule
