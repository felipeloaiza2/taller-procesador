// =============================================================================
// tb_ciclos.sv - Cuantos ciclos tarda cada programa en el segmentado
//
// GENERADO con tools/gen_tb_seg.py. Cuenta ciclos desde que se suelta el reset
// (el ciclo 1 es aquel en que se busca la instruccion de la direccion 0) hasta
// que el beq final del programa ("fin: beq x0, x0, fin") se retira.
//
// Ese beq esta en EX cuando pc_e vale la direccion de "fin" (en EX no puede
// haber instrucciones del camino equivocado: ya se vaciaron). Le faltan dos
// ciclos (MEM y WB) para retirarse, y por eso el total es ciclo_en_EX + 2.
//
// Compara contra lo que predice el modelo de Python y contra el monociclo
// (que tarda un ciclo por instruccion ejecutada).
// =============================================================================
`timescale 1ns/1ps

module tb_ciclos;

    logic clk, rst, en;

    riscv_segmentado #(.INIT_FILE("prog/humo.hex")) cpu_humo (.clk(clk), .rst(rst), .en(en));
    int c_humo, tot_humo;  bit hecho_humo;
    riscv_segmentado #(.INIT_FILE("prog/completo.hex")) cpu_completo (.clk(clk), .rst(rst), .en(en));
    int c_completo, tot_completo;  bit hecho_completo;
    riscv_segmentado #(.INIT_FILE("prog/bytes.hex")) cpu_bytes (.clk(clk), .rst(rst), .en(en));
    int c_bytes, tot_bytes;  bit hecho_bytes;
    riscv_segmentado #(.INIT_FILE("prog/seg_fwd.hex")) cpu_seg_fwd (.clk(clk), .rst(rst), .en(en));
    int c_seg_fwd, tot_seg_fwd;  bit hecho_seg_fwd;
    riscv_segmentado #(.INIT_FILE("prog/seg_carga.hex")) cpu_seg_carga (.clk(clk), .rst(rst), .en(en));
    int c_seg_carga, tot_seg_carga;  bit hecho_seg_carga;
    riscv_segmentado #(.INIT_FILE("prog/seg_saltos.hex")) cpu_seg_saltos (.clk(clk), .rst(rst), .en(en));
    int c_seg_saltos, tot_seg_saltos;  bit hecho_seg_saltos;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin

        c_humo = 0; tot_humo = 0; hecho_humo = 1'b0;
        c_completo = 0; tot_completo = 0; hecho_completo = 1'b0;
        c_bytes = 0; tot_bytes = 0; hecho_bytes = 1'b0;
        c_seg_fwd = 0; tot_seg_fwd = 0; hecho_seg_fwd = 1'b0;
        c_seg_carga = 0; tot_seg_carga = 0; hecho_seg_carga = 1'b0;
        c_seg_saltos = 0; tot_seg_saltos = 0; hecho_seg_saltos = 1'b0;
    end

    // Un contador por programa: cuenta el ciclo que acaba de terminar
    always @(posedge clk) begin
        if (!rst) begin
            if (!hecho_humo) begin
                c_humo = c_humo + 1;
                if (cpu_humo.pc_e === 32'h00000010) begin hecho_humo = 1'b1; tot_humo = c_humo + 2; end
            end
            if (!hecho_completo) begin
                c_completo = c_completo + 1;
                if (cpu_completo.pc_e === 32'h00000058) begin hecho_completo = 1'b1; tot_completo = c_completo + 2; end
            end
            if (!hecho_bytes) begin
                c_bytes = c_bytes + 1;
                if (cpu_bytes.pc_e === 32'h0000003c) begin hecho_bytes = 1'b1; tot_bytes = c_bytes + 2; end
            end
            if (!hecho_seg_fwd) begin
                c_seg_fwd = c_seg_fwd + 1;
                if (cpu_seg_fwd.pc_e === 32'h000000a4) begin hecho_seg_fwd = 1'b1; tot_seg_fwd = c_seg_fwd + 2; end
            end
            if (!hecho_seg_carga) begin
                c_seg_carga = c_seg_carga + 1;
                if (cpu_seg_carga.pc_e === 32'h0000007c) begin hecho_seg_carga = 1'b1; tot_seg_carga = c_seg_carga + 2; end
            end
            if (!hecho_seg_saltos) begin
                c_seg_saltos = c_seg_saltos + 1;
                if (cpu_seg_saltos.pc_e === 32'h00000074) begin hecho_seg_saltos = 1'b1; tot_seg_saltos = c_seg_saltos + 2; end
            end
        end
    end

    task automatic informar(input string nombre, input int mono, input int modelo_c, input int medido, input bit hecho);
        $display("  %-11s %9d %11d %9d    %s", nombre, mono, medido, modelo_c,
                 (!hecho) ? "NO TERMINO" : (medido == modelo_c) ? "coincide" : "DIFERENTE");
    endtask

    initial begin
        en = 1'b1; rst = 1'b1;
        repeat (2) @(posedge clk);
        #1 rst = 1'b0;
        repeat (300) @(posedge clk);
        #1;
        $display("--------------------------------------------------------");
        $display("  programa    monociclo  segmentado    modelo    estado");
        informar("humo", 5, 9, tot_humo, hecho_humo);
        informar("completo", 24, 34, tot_completo, hecho_completo);
        informar("bytes", 16, 20, tot_bytes, hecho_bytes);
        informar("seg_fwd", 42, 48, tot_seg_fwd, hecho_seg_fwd);
        informar("seg_carga", 30, 44, tot_seg_carga, hecho_seg_carga);
        informar("seg_saltos", 50, 82, tot_seg_saltos, hecho_seg_saltos);
        $display("--------------------------------------------------------");
        $display("  monociclo = instrucciones ejecutadas (1 ciclo cada una)");
        $finish;
    end

endmodule
