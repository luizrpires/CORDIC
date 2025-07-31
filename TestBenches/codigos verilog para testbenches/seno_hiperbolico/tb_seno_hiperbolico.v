`timescale 1ns / 1ps

module tb_seno_hiperbolico;

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
    integer file, r, grau, FD_CSV, FD_PRECISAO;
    real angle_rad, seno_ref, cos_ref, atan_ref, xin, zin, mult_ref, yin, 
            div_ref, zhin, sinh_ref, cosh_ref,mag_ref, magh_ref, atanh_ref;
    
    // String temporária para formatação
    reg [8*40:1] nome_op_temp;
    
    // Contador de erros
    integer error_count = 0, valores_count = 0;

    //Classificação do nível de erro
    real nivelErro;

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

            // Calcula o nível de erro relativo à quantidade de casas decimais
            if (error < 0.00001) nivelErro = 0;
                else if (error < 0.0001) nivelErro = 4;
                    else if (error < 0.001) nivelErro = 3;
                        else if (error < 0.01) nivelErro = 2;
                            else if (error < 0.1) nivelErro = 1;
                                else if (error < 1.0) nivelErro = 0;
                                    else nivelErro = -1;

            
            // Mostra apenas se erro > threshold
            if (error > ERROR_THRESHOLD) begin
                /*$display("ERRO em %s: Esperado=%f, Obtido=%f (Erro=%f)", 
                        nome_op, ref_val, r_result, error);*/
                error_count = error_count + 1;
            end
            valores_count = valores_count + 1;
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



        //=============== CODIGO DE TESTE ADICIONADO ==================//

        FD_CSV = $fopen("testbenches/seno_hiperbolico/resultadoTestes/CURVAS SENO HIPERBOLICO.csv", "w"); //ARQUIVO CSV
        if (!FD_CSV) begin
            $display("erro ao abrir CURVAS SENO HIPERBOLICO");
            $stop;
            $finish;
        end else begin $display("FD_CSV=%i",FD_CSV); end

        FD_PRECISAO = $fopen("testbenches/seno_hiperbolico/resultadoTestes/PRECISAO SENO HIPERBOLICO", "w"); //ESCRITA
        if (!FD_PRECISAO) begin
            $display("erro ao abrir NIVEIS SENO HIPERBOLICO");
            $stop;
            $finish;
        end else begin $display("FD_PRECISAO=%i",FD_PRECISAO); end


        //=============== TESTE DE OPERAÇÃO ESPECIFICA ================//


      //============ SENO Hiperbolico ===============//
         // Abre o arquivo de teste seno Hiperbolico    //teste 1000 -ok
        file = $fopen("tabelasTeste/tabela_seno_hiperbolico.txt","r");
        if (file == 0) begin 
            $display("Erro ao abrir tabela"); 
            $stop;
            $finish; 
        end

        // Lê e testa cada linha da tabela
        while (!$feof(file)) begin
           r = $fscanf(file,"%f,%f\n", zhin, sinh_ref);
            
            if (r == 2) begin  // Verifica se leu todos os 2 valores     
                // seno hiperbólico: SinH(1) ≈ 1.5430
                $sformat(nome_op_temp, "SINH(%f)", zhin);

                testar(SINH, 0.0, 0.0, zhin, nome_op_temp, sinh_ref);

                //============================================================//
                // Escreve no arquivo CSV
                $fwrite(FD_CSV, "%f,%f\n", zhin, $itor(result) / (1 << 16));
                $display(">>>> SinH(%f) = %f", zhin, $itor(result) / (1 << 16));
                $fwrite(FD_PRECISAO, "%f,%f\n", zhin, nivelErro);
                //============================================================//

                #100;  
                end
            end
        $fclose(file);
        #100;


        //=============== FIM DO TESTE DE OPERAÇÃO ESPECIFICA ================//

        $fclose(FD_CSV); //FECHA O ARQUIVO CSV
        $fclose(FD_PRECISAO); //FECHA O ARQUIVO PRECISAO

        // Mostra resultado final caso de sucesso
        if (error_count == 0) begin
            $display("\n====================================");
            $display(" SUCESSO: Todos os %0d valores passaram!", valores_count);
            $display("====================================\n");
        end else begin
            $display("\n====================================");
            $display(" ATENCÃO: %0d erros encontrados em %0d valores", error_count, valores_count);
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