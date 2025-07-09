`timescale 1ns/1ps

module tb_cordic;

    // Parâmetros
    parameter WIDTH = 32;
    parameter ITERATIONS = 16;

    //MODO COORDENADA
    parameter   CIRCULAR = 2'b01, //1 para Circular
                LINEAR = 2'b00, //0 para Linear
                HYPERBOLIC = 2'b11; //-1 para Hiperbólico

    //MODO OPERAÇÃO 
    parameter   ROTATION = 1'b0, //0 para Rotação
                VECTORING = 1'b1; //1 para Vetorização

    // Entradas
    reg clk;
    reg rst;
    reg enable;
    reg mode_op;    
    reg [1:0] mode_coord;
    reg signed [WIDTH-1:0] x_in, y_in, z_in;

    // Saídas
    wire signed [WIDTH-1:0] x_out, y_out, z_out;
    wire valid;

    // Variáveis para conversão de ponto fixo
    real real_x, real_y, real_z;
    real temp_x, temp_y, temp_z;

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

    initial begin
        // Inicialização
        clk = 0;
        rst = 1;
        enable = 0;
        mode_coord = LINEAR;
        mode_op = ROTATION;
        x_in = 0;
        y_in = 0;
        z_in = 0;

        #20;
        rst = 0;

        //entrada de dados
        temp_x = 5.0;
        temp_y = 0.0;
        temp_z = 1.5;
        
        // Converte para Q16.16
        real_to_q16_16(temp_x, x_in);
        real_to_q16_16(temp_y, y_in);
        real_to_q16_16(temp_z, z_in);

        enable = 1;
        #10 enable = 0;

        // Espera saída válida
        wait (valid == 1);
        #10;


        // Converte para ponto flutuante    
        q16_16_to_real(x_out, real_x);
        q16_16_to_real(y_out, real_y);
        q16_16_to_real(z_out, real_z);

        $display("X_out ≈ %f", real_x);
        $display("Y_out ≈ %f", real_y);
        $display("Z_out ≈ %f", real_z);

        #10 $stop;
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
