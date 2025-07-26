module cordic_parallel_q16_32 #(
    parameter ITERATIONS = 16 //quantidade de iterações
)(
    clk, rst,
    enable,
    x_in, y_in, z_in,
    mode_op,
    mode_coord,
    x_out, y_out, z_out,
    valid
);
    localparam WIDTH = 32; //tamanho dos dados de entrada e saída

    input clk;
    input rst;
    input enable;
    input signed [WIDTH-1:0] x_in;
    input signed [WIDTH-1:0] y_in;
    input signed [WIDTH-1:0] z_in;
    input mode_op;
    input [1:0] mode_coord;
    output signed [WIDTH-1:0] x_out;
    output signed [WIDTH-1:0] y_out;
    output signed [WIDTH-1:0] z_out;
    output valid;

    localparam INTERNAL_WIDTH = 48; //WIDTH para cálculos internos (Q16.32)
    localparam FRACTIONAL_BITS = 32; //32 bits fracionários para Q16.32

    //VARIAVEIS PARA CORREÇÃO DO MODULO
    localparam signed [INTERNAL_WIDTH-1:0] K_INV_CIRCULAR   = 48'sd2608131496; // (0.6072529350088813 * 2^32)
    localparam signed [INTERNAL_WIDTH-1:0] K_CIRCULAR       = 48'sd7072781453; // (1.646760258121066 * 2^32)
    localparam signed [INTERNAL_WIDTH-1:0] K_INV_HYPERBOLIC = 48'sd5186160416; // (1.2074970677630726 * 2^32)
    localparam signed [INTERNAL_WIDTH-1:0] K_HYPERBOLIC     = 48'sd3556917369; // (0.8281593606 * 2^32)

    //MODO COORDENADA
    localparam CIRCULAR = 2'b01, //1 para Circular
               LINEAR = 2'b00, //0 para Linear
               HYPERBOLIC = 2'b11; //-1 para Hiperbólico
    //MODO OPERAÇÃO 
    localparam ROTATION = 1'b0, //0 para Rotação
               VECTORING = 1'b1; //1 para Vetorização

    localparam N = ITERATIONS;
    
    reg signed [INTERNAL_WIDTH-1:0] x_in_aux, y_in_aux, z_in_aux;
    reg signed [INTERNAL_WIDTH-1:0] x_out_aux, y_out_aux, z_out_aux;
    reg signed [2*INTERNAL_WIDTH-1:0] mult;
    reg completed;
    reg enable_start;
    wire done_iter[0:N-1];
    wire signed [INTERNAL_WIDTH-1:0] x[0:N], y[0:N], z[0:N];
    wire enable_iter[0:N];

    //CORREÇAO DE QUADRANTE PARA SENO E COSSENO
    wire signed [INTERNAL_WIDTH-1:0] z_tratado;
    wire [2:0] quadrante;
    wire done_corquad;
    wire enable_corquad;
    assign enable_corquad = (enable && mode_op==ROTATION && mode_coord==CIRCULAR) ? 1'b1 : 1'b0;
    correcao_quadrante_pi_4_q16_32 #(WIDTH, INTERNAL_WIDTH) corquad (clk, rst, enable_corquad, z_in, z_tratado, quadrante, done_corquad);

    //CORREÇAO DE Z PARA MULTIPLICAÇÃO
    wire signed [INTERNAL_WIDTH-1:0] z_reduzido;
    wire [3:0] cont_div;
    wire done_corz;
    wire enable_corz;
    assign enable_corz = (enable && mode_op==ROTATION && mode_coord==LINEAR) ? 1'b1 : 1'b0;
    corr_z_multi_q16_32 #(WIDTH, INTERNAL_WIDTH) corz (clk, rst, enable_corz, z_in, z_reduzido, cont_div, done_corz);

    always @(*) begin
        if (done_iter[N-1]) begin
            if (mode_op == VECTORING) begin
                if(mode_coord == HYPERBOLIC)begin
                    mult <= (x[N][INTERNAL_WIDTH-1] == 1) ? (-x[N] * K_INV_HYPERBOLIC) >>> FRACTIONAL_BITS : 
                                                           (x[N] * K_INV_HYPERBOLIC) >>> FRACTIONAL_BITS ;
                end else if(mode_coord == CIRCULAR)begin
                    mult <= (x[N][INTERNAL_WIDTH-1] == 1) ? (-x[N] * K_INV_CIRCULAR) >>> FRACTIONAL_BITS : 
                                                           (x[N] * K_INV_CIRCULAR) >>> FRACTIONAL_BITS ;
                end else
                    mult <= 0;
            end else begin
                mult <= 0;
            end            
        end else begin
            mult <= 0;
        end
    end

    //ENTRADAS
    always @(posedge clk or posedge rst) begin 
        if (rst) begin
            enable_start <= 0;
            x_in_aux <= 0;
            y_in_aux <= 0;
            z_in_aux <= 0;
        end else begin
            if (mode_op == ROTATION) begin
                if (mode_coord == CIRCULAR) begin
                    x_in_aux <= K_INV_CIRCULAR;
                    z_in_aux <= z_tratado;
                    enable_start <= done_corquad;
                end else if (mode_coord == HYPERBOLIC) begin
                    x_in_aux <= K_INV_HYPERBOLIC;
                    z_in_aux <= {z_in, {16{1'b0}}};
                    enable_start <= enable;  
                end else if (mode_coord == LINEAR) begin
                    x_in_aux <= {x_in, {16{1'b0}}};
                    z_in_aux <= z_reduzido;
                    enable_start <= done_corz;
                end else begin
                    x_in_aux <={x_in, {16{1'b0}}};
                    z_in_aux <= {z_in, {16{1'b0}}};   
                    enable_start <= enable;
                end
            end else begin
                x_in_aux <= {x_in, {16{1'b0}}};
                z_in_aux <= {z_in, {16{1'b0}}};       
                enable_start <= enable;
            end
            y_in_aux <= {y_in, {16{1'b0}}};
        end
    end

    //SAÍDAS
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_out_aux <= 0;
            y_out_aux <= 0;
            z_out_aux <= 0;
            completed <= 0;
        end else if (done_iter[N-1]) begin               
            if (mode_coord == CIRCULAR) begin
                if (mode_op == VECTORING) begin
                    x_out_aux <= mult;
                    y_out_aux <= y[N];
                end else begin                    
                    case (quadrante)
                        3'b000: begin // entre -45° e 45°
                            x_out_aux <= x[N];
                            y_out_aux <= y[N];
                        end
                        3'b001: begin // maior que 45° e menor ou igual a 135°
                            x_out_aux <= -y[N];
                            y_out_aux <= x[N];
                        end
                        3'b010: begin // maior que 135° e menor ou igual a 180° 
                            x_out_aux <= -x[N];
                            y_out_aux <= -y[N];
                        end
                        3'b011: begin // maior que 180° e menor ou igual a 225°
                            x_out_aux <= -x[N];
                            y_out_aux <= -y[N];
                        end
                        3'b100: begin  // maior que 225° e menor ou igual a 315° 
                            x_out_aux <= y[N];
                            y_out_aux <= -x[N];
                        end
                        default: begin
                            x_out_aux <= x[N];
                            y_out_aux <= y[N];
                        end
                    endcase
                end
                z_out_aux <= z[N];
            end else if (mode_coord == HYPERBOLIC) begin
                x_out_aux <= (mode_op == VECTORING) ? mult : x[N];
                y_out_aux <= y[N];
                z_out_aux <= z[N];
            end else begin //(mode_coord == LINEAR)
                x_out_aux <= x[N];
                y_out_aux <= (mode_op == ROTATION) ? (y[N] <<< cont_div) : y[N];
                z_out_aux <= z[N];
            end
            completed <= 1;
        end else begin
            x_out_aux <= 0;
            y_out_aux <= 0;
            z_out_aux <= 0;
            completed <= 0;
        end
    end

    assign enable_iter[0] = enable_start;
    assign x[0] = x_in_aux;
    assign y[0] = y_in_aux;
    assign z[0] = z_in_aux;

    genvar i;
    generate
        for (i = 0; i < ITERATIONS; i = i + 1) begin
            cordic_calc_parallel_q16_32 #(
                .I(i),          //iteração atual
                .ITERATIONS(N), //quantidade de iterações
                .WIDTH(INTERNAL_WIDTH)   //tamanho dos dados de entrada e saída
            ) cordic_calc_inst (
                .clk(clk),
                .rst(rst), 
                .enable(enable_iter[i]),
                .x_in(x[i]),
                .y_in(y[i]),
                .z_in(z[i]),    
                .mode_op(mode_op),
                .mode_coord(mode_coord),
                .x_out(x[i+1]),
                .y_out(y[i+1]),
                .z_out(z[i+1]),
                .done(done_iter[i]));

            assign enable_iter[i+1] = done_iter[i];
        end
    endgenerate

    // Saídas
    assign x_out = x_out_aux[INTERNAL_WIDTH-1 : FRACTIONAL_BITS-16]; // Pega os 32 bits mais significativos
    assign y_out = y_out_aux[INTERNAL_WIDTH-1 : FRACTIONAL_BITS-16];
    assign z_out = z_out_aux[INTERNAL_WIDTH-1 : FRACTIONAL_BITS-16];
    assign valid = completed;

endmodule

module cordic_calc_parallel_q16_32 #( 
    parameter I = 0, //iteração atual
    parameter ITERATIONS = 16, //quantidade de iterações
    parameter WIDTH = 48 //tamanho dos dados de entrada e saída
)(
    input clk,
    input rst, 
    input enable,
    input signed [WIDTH-1:0] x_in,
    input signed [WIDTH-1:0] y_in,
    input signed [WIDTH-1:0] z_in,    
    input mode_op,
    input [1:0] mode_coord,
    output signed [WIDTH-1:0] x_out,
    output signed [WIDTH-1:0] y_out,
    output signed [WIDTH-1:0] z_out,
    output done
);
    //MODO COORDENADA
    localparam  CIRCULAR = 2'b01, //1 para Circular
                LINEAR = 2'b00, //0 para Linear
                HYPERBOLIC = 2'b11; //-1 para Hiperbólico

    //MODO OPERAÇÃO 
    localparam  ROTATION = 1'b0, //0 para Rotação
                VECTORING = 1'b1; //1 para Vetorização

    
    wire [$clog2(ITERATIONS)-1:0] iteration;
    wire signed [WIDTH-1:0] alpha;
    wire signed [WIDTH-1:0] x_shift,y_shift;
    reg sigma;
    reg signed [WIDTH-1:0] next_X, next_Y, next_Z;
    reg done_calc;

    assign iteration = (mode_coord == HYPERBOLIC) ? iter_index_hyperbolic(I) : I;

    assign alpha =  (mode_coord == CIRCULAR)   ? circular_lut(iteration) : 
                    (mode_coord == LINEAR)     ? linear_lut(iteration) : 
                    (mode_coord == HYPERBOLIC) ? hyperbolic_lut(iteration) : 48'sd0;

    always @(*) begin
        if (mode_op == ROTATION) begin
            if (z_in[WIDTH-1] == 1'b0) begin //testa se Z é positivo
                sigma <= 1'b1; //1 para +1
            end else begin
                sigma <= 1'b0; //0 para -1
            end
        end else begin //modo vetorização
            if (y_in[WIDTH-1] == x_in[WIDTH-1]) begin // testa se Y e X têm o mesmo sinal
                sigma <= 1'b0; //0 para -1
            end else begin
                sigma <= 1'b1; //1 para +1
            end
        end
    end
    
    assign x_shift = x_in >>> iteration;
    assign y_shift = y_in >>> iteration;

    always @(*) begin
        if (rst) begin
            next_X    <= 0;
            next_Y    <= 0;
            next_Z    <= 0;
            done_calc <= 0;
        end else if (enable) begin
            case (mode_coord)
                //xi+1 = xi − μ σi yi 2^−i
                //yi+1 = yi + σi xi 2^−i
                //zi+1 = zi − σi αi
                CIRCULAR: begin // m = 1
                    next_X <= x_in - (sigma ? y_shift : -y_shift);
                    next_Y <= y_in + (sigma ? x_shift : -x_shift);
                    next_Z <= z_in - (sigma ? alpha : -alpha);
                end

                LINEAR: begin // m = 0
                    next_X <= x_in;
                    next_Y <= y_in + (sigma ? x_shift : -x_shift);
                    next_Z <= z_in - (sigma ? alpha : -alpha);
                end

                HYPERBOLIC: begin // m = -1
                    next_X <= x_in + (sigma ? y_shift : -y_shift);
                    next_Y <= y_in + (sigma ? x_shift : -x_shift);
                    next_Z <= z_in - (sigma ? alpha : -alpha);
                end
                
                default: begin
                    next_X <= x_in;
                    next_Y <= y_in;
                    next_Z <= z_in;
                end
            endcase
            done_calc <= 1;
        end else begin
            next_X    <= 0;
            next_Y    <= 0;
            next_Z    <= 0;
            done_calc <= 0;
        end
    end

    assign x_out = next_X;
    assign y_out = next_Y;
    assign z_out = next_Z;
    assign done  = done_calc;



    //Função para repetir as iterações 4 e 13 no modo hiperbólico
    function [$clog2(ITERATIONS)-1:0] iter_index_hyperbolic;
        input integer iter;
        
        if (iter >= 0 && iter <= 3) begin
            iter_index_hyperbolic = iter + 1;
        end else if (iter >= 14 && iter < ITERATIONS) begin
            iter_index_hyperbolic = iter - 1;
        end else begin
            iter_index_hyperbolic = iter;
        end
    endfunction

    // Funções LUTs atualizadas para retornar valores em Q16.32
    function signed [WIDTH-1:0] circular_lut;
        input integer index;
        case (index)
            0:  circular_lut = 48'sd3373259426;   // atan(2^0) = 0.7853981633974483 * 2^32
            1:  circular_lut = 48'sd1991351318;   // atan(2^-1) = 0.4636476090008061 * 2^32
            2:  circular_lut = 48'sd1052175346;   // atan(2^-2) = 0.24497866312686414 * 2^32
            3:  circular_lut = 48'sd534100635;    // atan(2^-3) = 0.12435499454676144 * 2^32
            4:  circular_lut = 48'sd268086748;    // atan(2^-4) = 0.06241880999595735 * 2^32
            5:  circular_lut = 48'sd134174063;    // atan(2^-5) = 0.031239833430268277 * 2^32
            6:  circular_lut = 48'sd67103403;     // atan(2^-6) = 0.015623728620476831 * 2^32
            7:  circular_lut = 48'sd33553749;     // atan(2^-7) = 0.007812341060101111 * 2^32
            8:  circular_lut = 48'sd16777131;     // atan(2^-8) = 0.0039062301319669718 * 2^32
            9:  circular_lut = 48'sd8388597;      // atan(2^-9) = 0.0019531225164788188 * 2^32
            10: circular_lut = 48'sd4194303;      // atan(2^-10) = 0.0009765621895593195 * 2^32
            11: circular_lut = 48'sd2097152;      // atan(2^-11) = 0.0004882812111948983 * 2^32
            12: circular_lut = 48'sd1048576;      // atan(2^-12) = 0.00024414062014936177 * 2^32
            13: circular_lut = 48'sd524288;       // atan(2^-13) = 0.00012207031189367021 * 2^32
            14: circular_lut = 48'sd262144;       // atan(2^-14) = 0.00006103515617420877 * 2^32
            15: circular_lut = 48'sd131072;       // atan(2^-15) = 0.00003051757811552610 * 2^32
            16: circular_lut = 48'sd65536;        // atan(2^-16) = 0.000015258789061315762 * 2^32
            17: circular_lut = 48'sd32768;        // atan(2^-17) = 0.00000762939453110197 * 2^32
            18: circular_lut = 48'sd16384;        // atan(2^-18) = 0.000003814697265606496 * 2^32
            19: circular_lut = 48'sd8192;         // atan(2^-19) = 0.000001907348632810187 * 2^32
            20: circular_lut = 48'sd4096;         // atan(2^-20) = 0.0000009536743164059608 * 2^32
            21: circular_lut = 48'sd2048;         // atan(2^-21) = 0.00000047683715820308884 * 2^32
            22: circular_lut = 48'sd1024;         // atan(2^-22) = 0.000000238417669535 * 2^32
            23: circular_lut = 48'sd512;          // atan(2^-23) = 0.000000119208834768 * 2^32
            24: circular_lut = 48'sd256;          // atan(2^-24) = 0.000000059604417384 * 2^32
            25: circular_lut = 48'sd128;          // atan(2^-25) = 0.000000029802208692 * 2^32
            26: circular_lut = 48'sd64;           // atan(2^-26) = 0.000000014901104346 * 2^32
            27: circular_lut = 48'sd32;           // atan(2^-27) = 0.000000007450580596923828 * 2^32
            28: circular_lut = 48'sd16;           // atan(2^-28) = 0.000000003725290298461914 * 2^32
            29: circular_lut = 48'sd8;            // atan(2^-29) = 0.000000001862645149230957 * 2^32
            30: circular_lut = 48'sd4;            // atan(2^-30) = 0.0000000009313225746154785 * 2^32
            31: circular_lut = 48'sd2;            // atan(2^-31) = 0.0000000004656612873077393 * 2^32
            32: circular_lut = 48'sd1;            // atan(2^-32) = 0.00000000023283064365386963 * 2^32
            default: circular_lut = {WIDTH{1'b0}};
        endcase
    endfunction

    function signed [WIDTH-1:0] linear_lut;
        input integer index;
        case (index)
            0 : linear_lut = 48'sd4294967296; // 2^0   = 1.0
            1 : linear_lut = 48'sd2147483648; // 2^-1  = 0.5
            2 : linear_lut = 48'sd1073741824; // 2^-2  = 0.25
            3 : linear_lut = 48'sd536870912;  // 2^-3  = 0.125
            4 : linear_lut = 48'sd268435456;  // 2^-4  = 0.0625
            5 : linear_lut = 48'sd134217728;  // 2^-5  = 0.03125
            6 : linear_lut = 48'sd67108864;   // 2^-6  = 0.015625
            7 : linear_lut = 48'sd33554432;   // 2^-7  = 0.0078125
            8 : linear_lut = 48'sd16777216;   // 2^-8  = 0.00390625
            9 : linear_lut = 48'sd8388608;    // 2^-9  = 0.001953125
            10: linear_lut = 48'sd4194304;    // 2^-10 = 0.0009765625
            11: linear_lut = 48'sd2097152;    // 2^-11 = 0.00048828125
            12: linear_lut = 48'sd1048576;    // 2^-12 = 0.000244140625
            13: linear_lut = 48'sd524288;     // 2^-13 = 0.0001220703125
            14: linear_lut = 48'sd262144;     // 2^-14 = 0.00006103515625
            15: linear_lut = 48'sd131072;     // 2^-15 = 0.000030517578125
            16: linear_lut = 48'sd65536;      // 2^-16 = 0.0000152587890625
            17: linear_lut = 48'sd32768;      // 2^-17 = 0.00000762939453125
            18: linear_lut = 48'sd16384;      // 2^-18 = 0.000003814697265625
            19: linear_lut = 48'sd8192;       // 2^-19 = 0.0000019073486328125
            20: linear_lut = 48'sd4096;       // 2^-20 = 0.00000095367431640625
            21: linear_lut = 48'sd2048;       // 2^-21 = 0.000000476837158203125
            22: linear_lut = 48'sd1024;       // 2^-22 = 0.0000002384185791015625
            23: linear_lut = 48'sd512;        // 2^-23 = 0.00000011920928955078125
            24: linear_lut = 48'sd256;        // 2^-24 = 0.000000059604644775390625
            25: linear_lut = 48'sd128;        // 2^-25 = 0.0000000298023223876953125
            26: linear_lut = 48'sd64;         // 2^-26 = 0.00000001490116119384765625
            27: linear_lut = 48'sd32;         // 2^-27 = 0.000000007450580596923828125
            28: linear_lut = 48'sd16;         // 2^-28 = 0.0000000037252902984619140625
            29: linear_lut = 48'sd8;          // 2^-29 = 0.00000000186264514923095703125
            30: linear_lut = 48'sd4;          // 2^-30 = 0.000000000931322574615478515625
            31: linear_lut = 48'sd2;          // 2^-31 = 0.0000000004656612873077392578125
            32: linear_lut = 48'sd1;          // 2^-32 = 0.00000000023283064365386962890625

            default: linear_lut = {WIDTH{1'b0}};
        endcase
    endfunction

    function signed [WIDTH-1:0] hyperbolic_lut;
        input integer index;
        case (index)
            1 : hyperbolic_lut = 48'sd2360218706; // atanh(2^-1) = 0.5493061443340548 * 2^32
            2 : hyperbolic_lut = 48'sd1097207604; // atanh(2^-2) = 0.25541281188299536 * 2^32
            3 : hyperbolic_lut = 48'sd539459048;  // atanh(2^-3) = 0.12565721414045303 * 2^32
            4 : hyperbolic_lut = 48'sd269726207;  // atanh(2^-4) = 0.06258157147700301 * 2^32
            5 : hyperbolic_lut = 48'sd134863077;  // atanh(2^-5) = 0.03126017849066601 * 2^32
            6 : hyperbolic_lut = 48'sd67431445;   // atanh(2^-6) = 0.015626271752052268 * 2^32
            7 : hyperbolic_lut = 48'sd33715690;   // atanh(2^-7) = 0.007812658951540407 * 2^32
            8:  hyperbolic_lut = 48'sd16857827;   // atanh(2^-8) = 0.003906269868396824 * 2^32
            9:  hyperbolic_lut = 48'sd8428905;    // atanh(2^-9) = 0.0019531274835325495 * 2^32
            10: hyperbolic_lut = 48'sd4214449;    // atanh(2^-10) = 0.0009765628104402821 * 2^32
            11: hyperbolic_lut = 48'sd2107223;    // atanh(2^-11) = 0.00048828128880511276 * 2^32
            12: hyperbolic_lut = 48'sd1053611;    // atanh(2^-12) = 0.00024414062577522435 * 2^32
            13: hyperbolic_lut = 48'sd526805;     // atanh(2^-13) = 0.00012207031256109824 * 2^32
            14: hyperbolic_lut = 48'sd263402;     // atanh(2^-14) = 0.00006103515628126425 * 2^32
            15: hyperbolic_lut = 48'sd131701;     // atanh(2^-15) = 0.00003051757813447362 * 2^32
            16: hyperbolic_lut = 48'sd65850;      // atanh(2^-16) = 0.000015258789063284947 * 2^32
            17: hyperbolic_lut = 48'sd32925;      // atanh(2^-17) = 0.000007629394531398018 * 2^32
            18: hyperbolic_lut = 48'sd16462;      // atanh(2^-18) = 0.000003814697265643503 * 2^32
            19: hyperbolic_lut = 48'sd8231;       // atanh(2^-19) = 0.000001907348632812118 * 2^32
            20: hyperbolic_lut = 48'sd4096;       // atanh(2^-20) = 0.000000953674316406250 * 2^32
            21: hyperbolic_lut = 48'sd2048;       // atanh(2^-21) = 0.000000476837158203125 * 2^32
            22: hyperbolic_lut = 48'sd1023;       // atanh(2^-22) = 0.000000238418579101562 * 2^32
            23: hyperbolic_lut = 48'sd511;        // atanh(2^-23) = 0.000000119209289550781 * 2^32
            24: hyperbolic_lut = 48'sd255;        // atanh(2^-24) = 0.000000059604644775391 * 2^32
            25: hyperbolic_lut = 48'sd127;        // atanh(2^-25) = 0.000000029802322387695 * 2^32
            26: hyperbolic_lut = 48'sd63;         // atanh(2^-26) = 0.000000014901161193848 * 2^32
            27: hyperbolic_lut = 48'sd31;         // atanh(2^-27) = 0.000000007450580596924 * 2^32
            28: hyperbolic_lut = 48'sd15;         // atanh(2^-28) = 0.000000003725290298462 * 2^32
            29: hyperbolic_lut = 48'sd7;          // atanh(2^-29) = 0.000000001862645149231 * 2^32
            30: hyperbolic_lut = 48'sd4;          // atanh(2^-30) = 0.000000000931322574615 * 2^32 
            31: hyperbolic_lut = 48'sd2;          // atanh(2^-31) = 0.000000000465661287308 * 2^32 
            32: hyperbolic_lut = 48'sd1;          // atanh(2^-32) = 0.000000000232830643654 * 2^32 
            default: hyperbolic_lut = {WIDTH{1'b0}};
        endcase
    endfunction

endmodule