`timescale 1ns / 1ps

module tb_top_level_calc_cordic;

    parameter WIDTH = 32;
    parameter ITERATIONS = 30;
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
                //      = 4'b1010, //10 para 
                //      = 4'b1011, //11 para 
                //      = 4'b1100, //12 para  
                //      = 4'b1101, //13 para 
                //      = 4'b1110, //14 para 
                DEFAULT = 4'b1111; // Padrão/Sem uso

    // Variáveis para leitura do arquivo
    integer file, r, file_handle;
    real grau, angle_rad, xin, zin, yin, result_ref;
    
    // String temporária para formatação
    reg [8*40:1] nome_op_temp;
    
    // Contador de erros
    integer error_count = 0;

    top_level_calc_cordic #(
        .ITERATIONS(ITERATIONS)
    ) top_level (
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

    initial begin
        // Abre o arquivo para escrita. O "w" significa write (escrita).
        // Se o arquivo não existir, ele será criado. Se existir, será sobrescrito.
        file_handle = $fopen("log_erros_testes.txt", "w"); 
        if (file_handle == 0) begin // Verifica se o arquivo foi aberto com sucesso
            $display("ERRO: Não foi possível abrir o arquivo 'log_erros_testes.txt'");
            $stop; // Para a simulação se não puder abrir o arquivo
        end
        $fdisplay(file_handle, "--- Log de Testes de Operações ---"); // Escreve um cabeçalho no arquivo
    end

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
            
            if (error > ERROR_THRESHOLD) begin
                $fdisplay(file_handle, "ERRO em %s: Esperado=%f, Obtido=%f (Erro=%f)", // armazenar em um arquivo txt
                                    nome_op, ref_val, r_result, error);
                $display("ERRO em %s: Esperado=%f, Obtido=%f (Erro=%f)", // apenas mostrar no console
                                     nome_op, ref_val, r_result, error);
                error_count = error_count + 1;
            end else begin
                $fdisplay(file_handle, "ACERTO em %s: Esperado=%f, Obtido=%f (Erro=%f)", // armazenar em um arquivo txt
                                    nome_op, ref_val, r_result, error);
                //$display("ACERTO em %s: Esperado=%f, Obtido=%f (Erro=%f)", // apenas mostrar no console
                //                   nome_op, ref_val, r_result, error);
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

        //testar(MULT, 3.0, 0.0, 5.0, nome_op_temp, 15.0); 
        //testar(MULT, 4.0, 0.0, 6.0, nome_op_temp, 24.0); 

        $display("=== Iniciando testes (mostrando apenas erros > %f) ===", ERROR_THRESHOLD);        

        // Abre o arquivo de teste seno
        file = $fopen("test_cases_sin.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f,%f,%f\n",
           grau, xin, yin, zin, result_ref);
            
            if (r == 5) begin  // Verifica se leu todos os valores
                // Teste do SENO
                $sformat(nome_op_temp, "SENO(%f)", grau);
                testar(SIN, xin, yin, zin, nome_op_temp, result_ref);
                #10;                                                    
            end
        end
        $fclose(file);
        #20;

        // Abre o arquivo de teste cosseno
        file = $fopen("test_cases_cos.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f,%f,%f\n",
           grau, xin, yin, zin, result_ref);
            
            if (r == 5) begin  // Verifica se leu todos os valores                
                // Teste do COSSENO
                $sformat(nome_op_temp, "COSSENO(%f)", grau);
                testar(COS, xin, yin, zin, nome_op_temp, result_ref);
                #10;                                                       
            end
        end
        $fclose(file);
        #20;

        // Abre o arquivo de teste multiplicação       
        file = $fopen("test_cases_mult.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f,%f\n",
           xin, yin, zin, result_ref);
            
            if (r == 4) begin  // Verifica se leu todos os valores
                 // Teste da MULTIPLICAÇÃO
                $sformat(nome_op_temp, "MULT(%f x %f)", xin, zin);
                testar(MULT, xin, yin, zin, nome_op_temp, result_ref);
                #10;
                end
            end
        $fclose(file);
        #20;

        // Abre o arquivo de teste divisão      
        file = $fopen("test_cases_div.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f,%f\n",
           yin, xin, zin, result_ref);
            
            if (r == 4) begin  // Verifica se leu todos os valores
                // Teste da DIVISÃO
                $sformat(nome_op_temp, "DIV(%f / %f)", yin, xin);
                testar(DIV, xin, yin, zin, nome_op_temp, result_ref);
                #10;
                end
            end
        $fclose(file);
        #20;

        // Abre o arquivo de módulo / magnitude   
        file = $fopen("test_cases_mod.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f,%f\n",
           xin, yin, zin, result_ref);
            
            if (r == 4) begin  // Verifica se leu todos os valores
                // Teste da modulo/magnitude
                $sformat(nome_op_temp, "MOD(%f / %f)", xin, yin);
                testar(MOD, xin, yin, zin, nome_op_temp, result_ref);
                #10;
                end
            end
        $fclose(file);
        #20;     

        // Abre o arquivo de teste arcotangente        
        file = $fopen("test_cases_atan.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f,%f\n",
           xin, yin, zin, result_ref);
            
            if (r == 4) begin  // Verifica se leu todos os valores
                // Teste da ARC TANGENTE
                $sformat(nome_op_temp, "ATAN(%f / %f)", xin, yin);
                testar(ATAN, xin, yin, zin, nome_op_temp, result_ref);
                #10;
                end
            end
        $fclose(file);
        #20;     
 
        //Abre o arquivo de teste seno Hiperbolico     
        file = $fopen("test_cases_sinh.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f,%f\n",
           xin, yin, zin, result_ref);
            
            if (r == 4) begin  // Verifica se leu todos os valores
                // Seno hiperbólico: sinh(1) ≈ 1.1752
                $sformat(nome_op_temp, "SINH(%f)", zin);
                testar(SINH, xin, yin, zin, nome_op_temp, result_ref);
                #10;
                end                     
            end
        $fclose(file);
        #20;
    

         // Abre o arquivo de teste coseno Hiperbolico 
        file = $fopen("test_cases_cosh.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f,%f\n",
           xin, yin, zin, result_ref);
            
            if (r == 4) begin  // Verifica se leu todos os valores     
                // Cosseno hiperbólico: cosh(1) ≈ 1.5430
                $sformat(nome_op_temp, "COSH(%f)", zin);
                testar(COSH, xin, yin, zin, nome_op_temp, result_ref);
                #10;  
                end
            end
        $fclose(file);
        #20;


        // Abre o arquivo de teste tangente hiperbolica     
        file = $fopen("test_cases_atanh.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f,%f,%f\n",
           xin, yin, zin, result_ref);
            
            if (r == 4) begin  // Verifica se leu todos os valores
                // Teste da ARC TANGENTE hiperbólico
                $sformat(nome_op_temp, "ATANH(%f - %f)", xin, yin);
                testar(ATANH, xin, yin, zin, nome_op_temp, result_ref);
                #10;
                end
            end
        $fclose(file);
        #20;

        // Abre o arquivo de teste magnitude hiperbolico   
        file = $fopen("test_cases_modh.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin

           r = $fscanf(file,"%f,%f,%f,%f\n",
           xin, yin, zin, result_ref);
            
            if (r == 4) begin  // Verifica se leu todos os valores
                // Teste da modulo hiperbólico
                $sformat(nome_op_temp, "MODH(%f - %f)", xin, yin);
                testar(MODH, xin, yin, zin, nome_op_temp, result_ref);
                #10;
            end
        end
        $fclose(file);
        #20;

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
        
        // Fecha o arquivo quando a simulação termina
        if (file_handle != 0) begin
            $fclose(file_handle);
            $display("=== Fim dos testes ===");           
            $display("Log de testes salvo em 'log_erros_testes.txt'");
        end

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