


module GeradorDeTabelasCORDIC();
    // Variáveis para os arquivos
    integer FD_CSV;

    real x, y, z;

    initial begin

        //=============== GERAÇÃO DAS TABELAS ================//


        // Cria o arquivo COSSENO
        FD_CSV = $fopen("tabelasTeste/tabela_cosseno.txt", "w"); //ARQUIVO CSV
        if (!FD_CSV) begin
            $display("erro ao abrir tabela_cosseno");
            $stop;
            $finish;
        end else begin $display("FD_COS=%i",FD_CSV); end

        // Gera os valores de x e y para a tabela de COSENO
        x = 0.0;
        y = 0.0;
        for(z=-6.283; z <= 6.283; z = z + 0.0056) begin
            //$display("COS(%f)=%f", z, $cos(z));
            // Escreve os valores no arquivo CSV
            $fwrite(FD_CSV, "%f,%f\n", z, $cos(z));
        end
                //============================================//
        // ENCERRA A TABELA DE TESTES
        #10;
        $fclose(FD_CSV); //FECHA O ARQUIVO CSV



        // Cria o arquivo SENO
        FD_CSV = $fopen("tabelasTeste/tabela_seno.txt", "w"); //ARQUIVO CSV
        if (!FD_CSV) begin
            $display("erro ao abrir tabela_seno");
            $stop;
            $finish;
        end else begin $display("FD_SENO=%i",FD_CSV); end

        // Gera os valores de x e y para a tabela de COSENO
        x = 0.0;
        y = 0.0;
        for(z=-6.283; z <= 6.283; z = z + 0.0056) begin
            //$display("SENO(%f)=%f", z, $sin(z));
            // Escreve os valores no arquivo CSV
            $fwrite(FD_CSV, "%f,%f\n", z, $sin(z));
        end
                //============================================//
        // ENCERRA A TABELA DE TESTES
        #10;
        $fclose(FD_CSV); //FECHA O ARQUIVO CSV



        // Abre o arquivo DIVISAO
        FD_CSV = $fopen("tabelasTeste/tabela_divisao.txt", "w"); //ARQUIVO CSV
        if (!FD_CSV) begin
            $display("erro ao abrir tabela_divisao");
            $stop;
            $finish;
        end else begin $display("FD_DIV=%i",FD_CSV); end


        // Gera os valores de x e y para a tabela de divisão
        for(y = -30000; y <= 30000; y = y + 2213) begin
            for (x = -30000; x < 30000; x = x + 547) begin 
                z = y / x;
                $fwrite(FD_CSV, "%f,%f,%f\n", x, y, z);
            end
        end



        //============ MULTIPLICAÇÃO ===============// OK
        // Abre o arquivo MULTIPLICAÇÃO
        FD_CSV = $fopen("tabelasTeste/tabela_multiplicacao.txt", "w"); //ARQUIVO CSV
        if (!FD_CSV) begin
            $display("erro ao abrir tabela_multiplicacao");
            $stop;
            $finish;
        end else begin $display("FD_MULT=%i",FD_CSV); end


        // Gera os valores de x e y para a tabela de MULTIPLICAÇÃO
        for(y = -600; y < 600; y = y + 40) begin
            for (x = -127; x <= 127; x = x + 5) begin 
                z = y + x;
                $fwrite(FD_CSV, "%f,%f,%f\n", x, y, x * y);
            end
        end
                // ENCERRA A TABELA DE TESTES
        $fclose(FD_CSV); //FECHA O ARQUIVO CSV




        // Abre o arquivo SENO HIPERBOLICO
        FD_CSV = $fopen("tabelasTeste/tabela_seno_hiperbolico.txt", "w"); //ARQUIVO CSV
        if (!FD_CSV) begin
            $display("erro ao abrir tabela_seno_hiperbolico");
            $stop;
            $finish;
        end else begin $display("FD_SENH=%i",FD_CSV); end

        // Gera os valores de x e y para a tabela de SENO HIPERBOLICO
        x = 0.0;
        y = 0.0;
        for(z=-2.2; z <= 2.2 ; z = z + 0.01) begin
            // Escreve os valores no arquivo CSV
            $fwrite(FD_CSV, "%f,%f\n", z, $sinh(z));
        end
        #10;
        $fclose(FD_CSV);



        // Abre o arquivo COSSENO HIPERBOLICO
        FD_CSV = $fopen("tabelasTeste/tabela_cosseno_hiperbolico.txt", "w"); //ARQUIVO CSV
        if (!FD_CSV) begin
            $display("erro ao abrir tabela_cosseno_hiperbolico");
            $stop;
            $finish;
        end else begin $display("FD_COSH=%i",FD_CSV); end

        // Gera os valores de x e y para a tabela de SENO HIPERBOLICO
        x = 0.0;
        y = 0.0;
        for(z=-6.28; z <= 6.28; z = z + 0.01) begin
            // Escreve os valores no arquivo CSV
            $fwrite(FD_CSV, "%f,%f\n", z, $cosh(z));
        end
        #10;
        $fclose(FD_CSV);



        //============ ARCO TANGENTE ===============// OK
        // Abre o arquivo ARCO TANGENTE
        FD_CSV = $fopen("tabelasTeste/tabela_arcotangente.txt", "w"); //ARQUIVO CSV
        if (!FD_CSV) begin
            $display("erro ao abrir tabela_arco_tangente");
            $stop;
            $finish;
        end else begin $display("FD_atan=%i",FD_CSV); end

        // Gera os valores de x e y para a tabela de ARCO TANGENTE HIPERBOLICO
        x = 0.0;
        y = 0.0;
        for(x=-10000.0; x <= 10000.0; x = x + 1303.31) begin
            for(y=-15000.0; y <= 15000.0; y = y + 100.31) begin
                // Escreve os valores no arquivo CSV
                //if (((y/x)>(-1.57)) & ((y/x)<(1.57))) //somente valores na faixa -PI/2 até +PI/2
                $fwrite(FD_CSV, "%f,%f,%f\n", x, y, $atan(y/x));
            end
        end
        #10;
        $fclose(FD_CSV);


        //============ ARCO TANGENTE HIPERBOLICO ===============//
        // Abre o arquivo ARCO TANGENTE HIPERBOLICO
        FD_CSV = $fopen("tabelasTeste/tabela_arcotangente_hiperbolico.txt", "w"); //ARQUIVO CSV
        if (!FD_CSV) begin
            $display("erro ao abrir tabela_arco_tangente_hiperbolico");
            $stop;
            $finish;
        end else begin $display("FD_atanh=%i",FD_CSV); end

        // Gera os valores de x e y para a tabela de ARCO TANGENTE HIPERBOLICO
        x = 0.0;
        y = 0.0;
        for(y=-20000.0; y <= 20000.0; y = y + 2326.31) begin
            for(x=-15000.0; x <= 15000.0; x = x + 152.31) begin
                // Escreve os valores no arquivo CSV
                if (((y/x)>(-1)) & ((y/x)<(1))) //somente valores na faixa -1 até +1
                        $fwrite(FD_CSV, "%f,%f,%f\n", x, y, $atanh(y/x));
            end
        end
        #10;
        $fclose(FD_CSV);


        //============ MAGNITUDE ===============// OK
        // Abre o arquivo MAGNITUDE
        FD_CSV = $fopen("tabelasTeste/tabela_magnitude.txt", "w"); //ARQUIVO CSV
        if (!FD_CSV) begin
            $display("erro ao abrir tabela_magnitude");
            $stop;
            $finish;
        end else begin $display("FD_MOD=%i",FD_CSV); end


        // Gera os valores de x e y para a tabela de MULTIPLICAÇÃO
        for(y = -10000; y < 10000; y = y + 1000) begin
            for (x = -10000; x <= 10000; x = x + 100) begin 
                $fwrite(FD_CSV, "%f,%f,%f\n", x, y, $sqrt(x*x + y*y));
            end
        end
        #10;
        $fclose(FD_CSV); //FECHA O ARQUIVO CSV




        //============ MAGNITUDE HIPERBOLICA ===============// OK
        // Abre o arquivo MAGNITUDE HIPERBOLICA
        FD_CSV = $fopen("tabelasTeste/tabela_magnitude_hiperbolica.txt", "w"); //ARQUIVO CSV
        if (!FD_CSV) begin
            $display("erro ao abrir tabela_magnitude_hiperbolica");
            $stop;
            $finish;
        end else begin $display("FD_MODH=%i",FD_CSV); end


        // Gera os valores de x e y para a tabela de MULTIPLICAÇÃO
        for(y = -10000; y < 10000; y = y + 1000) begin
            for (x = -10000; x <= 10000; x = x + 100) begin 
                if (x*x - y*y >= 0) // Verifica se a raiz é válida
                    $fwrite(FD_CSV, "%f,%f,%f\n", x, y, $sqrt(x*x - y*y));
            end
        end
        #10;
        $fclose(FD_CSV); //FECHA O ARQUIVO CSV



    end

    
endmodule
