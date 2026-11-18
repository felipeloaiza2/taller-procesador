// =============================================================================
// tb_cpu.sv - Banco de pruebas del procesador entero
//
// Se entrega hecho. No hay que tocarlo: hay que hacer que pase.
//
// Instancia TRES procesadores, uno por programa, con el mismo reloj. Cada uno
// carga su propio .hex en su memoria de instrucciones, corre 200 ciclos y
// despues se le miran los registros y la memoria.
//
//   cpu_humo       5 instrucciones. Si esto falla, el cableado esta mal.
//   cpu_completo   los nueve grupos del ISA del curso.
//   cpu_bytes      los accesos de byte y de media palabra.
//
// Llega a los registros por REFERENCIA JERARQUICA: cpu_humo.rf.regs[3]. En
// hardware no existe; en simulacion es legal y es la unica forma de ver dentro
// sin sacar cables de depuracion. Por eso las instancias de tu
// riscv_monociclo.sv TIENEN que llamarse rf y dmem.
// =============================================================================
`timescale 1ns/1ps

module tb_cpu;

    localparam int CICLOS = 200;

    logic clk;
    logic rst;
    logic en;

    int pruebas;
    int errores;

    riscv_monociclo #(.INIT_FILE("prog/humo.hex"))     cpu_humo     (.clk(clk), .rst(rst), .en(en));
    riscv_monociclo #(.INIT_FILE("prog/completo.hex")) cpu_completo (.clk(clk), .rst(rst), .en(en));
    riscv_monociclo #(.INIT_FILE("prog/bytes.hex"))    cpu_bytes    (.clk(clk), .rst(rst), .en(en));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic comprobar(input string       programa,
                             input string       nota,
                             input logic [31:0] obtenido,
                             input logic [31:0] esperado);
        pruebas = pruebas + 1;
        if (obtenido !== esperado) begin
            errores = errores + 1;
            $display("  FALLO [%-8s] %-36s obtenido=0x%08h  esperado=0x%08h",
                     programa, nota, obtenido, esperado);
        end
    endtask

    initial begin
        $dumpfile("build/tb_cpu.vcd");
        $dumpvars(0, tb_cpu);

        pruebas = 0;
        errores = 0;

        en  = 1'b1;
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst = 1'b0;

        repeat (CICLOS) @(posedge clk);
        #1;

        // ---------------------------------------------------------------------
        // humo.s - addi, add, sw, beq
        // ---------------------------------------------------------------------
        comprobar("humo", "addi x1, x0, 5",        cpu_humo.rf.regs[1],  32'd5);
        comprobar("humo", "addi x2, x0, 10",       cpu_humo.rf.regs[2],  32'd10);
        comprobar("humo", "add  x3, x1, x2",       cpu_humo.rf.regs[3],  32'd15);
        comprobar("humo", "sw   x3, 0(x0)",        cpu_humo.dmem.mem[0], 32'd15);

        // ---------------------------------------------------------------------
        // completo.s - los nueve grupos
        //
        // x1 acaba en 0x4C y no en 5: "jal ra, duplica" escribe PC+4 en ra, y
        // ra ES x1. No es un fallo del procesador, es por que ra es
        // caller-saved.
        // ---------------------------------------------------------------------
        comprobar("completo", "ra tras jal (x1 == ra)",      cpu_completo.rf.regs[1],  32'h0000004C);
        comprobar("completo", "addi x2, x0, 10",             cpu_completo.rf.regs[2],  32'd10);
        comprobar("completo", "add  x3, x1, x2",             cpu_completo.rf.regs[3],  32'd15);
        comprobar("completo", "sub  x4, x2, x1",             cpu_completo.rf.regs[4],  32'd5);
        comprobar("completo", "and  x5, x1, x2",             cpu_completo.rf.regs[5],  32'd0);
        comprobar("completo", "or   x6, x1, x2",             cpu_completo.rf.regs[6],  32'd15);
        comprobar("completo", "xor  x7, x1, x2",             cpu_completo.rf.regs[7],  32'd15);
        comprobar("completo", "slt  x8, x1, x2",             cpu_completo.rf.regs[8],  32'd1);
        comprobar("completo", "lw   x9, 0(x0)",              cpu_completo.rf.regs[9],  32'd15);
        comprobar("completo", "sw   x3, 0(x0)",              cpu_completo.dmem.mem[0], 32'd15);
        comprobar("completo", "branch no tomado: x10 = 1",   cpu_completo.rf.regs[10], 32'd1);
        comprobar("completo", "branch tomado: x11 = 2",      cpu_completo.rf.regs[11], 32'd2);
        comprobar("completo", "addi x12, x0, 3",             cpu_completo.rf.regs[12], 32'd3);
        comprobar("completo", "lui  x13, 0x12345",           cpu_completo.rf.regs[13], 32'h12345000);
        comprobar("completo", "jal duplica + jalr ret",      cpu_completo.rf.regs[14], 32'd40);

        // Si al decodificador de la ALU le falta el termino op[5], el
        // "addi x15, x0, -1" se ejecuta como resta y esta fila falla.
        comprobar("completo", "sltu (detecta el bug de op[5])", cpu_completo.rf.regs[15], 32'd1);
        comprobar("completo", "x0 cableado a cero",          cpu_completo.rf.regs[0],  32'd0);

        // ---------------------------------------------------------------------
        // bytes.s - los accesos de byte y de media palabra
        // ---------------------------------------------------------------------
        comprobar("bytes", "lui + addi = 0xDEADBEEF",  cpu_bytes.rf.regs[2],  32'hDEADBEEF);
        comprobar("bytes", "lb  con signo",            cpu_bytes.rf.regs[3],  32'hFFFFFFEF);
        comprobar("bytes", "lbu sin signo",            cpu_bytes.rf.regs[4],  32'h000000EF);
        comprobar("bytes", "lh  con signo",            cpu_bytes.rf.regs[5],  32'hFFFFBEEF);
        comprobar("bytes", "lhu sin signo",            cpu_bytes.rf.regs[6],  32'h0000BEEF);
        comprobar("bytes", "sb sin pisar los vecinos", cpu_bytes.rf.regs[8],  32'hDEAD55EF);
        comprobar("bytes", "sh sin pisar los vecinos", cpu_bytes.rf.regs[10], 32'h012355EF);
        comprobar("bytes", "lhu de la media alta",     cpu_bytes.rf.regs[11], 32'h00000123);
        comprobar("bytes", "la fila tras sb y sh",     cpu_bytes.dmem.mem[0], 32'h012355EF);

        $display("--------------------------------------------------");
        $display("pruebas: %0d    errores: %0d", pruebas, errores);
        if (errores == 0) $display("tb_cpu: PASS");
        else              $display("tb_cpu: FAIL");
        $display("--------------------------------------------------");

        $finish;
    end

endmodule
