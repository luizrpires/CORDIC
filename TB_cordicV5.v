`timescale 1ns/1ps
module tb_cordic_tabela;

    // ---------------------------------------------------------------
    // parâmetros do módulo CORDIC
    // ---------------------------------------------------------------
    parameter WIDTH      = 32;
    parameter ITERATIONS = 16;
    parameter CIRCULAR   = 2'b01;
    parameter ROTATION   = 1'b0;
    parameter LINEAR     = 2'b00;

    // ---------------------------------------------------------------
    // sinais de entrada do DUT
    // ---------------------------------------------------------------
    reg  clk, rst, enable;
    reg  mode_op;
    reg  [1:0] mode_coord;
    reg  signed [WIDTH-1:0] x_in, y_in, z_in;

    // ---------------------------------------------------------------
    // sinais de saída do DUT
    // ---------------------------------------------------------------
    wire signed [WIDTH-1:0] x_out, y_out, z_out;
    wire valid;

    // ---------------------------------------------------------------
    // variáveis auxiliares
    // ---------------------------------------------------------------
    real angle_rad;
    integer file, r, grau;
    integer deg_norm; // <<--- agora declarado corretamente
    real seno_ref, cos_ref, tan_ref;
    real x_real, y_real, z_real;
    integer y_trunc, x_trunc, seno_trunc, cos_trunc;

    // -------- variáveis modo LINEAR ----------
    real x_test, z_test, y_expected, y_result;
    integer k;
    real x_tab [0:8], z_tab [0:8];

    // ---------------------------------------------------------------
    // instância do DUT
    // ---------------------------------------------------------------
    cordic #(
        .WIDTH(WIDTH),
        .ITERATIONS(ITERATIONS)
    ) dut (
        .clk(clk), .rst(rst), .enable(enable),
        .mode_op(mode_op), .mode_coord(mode_coord),
        .x_in(x_in), .y_in(y_in), .z_in(z_in),
        .x_out(x_out), .y_out(y_out), .z_out(z_out),
        .valid(valid)
    );

    // clock 100 MHz
    always #5 clk = ~clk;

    // ---------------------------------------------------------------
    // Tarefa para imprimir valores truncados com duas casas decimais
    // ---------------------------------------------------------------
    task print_real_trunc;
        input [255:0] label;
        input integer val;
        integer abs_val;
        begin
            abs_val = (val < 0) ? -val : val;
            if (val < 0)
                $write("%s ≈ -%0d.%02d  ", label, abs_val / 100, abs_val % 100);
            else
                $write("%s ≈  %0d.%02d  ", label, abs_val / 100, abs_val % 100);
        end
    endtask

    // ---------------------------------------------------------------
    // Teste completo
    // ---------------------------------------------------------------
    initial begin
        clk = 0; rst = 1; enable = 0;
        mode_op = ROTATION;
        mode_coord = CIRCULAR;
        x_in = 0; y_in = 0; z_in = 0;
        #20 rst = 0;

        // -----------------------------------------------------------
        // Teste CIRCULAR + ROTATION (seno/cosseno)
        // -----------------------------------------------------------
        file = $fopen("tabela_trigonometrica_verilog.txt", "r");
        if (file == 0) begin
            $display("Erro ao abrir o arquivo."); $finish;
        end

        while (!$feof(file)) begin
            r = $fscanf(file, "%d,%f,%f,%f,%f\n",
                        grau, angle_rad, seno_ref, cos_ref, tan_ref);

            // normalização do ângulo para -180° a +180°
            deg_norm = grau;
            if (deg_norm > 180)
                deg_norm = deg_norm - 360;

            // Entradas em Q16.16
            real_to_q16_16(0.60725293, x_in);
            real_to_q16_16(0.0       , y_in);
            deg_to_q16_16(deg_norm   , z_in);

            enable = 1; #10 enable = 0;
            @(posedge valid);

            q16_16_to_real(x_out, x_real);
            q16_16_to_real(y_out, y_real);

            y_trunc    = y_real   * 100;
            x_trunc    = x_real   * 100;
            seno_trunc = seno_ref * 100;
            cos_trunc  = cos_ref  * 100;

            $write("%03d => CORDIC:", grau);
            print_real_trunc("sin", y_trunc);
            print_real_trunc("cos", x_trunc);
            $write("| REF:");
            print_real_trunc("sin", seno_trunc);
            print_real_trunc("cos", cos_trunc);
            $write("\n");
        end
        $fclose(file);

        // -----------------------------------------------------------
        // Teste LINEAR + ROTATION
        // -----------------------------------------------------------
        mode_coord = LINEAR;
        $display("\n*** Testes max/min/negativo - modo LINEAR ***");

        x_tab[0]=0.5;        z_tab[0]= 1.5;
        x_tab[1]=1.25;       z_tab[1]= 1.99;
        x_tab[2]=2.0;        z_tab[2]= 2.1;
        x_tab[3]=16384.0;    z_tab[3]= 2.0;
        x_tab[4]=20000.0;    z_tab[4]= 2.0;
        x_tab[5]=-32768.0;   z_tab[5]= 1.0;
        x_tab[6]=2.0;        z_tab[6]=-1.5;
        x_tab[7]=0.1;        z_tab[7]= 0.1;
        x_tab[8]=0.1;        z_tab[8]= 2.0;

        for (k = 0; k < 9; k = k + 1) begin
            x_test = x_tab[k];
            z_test = z_tab[k];
            y_expected = x_test * z_test;

            real_to_q16_16(x_test, x_in);
            real_to_q16_16(0.0   , y_in);
            real_to_q16_16(z_test, z_in);

            enable = 1; #10 enable = 0;
            @(posedge valid);

            q16_16_to_real(y_out, y_result);

            $display("x=%.2f  z=%.2f  =>  y CORDIC=%.2f | ref=%.2f",
                     x_test, z_test, y_result, y_expected);
        end
        $stop;
    end

    // ---------------------------------------------------------------
    // Funções de conversão Q16.16
    // ---------------------------------------------------------------
    task real_to_q16_16(input real val_in, output reg signed [31:0] val_out);
        begin val_out = $rtoi(val_in * 65536.0); end
    endtask

    task q16_16_to_real(input signed [31:0] val_in, output real val_out);
        begin val_out = val_in / 65536.0; end
    endtask

    task deg_to_q16_16(input integer deg_in, output reg signed [31:0] val_out);
        real rad;
        begin
            rad = deg_in * 3.141592653589793 / 180.0;
            val_out = $rtoi(rad * 65536.0);
        end
    endtask

endmodule
