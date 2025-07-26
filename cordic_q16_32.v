module cordic_q16_32 #(
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

    localparam signed [INTERNAL_WIDTH-1:0] K_INV_CIRCULAR   = 48'sd2608131496; // (0.6072529350088813 * 2^32)
    localparam signed [INTERNAL_WIDTH-1:0] K_CIRCULAR       = 48'sd7072781453; // (1.646760258121066 * 2^32)
    localparam signed [INTERNAL_WIDTH-1:0] K_INV_HYPERBOLIC = 48'sd5186160416; // (1.2074970677630726 * 2^32)
    localparam signed [INTERNAL_WIDTH-1:0] K_HYPERBOLIC     = 48'sd3556917369; // (0.8281593606 * 2^32)

    //MODO COORDENADA
    localparam  CIRCULAR   = 2'b01, //1 para Circular
                LINEAR     = 2'b00, //0 para Linear
                HYPERBOLIC = 2'b11; //-1 para Hiperbólico

    //MODO OPERAÇÃO 
    localparam  ROTATION  = 1'b0, //0 para Rotação
                VECTORING = 1'b1; //1 para Vetorização

    //ESTADOS
    localparam  IDLE       = 2'b00,
                INITIALIZE = 2'b01,
                UPDATE     = 2'b10,
                FINALIZE   = 2'b11;


    reg [1:0] state, next_state;
    reg [$clog2(ITERATIONS)-1:0] iter_counter; 
    reg signed [INTERNAL_WIDTH-1:0] reg_X, reg_Y, reg_Z, next_X, next_Y, next_Z, X_out_aux, Y_out_aux, Z_out_aux;
    wire signed [INTERNAL_WIDTH-1:0] shift_X, shift_Y;
    wire signed [INTERNAL_WIDTH-1:0] alpha;
    reg sigma; // Sinal de direção: 0 para sinal neg, 1 para sinal pos
    reg hyperbolic_4, hyperbolic_13; // Sinais de controle para iterações específicas no modo hiperbólico
    reg completed; //Sinal para indicar que o cálculo está concluído
    reg signed [2*INTERNAL_WIDTH-1:0] mult_x; // Variável para calcular ganho de X

    // Convertendo entrada Q16.16 para Q16.32 para uso interno
    wire signed [INTERNAL_WIDTH-1:0] X_in_aux;
    wire signed [INTERNAL_WIDTH-1:0] Y_in_aux;
    wire signed [INTERNAL_WIDTH-1:0] Z_in_aux;
    assign X_in_aux = {x_in, {16{1'b0}}};
    assign Y_in_aux = {y_in, {16{1'b0}}};
    assign Z_in_aux = {z_in, {16{1'b0}}};

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

    //Lógica para definir a direção da rotação ou vetorização
    always @(*) begin
        if (mode_op == ROTATION) begin
            if (reg_Z[INTERNAL_WIDTH-1] == 1'b0) begin //testa se Z é positivo
                sigma <= 1'b1; //1 para +1
            end else begin
                sigma <= 1'b0; //0 para -1
            end
        end else begin //modo vetorização
            if (reg_Y[INTERNAL_WIDTH-1] == reg_X[INTERNAL_WIDTH-1]) begin // testa se Y e X têm o mesmo sinal
                sigma <= 1'b0; //0 para -1
            end else begin // Y e X têm sinais opostos
                sigma <= 1'b1; //1 para +1
            end            
        end
    end

    // Shift registers
    assign shift_X = reg_X >>> iter_counter;
    assign shift_Y = reg_Y >>> iter_counter;

    // Atualização de alpha
    assign alpha =  (mode_coord == CIRCULAR)   ? circular_lut(iter_counter) : 
                    (mode_coord == LINEAR)     ? linear_lut(iter_counter) : 
                    (mode_coord == HYPERBOLIC) ? hyperbolic_lut(iter_counter) : {INTERNAL_WIDTH{1'b0}};

    // cálculo do ganho K no final da operação
    always @(*) begin
        if (rst) begin
            mult_x <= {2*INTERNAL_WIDTH{1'b0}};
        end else begin
            if (state == FINALIZE) begin
                if (mode_op == VECTORING) begin
                    if(mode_coord == HYPERBOLIC)begin
                        mult_x <= (reg_X[INTERNAL_WIDTH-1] == 1'b1) ? (-reg_X * K_INV_HYPERBOLIC) >>> FRACTIONAL_BITS : (reg_X * K_INV_HYPERBOLIC) >>> FRACTIONAL_BITS;
                    end else if(mode_coord == CIRCULAR)begin
                        mult_x <= (reg_X[INTERNAL_WIDTH-1] == 1'b1) ? (-reg_X * K_INV_CIRCULAR) >>> FRACTIONAL_BITS : (reg_X * K_INV_CIRCULAR) >>> FRACTIONAL_BITS;
                    end else
                        mult_x <= {2*INTERNAL_WIDTH{1'b0}};
                end else 
                mult_x <= {2*INTERNAL_WIDTH{1'b0}};
            end else 
                mult_x <= {2*INTERNAL_WIDTH{1'b0}};
        end
    end
   
    // executa os cálculos do cordic generalizado
    always @(*)begin
        if (rst) begin
            next_X <= {INTERNAL_WIDTH{1'b0}}; 
            next_Y <= {INTERNAL_WIDTH{1'b0}};
            next_Z <= {INTERNAL_WIDTH{1'b0}};
        end else begin
            case (mode_coord)
                //xi+1 = xi − μ σi yi 2^−i
                //yi+1 = yi + σi xi 2^−i
                //zi+1 = zi − σi αi
                CIRCULAR: begin // m = 1
                    next_X <= reg_X - (sigma ? shift_Y : -shift_Y);
                    next_Y <= reg_Y + (sigma ? shift_X : -shift_X);
                    next_Z <= reg_Z - (sigma ? alpha : -alpha);
                end

                LINEAR: begin // m = 0
                    next_X <= reg_X;
                    next_Y <= reg_Y + (sigma ? shift_X : -shift_X);
                    next_Z <= reg_Z - (sigma ? alpha : -alpha);
                end

                HYPERBOLIC: begin // m = -1
                    next_X <= reg_X + (sigma ? shift_Y : -shift_Y);
                    next_Y <= reg_Y + (sigma ? shift_X : -shift_X);
                    next_Z <= reg_Z - (sigma ? alpha : -alpha);
                end

                default: begin
                    next_X <= reg_X;
                    next_Y <= reg_Y;
                    next_Z <= reg_Z;
                end
            endcase
        end
    end

    //Lógica de transição de estados
    always @(*) begin
        case (state)
            IDLE:
                next_state <= (enable) ? INITIALIZE : IDLE;
            INITIALIZE:
                if (mode_op == ROTATION) begin
                    if (mode_coord == CIRCULAR)
                        next_state <= (~done_corquad) ? INITIALIZE : UPDATE;
                    else if (mode_coord == LINEAR)
                        next_state <= (~done_corz) ? INITIALIZE : UPDATE;
                    else
                        next_state <= UPDATE;
                end else begin
                    next_state <= UPDATE;
                end
            UPDATE:
                next_state <= (iter_counter == ITERATIONS-1) ? FINALIZE : UPDATE;
            FINALIZE:
                next_state <= IDLE;
            default:
                next_state <= IDLE;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            iter_counter  <= {$clog2(ITERATIONS){1'b0}};
            reg_X         <= {INTERNAL_WIDTH{1'b0}};
            reg_Y         <= {INTERNAL_WIDTH{1'b0}};
            reg_Z         <= {INTERNAL_WIDTH{1'b0}};
            X_out_aux     <= {INTERNAL_WIDTH{1'b0}};
            Y_out_aux     <= {INTERNAL_WIDTH{1'b0}};
            Z_out_aux     <= {INTERNAL_WIDTH{1'b0}};
            completed     <= 1'b0;
            hyperbolic_4  <= 1'b1;
            hyperbolic_13 <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    iter_counter  <= {$clog2(ITERATIONS){1'b0}};
                    reg_X         <= {INTERNAL_WIDTH{1'b0}};
                    reg_Y         <= {INTERNAL_WIDTH{1'b0}};
                    reg_Z         <= {INTERNAL_WIDTH{1'b0}};
                    X_out_aux     <= {INTERNAL_WIDTH{1'b0}};
                    Y_out_aux     <= {INTERNAL_WIDTH{1'b0}};
                    Z_out_aux     <= {INTERNAL_WIDTH{1'b0}};
                    completed     <= 1'b0;
                    hyperbolic_4  <= 1'b1;
                    hyperbolic_13 <= 1'b1;
                end

                INITIALIZE: begin
                    iter_counter <= (mode_coord == HYPERBOLIC) ? 1'b1 : 1'b0;
                    
                    if (mode_op == ROTATION) begin
                        if (mode_coord == CIRCULAR) begin 
                            reg_X <= K_INV_CIRCULAR;
                            reg_Z <= z_tratado; 
                        end else if (mode_coord == HYPERBOLIC) begin
                            reg_X <= K_INV_HYPERBOLIC;
                            reg_Z <= Z_in_aux;
                        end else if (mode_coord == LINEAR) begin
                            reg_X <= X_in_aux;
                            reg_Z <= z_reduzido;
                        end else begin
                            reg_X <= X_in_aux;
                            reg_Z <= Z_in_aux;
                        end
                    end else begin
                        reg_X <= X_in_aux;
                        reg_Z <= Z_in_aux; 
                    end

                    reg_Y <= Y_in_aux;
                end

                UPDATE: begin
                    reg_X <= next_X;
                    reg_Y <= next_Y;
                    reg_Z <= next_Z;

                    // Incrementa o contador de iterações
                    // No modo hiperbólico, as iterações 4 e 13 são repetidas
                    if (mode_coord == HYPERBOLIC) begin
                        if (iter_counter==4 && hyperbolic_4)
                            hyperbolic_4 <= 1'b0; // Desativa a repetição após a primeira iteração
                        else if (iter_counter==13 && hyperbolic_13) 
                            hyperbolic_13 <= 1'b0; // Desativa a repetição após a primeira iteração
                        else
                            iter_counter <= iter_counter + 1; // Incrementa o contador normalmente
                    end else begin                        
                        iter_counter <= iter_counter + 1; // Incrementa o contador normalmente para outros modos
                    end
                end

                FINALIZE: begin
                    case (mode_coord)                        
                        CIRCULAR: begin 
                            if (mode_op == ROTATION) begin
                                case (quadrante)
                                    3'b000: begin // entre -45° e 45°
                                        X_out_aux <= reg_X;
                                        Y_out_aux <= reg_Y;
                                    end
                                    3'b001: begin // maior que 45° e menor ou igual a 135°
                                        X_out_aux <= -reg_Y;
                                        Y_out_aux <= reg_X;
                                    end
                                    3'b010: begin // maior que 135° e menor ou igual a 180° 
                                        X_out_aux <= -reg_X;
                                        Y_out_aux <= -reg_Y;
                                    end
                                    3'b011: begin // maior que 180° e menor ou igual a 225°
                                        X_out_aux <= -reg_X;
                                        Y_out_aux <= -reg_Y;
                                    end
                                    3'b100: begin  // maior que 225° e menor ou igual a 315° 
                                        X_out_aux <= reg_Y;
                                        Y_out_aux <= -reg_X;
                                    end
                                    default: begin
                                        X_out_aux <= reg_X;
                                        Y_out_aux <= reg_Y;
                                    end
                                endcase
                                Z_out_aux <= reg_Z;
                            end else begin
                                X_out_aux <= mult_x; //MODO VECTORING
                                Y_out_aux <= reg_Y;
                                Z_out_aux <= reg_Z;
                            end                          
                        end

                        HYPERBOLIC: begin
                            if (mode_op == ROTATION) begin
                                X_out_aux <= reg_X;
                                Y_out_aux <= reg_Y;
                                Z_out_aux <= reg_Z;
                            end else begin
                                X_out_aux <= mult_x; //MODO VECTORING
                                Y_out_aux <= reg_Y;
                                Z_out_aux <= reg_Z;
                            end 
                        end        
                        
                        LINEAR: begin
                            if (mode_op == ROTATION) begin
                                X_out_aux <= reg_X;
                                Y_out_aux <= reg_Y <<< cont_div;
                                Z_out_aux <= reg_Z; 
                            end else begin
                                X_out_aux <= reg_X;
                                Y_out_aux <= reg_Y;
                                Z_out_aux <= reg_Z;
                            end
                        end 

                        default: begin
                            X_out_aux <= reg_X;
                            Y_out_aux <= reg_Y;
                            Z_out_aux <= reg_Z;
                        end
                    endcase
                        
                    completed <= 1'b1;
                end

                default: begin
                    iter_counter  <= {$clog2(ITERATIONS){1'b0}};
                    reg_X         <= {INTERNAL_WIDTH{1'b0}};
                    reg_Y         <= {INTERNAL_WIDTH{1'b0}};
                    reg_Z         <= {INTERNAL_WIDTH{1'b0}};
                    X_out_aux     <= {INTERNAL_WIDTH{1'b0}};
                    Y_out_aux     <= {INTERNAL_WIDTH{1'b0}};
                    Z_out_aux     <= {INTERNAL_WIDTH{1'b0}};
                    completed     <= 1'b0;
                    hyperbolic_4  <= 1'b1;
                    hyperbolic_13 <= 1'b1;                    
                end
            endcase
        end
    end

    // Conversão das saídas internas de Q16.32 para Q16.16
    assign x_out = X_out_aux[INTERNAL_WIDTH-1 : FRACTIONAL_BITS-16]; // Pega os 32 bits mais significativos
    assign y_out = Y_out_aux[INTERNAL_WIDTH-1 : FRACTIONAL_BITS-16];
    assign z_out = Z_out_aux[INTERNAL_WIDTH-1 : FRACTIONAL_BITS-16];
    assign valid = completed;

    // Funções LUTs atualizadas para retornar valores em Q16.32
    function signed [INTERNAL_WIDTH-1:0] circular_lut;
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
            default: circular_lut = {INTERNAL_WIDTH{1'b0}};
        endcase
    endfunction

    function signed [INTERNAL_WIDTH-1:0] linear_lut;
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

            default: linear_lut = {INTERNAL_WIDTH{1'b0}};
        endcase
    endfunction

    function signed [INTERNAL_WIDTH-1:0] hyperbolic_lut;
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
            default: hyperbolic_lut = {INTERNAL_WIDTH{1'b0}};
        endcase
    endfunction
    
endmodule