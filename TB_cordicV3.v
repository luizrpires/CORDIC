`timescale 1ns/1ps

module tb_cordic_tabela;

    // parâmetros do módulo CORDIC
    parameter WIDTH = 32;
    parameter ITERATIONS = 16;
    parameter CIRCULAR = 2'b01;
    parameter ROTATION = 1'b0;
    parameter LINEAR = 2'b00;

    // sinais de entrada do DUT
    reg clk;
    reg rst;
    reg enable;
    reg mode_op;
    reg [1:0] mode_coord;
    reg signed [WIDTH-1:0] x_in, y_in, z_in;

    // sinais de saída do DUT
    wire signed [WIDTH-1:0] x_out, y_out, z_out;
    wire valid;

    // variáveis auxiliares
    real angle_rad;
    integer file, r, grau;
    real seno_ref, cos_ref, tan_ref;
    real x_real, y_real, z_real;

    // variáveis para truncamento
    integer y_trunc, x_trunc, seno_trunc, cos_trunc;

    // variáveis para modo LINEAR (multiplicação)
    real x_test, z_test, y_expected, y_result;
    integer y_trunc_test, y_expected_trunc;
    integer i, j;

    // instância do módulo CORDIC
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

    // geração de clock
    always #5 clk = ~clk;

    initial begin
        // inicialização
        clk = 0;
        rst = 1;
        enable = 0;
        mode_op = ROTATION;
        mode_coord = CIRCULAR;

        x_in = 0;
        y_in = 0;
        z_in = 0;

        #20 rst = 0;

        // abre arquivo com valores de referência
        file = $fopen("tabela_trigonometrica_verilog.txt", "r");
        if (file == 0) begin
            $display("Erro ao abrir o arquivo.");
            $finish;
        end

        // --- Modo CIRCULAR + ROTATION: Cosseno/Seno
      /*  while (!$feof(file)) begin
            r = $fscanf(file, "%d,%f,%f,%f,%f\n", grau, angle_rad, seno_ref, cos_ref, tan_ref);

            real_to_q16_16(0.60725293, x_in);
            real_to_q16_16(0.0, y_in);
            real_to_q16_16(angle_rad, z_in);

            enable = 1;
            #10 enable = 0;

            wait(valid == 1);
            #10;

            q16_16_to_real(x_out, x_real);
            q16_16_to_real(y_out, y_real);
            q16_16_to_real(z_out, z_real);

            y_trunc    = y_real * 100;
            x_trunc    = x_real * 100;
            seno_trunc = seno_ref * 100;
            cos_trunc  = cos_ref * 100;

            $display("°%03d => CORDIC: sin ≈ %0d.%02d, cos ≈ %0d.%02d | REF: sin ≈ %0d.%02d, cos ≈ %0d.%02d",
                     grau,
                     y_trunc / 100,    y_trunc % 100,
                     x_trunc / 100,    x_trunc % 100,
                     seno_trunc / 100, seno_trunc % 100,
                     cos_trunc / 100,  cos_trunc % 100);
        end
        $fclose(file);
*/
        // --- Modo LINEAR: Multiplicação y = x * z
        $display("\n--- Testando CORDIC LINEAR (Multiplicação: y = x * z) ---");
        for (i = 1; i <= 3; i = i + 1) begin
            for (j = 1; j <= 3; j = j + 1) begin
                x_test = i * 0.5;
                z_test = j * 1.5;
                y_expected = x_test * z_test;

                real_to_q16_16(x_test, x_in);
                real_to_q16_16(0.0, y_in);
                real_to_q16_16(z_test, z_in);

                mode_coord = LINEAR;
                mode_op = ROTATION;

                enable = 1;
                #10 enable = 0;

                wait(valid == 1);
                #10;

                q16_16_to_real(y_out, y_result);

                y_trunc_test = y_result * 100;
                y_expected_trunc = y_expected * 100;

                $display("x = %4.2f, z = %4.2f => CORDIC y ≈ %0d.%02d | Esperado y ≈ %0d.%02d",
                         x_test, z_test,
                         y_trunc_test / 100, y_trunc_test % 100,
                         y_expected_trunc / 100, y_expected_trunc % 100);
            end
        end
        $display("\n--- Stress max min negativo faixa LINEAR ---");

        // 1) x =  0,5	z= 1,5	resultado =0,75
        x_test     = 0.5;
        z_test     = 1.5;
        y_expected = x_test * z_test;
        real_to_q16_16(x_test, x_in);
        real_to_q16_16(0.0   , y_in);
        real_to_q16_16(z_test, z_in);
        mode_coord = LINEAR;  mode_op = ROTATION;
        enable = 1; #10 enable = 0;
        wait(valid); #10;
        q16_16_to_real(y_out, y_result);
        $display("x = %0.2f, z = %0.2f => y CORDIC = %0.2f | ref ≈ %0.2f",
         x_test, z_test, y_result, y_expected);

        // 2)  x=  1,25	z= 1,99	resultado =	2,4875
        x_test     = 1.25;  
        z_test     = 1.99;
        y_expected = x_test * z_test;
        real_to_q16_16(x_test, x_in);
        real_to_q16_16(0.0   , y_in);
        real_to_q16_16(z_test, z_in);
        enable = 1; #10 enable = 0;
        wait(valid); #10;
        q16_16_to_real(y_out, y_result);
        $display("x = %0.2f, z = %0.2f => y CORDIC = %0.2f | ref ≈ %0.2f",
         x_test, z_test, y_result, y_expected);

        // 3)  x= 2,0	z= 2,1  resultado =	4,2
        x_test     = 2.0;
        z_test     = 2.1;
        y_expected = x_test * z_test;
        real_to_q16_16(x_test, x_in);
        real_to_q16_16(0.0   , y_in);
        real_to_q16_16(z_test, z_in);
        enable = 1; #10 enable = 0;
        wait(valid); #10;
        q16_16_to_real(y_out, y_result);
        $display("x = %0.2f, z = %0.2f => y CORDIC = %0.2f | ref ≈ %0.2f",
         x_test, z_test, y_result, y_expected);

        // 4) x = 16384,0  z = 2,0  resultado =	32768
        x_test     = 16384.0;
        z_test     = 2.0;
        y_expected = x_test * z_test;  // ≈ 0.491505
        real_to_q16_16(x_test, x_in);
        real_to_q16_16(0.0   , y_in);
        real_to_q16_16(z_test, z_in);
        enable = 1; #10 enable = 0;
        wait(valid); #10;
        q16_16_to_real(y_out, y_result);
        $display("x = %0.2f, z = %0.2f => y CORDIC = %0.2f | ref ≈ %0.2f",
        x_test, z_test, y_result, y_expected);

        // 5) x = 20000,0  z = 2,0  resultado= 40000 Estoura
        x_test     = 20000.0;
        z_test     = 2.0;
        y_expected = x_test * z_test;  // ≈ 0.491505
        real_to_q16_16(x_test, x_in);
        real_to_q16_16(0.0   , y_in);
        real_to_q16_16(z_test, z_in);
        enable = 1; #10 enable = 0;
        wait(valid); #10;
        q16_16_to_real(y_out, y_result);
        $display("x = %0.2f, z = %0.2f => y CORDIC = %0.2f | ref ≈ %0.2f",
         x_test, z_test, y_result, y_expected);

        // 6) x = -32768.0  z = 1.0  resultado= -32768
        x_test     = -32768.0;
        z_test     = 1.0;
        y_expected = x_test * z_test;  // ≈ 0.491505
        real_to_q16_16(x_test, x_in);
        real_to_q16_16(0.0   , y_in);
        real_to_q16_16(z_test, z_in);
        enable = 1; #10 enable = 0;
        wait(valid); #10;
        q16_16_to_real(y_out, y_result);
        $display("x = %0.2f, z = %0.2f => y CORDIC = %0.2f | ref ≈ %0.2f",
        x_test, z_test, y_result, y_expected);

        // 7) x = 2.0 z = -3.5  resultado= -7   ---- Z negativo
        x_test     = 2.0;
        z_test     = -3.5;
        y_expected = x_test * z_test;  // ≈ 0.491505
        real_to_q16_16(x_test, x_in);
        real_to_q16_16(0.0   , y_in);
        real_to_q16_16(z_test, z_in);
        enable = 1; #10 enable = 0;
        wait(valid); #10;
        q16_16_to_real(y_out, y_result);
        $display("x = %0.2f, z = %0.2f => y CORDIC = %0.2f | ref ≈ %0.2f",
        x_test, z_test, y_result, y_expected);

        // 8) x = 0.1 z = 0.1  resultado= 0.01   --valor minimo
        x_test     = 0.1;
        z_test     = 0.1;
        y_expected = x_test * z_test;  // ≈ 0.491505
        real_to_q16_16(x_test, x_in);
        real_to_q16_16(0.0   , y_in);
        real_to_q16_16(z_test, z_in);
        enable = 1; #10 enable = 0;
        wait(valid); #10;
        q16_16_to_real(y_out, y_result);
        $display("x = %0.2f, z = %0.2f => y CORDIC = %0.2f | ref ≈ %0.2f",
        x_test, z_test, y_result, y_expected);

        // 9) x = 0.1 z = 2.0  resultado= 0,2
        x_test     = 0.1;
        z_test     = 2.0;
        y_expected = x_test * z_test;  // ≈ 0.491505
        real_to_q16_16(x_test, x_in);
        real_to_q16_16(0.0   , y_in);
        real_to_q16_16(z_test, z_in);
        enable = 1; #10 enable = 0;
        wait(valid); #10;
        q16_16_to_real(y_out, y_result);
        $display("x = %0.2f, z = %0.2f => y CORDIC = %0.2f | ref ≈ %0.2f",
        x_test, z_test, y_result, y_expected);
        $stop;
    end

    // Conversão de real para Q16.16
    task real_to_q16_16;
        input real val_real;
        output reg signed [31:0] val_fixed;
        begin
            val_fixed = $rtoi(val_real * 65536.0);
        end
    endtask

    // Conversão de Q16.16 para real
    task q16_16_to_real;
        input signed [31:0] val_fixed;
        output real val_real;
        begin
            val_real = $itor(val_fixed) / 65536.0;
        end
    endtask

endmodule
