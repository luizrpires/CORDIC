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
    localparam  SIN     = 4'b0000, //0 para Seno
                COS     = 4'b0001, //1 para Cosseno
                ATAN    = 4'b0010, //2 para Arc Tangente
                MOD     = 4'b0011, //3 para Módulo/Magnitude
                MULT    = 4'b0100, //4 para Multiplicação
                DIV     = 4'b0101, //5 para Divisão
                SINH    = 4'b0110, //6 para Seno Hiperbólico
                COSH    = 4'b0111, //7 para Cosseno Hiperbólico
                ATANH   = 4'b1000, //8 para Arc Tangente Hiperbólico
                MODH    = 4'b1001, //9 para Módulo Hiperbólico
                //EXP     = 4'b1010, //10 para Exponencial
                //LOG     = 4'b1011, //11 para Logaritmo
                //SQRT    = 4'b1100, //12 para Raiz Quadrada
                //      = 4'b1101, //13 para 
                //      = 4'b1110, //14 para 
                DEFAULT = 4'b1111; // Padrão/Sem uso

    // Variáveis para leitura do arquivo
    integer file, r, grau;
    real angle_rad, seno_ref, cos_ref, atan_ref, xin, zin, mult_ref, yin, div_ref, zhin, sinh_ref, cosh_ref,mag_ref;
    
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
        input [8*40:1] nome_op;
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
/*
        // Abre o arquivo de teste seno e coseno
        file = $fopen("tabela_seno_coseno.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f,%f\n",
           grau, angle_rad, seno_ref, cos_ref);
            
            if (r == 4) begin  // Verifica se leu todos os 4 valores
                // Teste do SENO
                $sformat(nome_op_temp, "SENO(%0d)", grau);
                testar(SIN, 0.0, 0.0, angle_rad, nome_op_temp, seno_ref);
                #10;
                
                // Teste do COSSENO
                $sformat(nome_op_temp, "COSSENO(%0d)", grau);
                testar(COS, 0.0, 0.0, angle_rad, nome_op_temp, cos_ref);
                #10;                                                       
            end
        end
        $fclose(file);
        #200;

        // Abre o arquivo de teste multiplicação
        file = $fopen("tabela_multiplicacao.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f\n",
           xin, zin, mult_ref);
            
            if (r == 3) begin  // Verifica se leu todos os 3 valores
                 // Teste da MULTIPLICAÇÃO
                $sformat(nome_op_temp, "MULT(%f x %f)", xin, zin);
                testar(MULT, xin, 0.0, zin, nome_op_temp, mult_ref);
                #10;
                end
            end
        $fclose(file);
        #200;

        // Abre o arquivo de teste divição
        file = $fopen("tabela_divisaoo.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f\n",
           xin, yin, div_ref);
            
            if (r == 3) begin  // Verifica se leu todos os 3 valores
                // Teste da DIVIÇÃO
                $sformat(nome_op_temp, "DIV(%f / %f)", yin, xin);
                testar(DIV, xin, yin, 0.0, nome_op_temp, div_ref);
                #100;
                end
            end
        $fclose(file);
        #200;

        // Abre o arquivo de teste artangente
        file = $fopen("tabela_tangente.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f\n",
           xin, yin, atan_ref);
            
            if (r == 3) begin  // Verifica se leu todos os 3 valores
                // Teste da ARC TANGENTE
                $sformat(nome_op_temp, "ATAN(%f / %f)", yin, xin);
                testar(ATAN, xin, yin, 0.0, nome_op_temp, atan_ref);
                #100;
                end
            end
        $fclose(file);
        #200;
*/
        // Abre o arquivo de teste magnitude
        file = $fopen("tabela_magnitude.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f\n",
           xin, yin, mag_ref);
            
            if (r == 3) begin  // Verifica se leu todos os 3 valores
                // Teste da ARC TANGENTE
                $sformat(nome_op_temp, "MOD(%f - %f)", yin, xin);
                testar(MOD, xin, yin, 0.0, nome_op_temp, mag_ref);
                #100;
                end
            end
        $fclose(file);
        #200;

        
    /*   
        // Abre o arquivo de teste seno Hiperbolico 
        file = $fopen("tabela_seno_hiperbolico.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f\n",
           zin, sinh_ref);
            
            if (r == 2) begin  // Verifica se leu todos os 2 valores
                // Seno hiperbólico: sinh(1) ≈ 1.1752
                $sformat(nome_op_temp, "SINH(%f)", zhin);
                testar(SINH, 0.0, 0.0, zhin, nome_op_temp, sinh_ref);
                #100;
                end                     
            end
        $fclose(file);
        #200;
        

         // Abre o arquivo de teste coseno Hiperbolico 
        file = $fopen("tabela_coseno_hiperbolico.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f\n",
           zin, cosh_ref);
            
            if (r == 2) begin  // Verifica se leu todos os 2 valores     
                // Cosseno hiperbólico: cosh(1) ≈ 1.5430
                $sformat(nome_op_temp, "COSH(%f)", zhin);
                testar(COSH, 0.0, 0.0, zhin, nome_op_temp, cosh_ref);
                #100;  
                end
            end
        $fclose(file);
        #100;
*/
        // Mostra resultado final caso de sucesso
        if (error_count == 0) begin
            $display("\n====================================");
            $display(" SUCESSO: Todos os valores passaram!");
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