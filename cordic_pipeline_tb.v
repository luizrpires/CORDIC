`timescale 1ns / 100ps

module tb_cordic_pipeline;

    reg clk;
    reg signed [31:0] angle_q16_16;
    wire signed [31:0] cos_q16_16;
    wire signed [31:0] sin_q16_16;

    // DUT
    cordic_pipeline uut (
        .clk(clk),
        .angle(angle_q16_16),
        .cos_out(cos_q16_16),
        .sin_out(sin_q16_16)
    );

    // Clock 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;

    // Conversão grau para rad no formato Q16.16 
    function [31:0] graus_para_q16_16;
        input real graus;
        real rad;
        begin
            rad = graus * 3.14159265358979 / 180.0;
            graus_para_q16_16 = $rtoi(rad * 65536.0);
        end
    endfunction

    
    integer i;
    real graus [0:7];
    initial begin
        // Lista de ângulos para teste
        graus[0] = 0.0;
        graus[1] = 30.0;
        graus[2] = 45.0;
        graus[3] = 60.0;
        graus[4] = 90.0;
        graus[5] = -60.0;
        graus[6] = -45.0;
        graus[7] = -30.0;

        // Envia os ângulos, um por ciclo
        for (i = 0; i < 8; i = i + 1) begin
            angle_q16_16 = graus_para_q16_16(graus[i]);
            @(posedge clk);
        end

        // Espera um tempo para propagar pelos 16 estágios do pipeline
        repeat(20) @(posedge clk);

        $stop;
    end

endmodule
