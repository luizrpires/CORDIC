`timescale 1ns / 1ps

module tb_top_level_calc_cordic;

    parameter WIDTH = 32;
    parameter ITERATIONS = 16;
    parameter ERROR_THRESHOLD = 0.1;  // Margem de erro permitida

    reg clk, rst, enable;
    reg [3:0] operation;
    reg signed [WIDTH-1:0] x_in, y_in, z_in;

    wire signed [WIDTH-1:0] result;
    wire done;

    // OPERAÇÕES
    localparam  SIN     = 4'b0000,
                COS     = 4'b0001,
                TAN     = 4'b0010,
                ATAN    = 4'b0011,
                MAG     = 4'b0100,
                POLtoREC= 4'b0101,
                RECtoPOL= 4'b0110,
                MULT    = 4'b0111,
                DIV     = 4'b1000,
                SINH    = 4'b1001,
                COSH    = 4'b1010,
                ATANH   = 4'b1011,
                EXP     = 4'b1100,
                LOG     = 4'b1101,
                SQRT    = 4'b1110,
                DEFAULT = 4'b1111;

    // Variáveis para leitura do arquivo
    integer file, r, grau;
    real angle_rad, seno_ref, cos_ref, tan_ref, xin, zin, mult_ref, yin, div_ref, zhin, sinh_ref, cosh_ref;
    
    // String temporária para formatação
    reg [8*40:1] nome_op_temp;
    
    // Contador de erros
    integer error_count = 0;

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
        input [8*30:1] nome_op;
        input real ref_val;  // Novo parâmetro para valor de referência

        real r_result;
        real error;

        begin
            operation = op;
            real_to_q16_16(x_val, x_in);
            real_to_q16_16(y_val, y_in);
            real_to_q16_16(z_val, z_in);

            @(negedge clk); enable = 1;
            @(negedge clk); enable = 0;

            wait(done == 1);
            q16_16_to_real(result, r_result);
            
            // Calcula o erro absoluto
            error = (r_result > ref_val) ? (r_result - ref_val) : (ref_val - r_result);
            
            // Mostra apenas se erro > threshold
            if (error > ERROR_THRESHOLD) begin
                $display("ERRO em %s: Esperado=%f, Obtido=%f (Erro=%f)", 
                        nome_op, ref_val, r_result, error);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        rst = 1; enable = 0;
        x_in = 32'b0;
        y_in = 32'b0;
        z_in = 32'b0;
        operation = DEFAULT;
        #20 rst = 0;

        $display("=== Iniciando testes (mostrando apenas erros > %f) ===", ERROR_THRESHOLD);

        // Abre o arquivo de teste
        file = $fopen("tabela_trigonometrica_verilog2v.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%d,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f\n",
           grau, angle_rad, seno_ref, cos_ref, tan_ref, xin, zin, mult_ref, yin, div_ref, zhin, sinh_ref, cosh_ref);
            
            if (r == 13) begin  // Verifica se leu todos os 12 valores
                // Teste do SENO
                $sformat(nome_op_temp, "SENO(%0d)", grau);
                testar(SIN, 0.0, 0.0, angle_rad, nome_op_temp, seno_ref);
                #10;
                
                // Teste do COSSENO
                $sformat(nome_op_temp, "COSSENO(%0d)", grau);
                testar(COS, 0.0, 0.0, angle_rad, nome_op_temp, cos_ref);
                #10; 

                // Teste da MULTIPLICAÇÃO
                $sformat(nome_op_temp, "MULT(%f x %f)", xin, zin);
                testar(MULT, xin, 0.0, zin, nome_op_temp, mult_ref);
                #10;

                // Teste da DIVIÇÃO
                $sformat(nome_op_temp, "DIV(%f / %f)", yin, xin);
                testar(DIV, xin, yin, 0.0, nome_op_temp, div_ref);
                #10;

                // Seno hiperbólico: sinh(1) ≈ 1.1752
                $sformat(nome_op_temp, "SINH(%f)", zhin);
                testar(SINH, 0.0, 0.0, zhin, nome_op_temp, sinh_ref);
                #10;
         
                // Cosseno hiperbólico: cosh(1) ≈ 1.5430
                $sformat(nome_op_temp, "COSH(%f)", zhin);
                testar(COSH, 0.0, 0.0, zhin, nome_op_temp, cosh_ref);
                #10;                
                                            
            end
        end
        $fclose(file);

        // Mostra resultado final caso de sucesso
        if (error_count == 0) begin
            $display("\n====================================");
            $display(" SUCESSO: Todos os valores Seno e Coseno passaram!");
            $display("====================================\n");
        end else begin
            $display("\n====================================");
            $display(" ATENCÃO: %0d erros encontrados", error_count);
            $display("====================================\n");
        end

        $display("=== Fim dos testes ===");
        $stop;
    end

    task real_to_q16_16;
        input real val_real;
        output reg signed [31:0] val_fixed;
        begin
            val_fixed = $rtoi(val_real * (1 << 16));
        end
    endtask

    task q16_16_to_real;
        input signed [31:0] val_fixed;
        output real val_real;
        begin
            val_real = $itor(val_fixed) / (1 << 16);
        end
    endtask

endmodule