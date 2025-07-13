`timescale 1ns / 1ps

module tb_top_level_calc_cordic;

    parameter WIDTH = 32;
    parameter ITERATIONS = 16;

    reg clk, rst, enable;
    reg [3:0] operation;
    reg signed [WIDTH-1:0] x_in, y_in, z_in;

    wire signed [WIDTH-1:0] result;
    wire done;

    // OPERAÇÕES
    localparam  SIN     = 4'b0000, //0 para Seno
                COS     = 4'b0001, //1 para Cosseno
                TAN     = 4'b0010, //2 para Tangente
                ATAN    = 4'b0011, //3 para Arco Tangente
                MAG     = 4'b0100, //4 para Magnitude
                POLtoREC= 4'b0101, //5 para Conversão Polar para Retangular
                RECtoPOL= 4'b0110, //6 para Conversão Retangular para Polar
                MULT    = 4'b0111, //7 para Multiplicação
                DIV     = 4'b1000, //8 para Divisão
                SINH    = 4'b1001, //9 para Seno Hiperbólico
                COSH    = 4'b1010, //10 para Cosseno Hiperbólico
                ATANH   = 4'b1011, //11 para Arco Tangente Hiperbólico
                EXP     = 4'b1100, //12 para Exponencial
                LOG     = 4'b1101, //13 para Logaritmo
                SQRT    = 4'b1110, //14 para Raiz Quadrada
                DEFAULT = 4'b1111; // Padrão


    top_level_calc_cordic #(
        .WIDTH(WIDTH),
        .ITERATIONS(ITERATIONS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .operation(operation),
        .x_in(x_in),
        .y_in(y_in),
        .z_in(z_in),
        .result(result),
        .done(done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task testar;
        input [3:0] op;
        input real x_val, y_val, z_val;
        input [8*20:1] nome_op;

        real r_result;

        begin
            operation = op;
            real_to_q16_16(x_val, x_in);
            real_to_q16_16(y_val, y_in);
            real_to_q16_16(z_val, z_in);

            @(negedge clk); enable = 1;
            @(negedge clk); enable = 0;

            wait(done == 1);
            q16_16_to_real(result, r_result);

            $display("[%s] Resultado: %f", nome_op, r_result);
        end
    endtask

    initial begin
        rst = 1; enable = 0;
        x_in = 32'b0;
        y_in = 32'b0;
        z_in = 32'b0;
        operation = DEFAULT;
        #20 rst = 0;

        $display("=== Testes do CALC_cordic ===");

        // Seno: sin(45°) ≈ 0.7071
        testar(SIN, 0.0, 0.0, 0.7854, "SIN(45)");
        #10;

        // Cosseno: cos(45°) ≈ 0.7071
        testar(COS, 0.0, 0.0, 0.7854, "COS(45)");
        #10;          

        // Multiplicação: 2 * 1.5 = 3
        testar(MULT, 1.5, 0.0, 2.0, "MULT(2 * 1.5)");
        #10;
        
        // Divisão: 15 / 9 = 1.6667
        testar(DIV, 9.0, 15.0, 0.0, "DIV(15 / 9)");
        #10;

        // Seno hiperbólico: sinh(1) ≈ 1.1752
        testar(SINH, 0.0, 0.0, 1.0, "SINH(1)");
        #10;

        // Cosseno hiperbólico: cosh(1) ≈ 1.5430
        testar(COSH, 0.0, 0.0, 1.0, "COSH(1)");
        #10;

        $display("=== Fim dos testes ===");
        $stop;
    end

    // Converte número real para ponto fixo Q16.16
    task real_to_q16_16;
        input real val_real;
        output reg signed [31:0] val_fixed;
        begin
            val_fixed = $rtoi(val_real * (1 << 16)); // Multiplica por 2^16 //65536.0
        end
    endtask

    // Converte valor Q16.16 para real
    task q16_16_to_real;
        input signed [31:0] val_fixed;
        output real val_real;
        begin
            val_real = $itor(val_fixed) / (1 << 16); // Divide por 2^16 //65536.0
        end
    endtask

endmodule
