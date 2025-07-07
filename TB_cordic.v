`timescale 1ns/1ps

module tb_cordic;

    // Parâmetros
    parameter WIDTH = 32;
    parameter ITERATIONS = 16;

    // Entradas
    reg clk;
    reg rst;
    reg enable;
    reg mode_op;     // 0 = ROTATION
    reg [1:0] mode_coord;  // 1 = CIRCULAR
    reg signed [WIDTH-1:0] x_in, y_in, z_in;

    // Saídas
    wire signed [WIDTH-1:0] x_out, y_out, z_out;
    wire valid;

    // Instância do módulo CORDIC
    cordic #(
        .WIDTH(WIDTH),
        .ITERATIONS(ITERATIONS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .mode_op(mode_op),
        .mode_coord(mode_coord),
        .x_in(x_in),
        .y_in(y_in),
        .z_in(z_in),
        .x_out(x_out),
        .y_out(y_out),
        .z_out(z_out),
        .valid(valid)
    );

    // Clock
    always #5 clk = ~clk;

    // Conversão Q16.16 para ponto flutuante (em real)
    real real_x, real_y, real_z;
    real scale;
    initial scale = 65536.0;

    initial begin
        // Inicialização
        clk = 0;
        rst = 1;
        enable = 0;
        mode_op = 1'b0;      // ROTATION
        mode_coord = 2'b01;   // CIRCULAR
        x_in = 0;
        y_in = 0;
        z_in = 0;

        #20;
        rst = 0;

        // Entradas para calcular sin/cos(45°) sem compensação (já feita no módulo)
        x_in = 32'd65536;    // 1.0 em Q16.16
        y_in = 32'd0;
        z_in = 32'd51472;    // 0.785398 rad ≈ 45° em Q16.16

        enable = 1;
        #10 enable = 0;

        // Espera saída válida
        wait (valid == 1);
        #10;

        // Converte para ponto flutuante
        real_x = $itor(x_out) / scale;
        real_y = $itor(y_out) / scale;
        real_z = $itor(z_out) / scale;

        $display("=== Resultado CORDIC (45 graus) ===");
        $display("cos(45°) ≈ %f", real_x);
        $display("sin(45°) ≈ %f", real_y);
        $display("z_final  ≈ %f", real_z);

        #10 $stop;
    end

endmodule
