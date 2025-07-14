`timescale 1ns/1ps
module tb_cordic_tabela;

    // ------------------------------------------------------------
    // Parâmetros do CORDIC
    // ------------------------------------------------------------
    parameter WIDTH      = 32;
    parameter ITERATIONS = 16;
    parameter CIRCULAR   = 2'b01;
    parameter ROTATION   = 1'b0;
    parameter LINEAR     = 2'b00;
    parameter HYPERBOLIC = 2'b11;

    // Imprime erros só se > 0.1 (modo circular)
    parameter real ERROR_THRESHOLD = 0.1;

    // ------------------------------------------------------------
    // Sinais de I/O
    // ------------------------------------------------------------
    reg clk, rst, enable;
    reg mode_op;
    reg [1:0] mode_coord;
    reg  signed [WIDTH-1:0] x_in, y_in, z_in;
    wire signed [WIDTH-1:0] x_out, y_out, z_out;
    wire valid;

    // ------------------------------------------------------------
    // Variáveis auxiliares – modo circular
    // ------------------------------------------------------------
    real angle_rad;
    integer file, r, grau, deg_norm;
    real seno_ref, cos_ref, tan_ref;
    real x_real, y_real;
    real error_sin, error_cos;

    // ------------------------------------------------------------
    // Tabelas usadas nos blocos Linear e Hiperbólico
    // ------------------------------------------------------------
    real x_tab [0:12], z_tab [0:12];
    real x_test, z_test;
    real y_expected, y_result;
    integer k;
    real ref_x, ref_y, err_x, err_y;
    real ref_cosh, ref_sinh;    // <<<  AQUI (antes do initial)

    // ------------------------------------------------------------
    // Instância do DUT
    // ------------------------------------------------------------
    cordic #(
        .WIDTH     (WIDTH),
        .ITERATIONS(ITERATIONS)
    ) dut (
        .clk       (clk),
        .rst       (rst),
        .enable    (enable),
        .mode_op   (mode_op),
        .mode_coord(mode_coord),
        .x_in      (x_in),
        .y_in      (y_in),
        .z_in      (z_in),
        .x_out     (x_out),
        .y_out     (y_out),
        .z_out     (z_out),
        .valid     (valid)
    );

    // clock 10 ns
    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // Tasks / funções auxiliares
    // ------------------------------------------------------------
    function real abs_real(input real v); begin abs_real = (v<0.0)? -v : v; end endfunction

    task real_to_q16_16(input real r,   output reg signed [31:0] q);
        begin q = $rtoi(r * 65536.0); end
    endtask

    task q16_16_to_real(input signed [31:0] q, output real r);
        begin r = q / 65536.0; end
    endtask

    task deg_to_q16_16(input integer d, output reg signed [31:0] q);
        real rad; begin
            rad = d * 3.141592653589793 / 180.0;
            q   = $rtoi(rad * 65536.0);
        end
    endtask

    // ============================================================
    //  BLOCO PRINCIPAL
    // ============================================================
    initial begin
        //---------------------------------------------------------
        // Reset
        //---------------------------------------------------------
        clk=0; rst=1; enable=0;
        mode_op=ROTATION; mode_coord=CIRCULAR;
        #20 rst=0;

        //---------------------------------------------------------
        // 1)  CIRCULAR – rotação
        //---------------------------------------------------------
        file=$fopen("tabela_trigonometrica_verilog.txt","r");
        if (file==0) begin $display("Erro ao abrir tabela"); $finish; end

        while (!$feof(file)) begin
            r=$fscanf(file,"%d,%f,%f,%f,%f\n",
                      grau,angle_rad,seno_ref,cos_ref,tan_ref);

            deg_norm=(grau>180)? grau-360 : grau;

            real_to_q16_16(0.60725293,x_in);   // K^-1
            real_to_q16_16(0.0        ,y_in);
            deg_to_q16_16(deg_norm    ,z_in);

            enable=1; #10 enable=0; @(posedge valid);
            q16_16_to_real(x_out,x_real); q16_16_to_real(y_out,y_real);

            error_sin=abs_real(y_real-seno_ref);
            error_cos=abs_real(x_real-cos_ref);

            if (error_sin>ERROR_THRESHOLD || error_cos>ERROR_THRESHOLD)
                $display("ERRO %03d  sin=%.2f (ref %.2f)  cos=%.2f (ref %.2f)",
                         grau, y_real,seno_ref,x_real,cos_ref);
        end
        $fclose(file);

        //---------------------------------------------------------
        // 2)  LINEAR – rotação   (y = x * z)
        //---------------------------------------------------------
        mode_coord = LINEAR;
        $display("\n*** Testes LINEAR (y=x*z) ***");

        x_tab[0]=0.5; z_tab[0]= 1.5;
        x_tab[1]=1.25; z_tab[1]=1.99;
        x_tab[2]=2.0; z_tab[2]= 2.1;
        x_tab[3]=16384.0; z_tab[3]=2.0;
        x_tab[4]=20000.0; z_tab[4]=2.0;
        x_tab[5]=-32768.0; z_tab[5]=1.0;
        x_tab[6]=2.0; z_tab[6]=-1.5;
        x_tab[7]=0.1; z_tab[7]=0.1;
        x_tab[8]=0.1; z_tab[8]=2.0;

        for (k=0;k<9;k=k+1) begin
            x_test=x_tab[k]; z_test=z_tab[k]; y_expected=x_test*z_test;
            real_to_q16_16(x_test,x_in);
            real_to_q16_16(0.0   ,y_in);
            real_to_q16_16(z_test,z_in);

            enable=1; #10 enable=0; @(posedge valid);
            q16_16_to_real(y_out,y_result);

            $display("x=%8.2f  z=%6.2f  => y=%.2f  (ref %.2f)",
                     x_test,z_test,y_result,y_expected);
        end

        //---------------------------------------------------------
        // 3)  HIPERBÓLICO – rotação
        //---------------------------------------------------------
        mode_coord = HYPERBOLIC;
        $display("\n*** Testes HIPERBÓLICO (rotação) ***");

        // Tabela de entrada (x_in, z_in)
        x_tab[0]=1.0   ; z_tab[0]= 0.5 ;
        x_tab[1]=1.0   ; z_tab[1]=-0.5 ;
        x_tab[2]=3.0   ; z_tab[2]= 2.0 ;
        x_tab[3]=0.1   ; z_tab[3]= 1.0 ;
        x_tab[4]=0.5   ; z_tab[4]=-2.0 ;
        x_tab[5]=8.0   ; z_tab[5]= 1.0 ;
        x_tab[6]=0.0015; z_tab[6]= 1.0 ;
        x_tab[7]=1.0   ; z_tab[7]= 4.0 ;
        x_tab[8]=1.0   ; z_tab[8]=-4.0 ;
        x_tab[9]=1.3   ; z_tab[9]= 2.4 ;
        x_tab[10]=1.3  ; z_tab[10]=-2.4 ;
        x_tab[11]=5200 ; z_tab[11]= 2.0 ;
        x_tab[12]=5300 ; z_tab[12]= 2.0 ;




        for (k = 0; k < 12; k = k + 1) begin
            x_test = x_tab[k];
            z_test = z_tab[k];

            // referências cosh(z)*x  e  sinh(z)*x
            ref_cosh = ( $exp(z_test) + $exp(-z_test) ) / 2.0;
            ref_sinh = ( $exp(z_test) - $exp(-z_test) ) / 2.0;
            ref_x    = x_test * ref_cosh;
            ref_y    = x_test * ref_sinh;

            real_to_q16_16(x_test, x_in);
            real_to_q16_16(0.0   , y_in);
            real_to_q16_16(z_test, z_in);

            enable = 1; #10; enable = 0;
            @(posedge valid);

            q16_16_to_real(x_out, x_real);
            q16_16_to_real(y_out, y_real);

            err_x = abs_real(x_real - ref_x);
            err_y = abs_real(y_real - ref_y);

            $display("T%0d  x_in=%8.2f  z=%6.2f  ->  x_out=%9.2f (ref %9.2f | err %.2f)  |  y_out=%9.2f (ref %9.2f | err %.2f)",
                    k+1, x_test, z_test,
                    x_real, ref_x, err_x,
                    y_real, ref_y, err_y);
        end

        $finish;      // encerra a simulação após todos os testes
    end              // initial
endmodule
