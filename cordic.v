module cordic #(
    parameter ITERATIONS = 16, //quantidade de iterações
    parameter WIDTH = 32 //tamanho dos dados de entrada e saída
)(
    input clk,
    input rst,
    input enable,
    input mode_op,
    input [1:0] mode_coord, 
    input signed [WIDTH-1:0] x_in,
    input signed [WIDTH-1:0] y_in,
    input signed [WIDTH-1:0] z_in,
    output signed [WIDTH-1:0] x_out,
    output signed [WIDTH-1:0] y_out,
    output signed [WIDTH-1:0] z_out,
    output valid
);

    localparam FRACTIONAL_BITS  = 16; //16 bits fracionários para Q16.16
    localparam K_INV_CIRCULAR   = 32'sd39797;    // 1 / 1.64676 = 0.6072529350088813 * 2^16
    localparam K_CIRCULAR       = 32'sd107936; // 1.646760258121066 * 2^16
    localparam K_INV_HYPERBOLIC = 32'sd79134;    // 1 / 0.82816 = 1.2074970677630726 * 2^16
    localparam K_HYPERBOLIC     = 32'sd54275;  // 0.8281593606 * 2^16

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
    reg signed [WIDTH-1:0] reg_X, reg_Y, reg_Z, next_X, next_Y, next_Z, X_out_aux, Y_out_aux, Z_out_aux;
    wire signed [WIDTH-1:0] shift_X, shift_Y;
    wire signed [WIDTH-1:0] alpha;
    reg sigma; // Sinal de direção: 0 para sinal neg, 1 para sinal pos
    reg hyperbolic_4, hyperbolic_13; // Sinais de controle para iterações específicas no modo hiperbólico
    reg completed; //Sinal para indicar que o cálculo está concluído
    reg signed [2*WIDTH-1:0] mult_x; // Variável para calcular ganho de X

    //CORREÇAO DE QUADRANTE PARA SENO E COSSENO
    wire signed [WIDTH-1:0] z_tratado;
    wire [2:0] quadrante;
    wire done_corquad;
    correcao_quadrante_pi_4 #(WIDTH) corquad (clk, rst, enable, z_in, z_tratado, quadrante, done_corquad);

    //CORREÇAO DE Z PARA MULTIPLICAÇÃO
    wire signed [WIDTH-1:0] z_reduzido;
    wire [WIDTH-1:0] cont_div;
    wire done_diviz;
    corr_z_multi #(WIDTH) corz (clk, rst, enable, z_in, z_reduzido, cont_div, done_diviz);

    //Lógica para definir a direção da rotação ou vetorização
    always @(*) begin
        if (mode_op == ROTATION) begin
            if (reg_Z[WIDTH-1] == 1'b0) begin //testa se Z é positivo
                sigma <= 1'b1; //1 para +1
            end else begin
                sigma <= 1'b0; //0 para -1
            end
        end else begin //modo vetorização
            if (reg_Y[WIDTH-1] == reg_X[WIDTH-1]) begin // testa se Y e X têm o mesmo sinal
                sigma <= 1'b0; // Para que Y se aproxime de zero, a operação deve "subtrair" ou "adicionar um negativo"
            end else begin // Y e X têm sinais opostos
                sigma <= 1'b1; // Para que Y se aproxime de zero, a operação deve "somar" ou "subtrair um negativo"
            end
        end
    end

    // Shift registers
    assign shift_X = reg_X >>> iter_counter;
    assign shift_Y = reg_Y >>> iter_counter;

    // Atualização de alpha
    assign alpha =  (mode_coord == CIRCULAR)   ? circular_lut(iter_counter) : 
                    (mode_coord == LINEAR)     ? linear_lut(iter_counter) : 
                    (mode_coord == HYPERBOLIC) ? hyperbolic_lut(iter_counter) : 32'sd0;

    //cálculo do ganho K no final da operação
    always @(*) begin
        if (rst) begin
            mult_x <= 64'b0;
        end else begin
            if (state == FINALIZE) begin
                if (mode_op == VECTORING) begin
                    if(mode_coord == HYPERBOLIC)begin
                        mult_x <= (reg_X[WIDTH-1] == 1'b1) ? (-reg_X * K_INV_HYPERBOLIC) >>> FRACTIONAL_BITS : (reg_X * K_INV_HYPERBOLIC) >>> FRACTIONAL_BITS;
                    end else if(mode_coord == CIRCULAR)begin
                        mult_x <= (reg_X[WIDTH-1] == 1'b1) ? (-reg_X * K_INV_CIRCULAR) >>> FRACTIONAL_BITS : (reg_X * K_INV_CIRCULAR) >>> FRACTIONAL_BITS;
                    end else
                        mult_x <= 64'b0;
                end else 
                mult_x <= 64'b0;
            end else 
                mult_x <= 64'b0;
        end
    end
   
    // executa os cálculos do cordic generalizado
    always @(*)begin
        if (rst) begin
            next_X <= 32'b0; 
            next_Y <= 32'b0;
            next_Z <= 32'b0;
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
                        next_state <= (~done_diviz) ? INITIALIZE : UPDATE;
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
            iter_counter  <= 0;
            reg_X         <= 32'b0;
            reg_Y         <= 32'b0;
            reg_Z         <= 32'b0;
            X_out_aux     <= 32'b0;
            Y_out_aux     <= 32'b0;
            Z_out_aux     <= 32'b0;
            completed     <= 1'b0;
            hyperbolic_4  <= 1'b1;
            hyperbolic_13 <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    iter_counter  <= 32'b0;
                    reg_X         <= 32'b0;
                    reg_Y         <= 32'b0;
                    reg_Z         <= 32'b0;
                    X_out_aux     <= 32'b0;
                    Y_out_aux     <= 32'b0;
                    Z_out_aux     <= 32'b0;
                    completed     <= 1'b0;
                    hyperbolic_4  <= 1'b1;
                    hyperbolic_13 <= 1'b1;
                end

                INITIALIZE: begin
                    //CONTADOR DE ITERAÇÕES
                    iter_counter <= (mode_coord == HYPERBOLIC) ? 1 : 0; // Inicia o contador de iterações em 1 para hiperbólico, 0 para outros modos
                    
                    if (mode_op == ROTATION) begin
                        if (mode_coord == CIRCULAR) begin 
                            reg_X <= K_INV_CIRCULAR;//SENO E COSSENO, 1/K É SETADO NO INÍCIO DA OPERAÇÃO
                            reg_Z <= z_tratado; //PARA SENO E COSSENO HÁ O TRATAMENTO DO QUADRANTE
                        end else if (mode_coord == HYPERBOLIC) begin
                            reg_X <= K_INV_HYPERBOLIC;//SENO E COSSENO, 1/K É SETADO NO INÍCIO DA OPERAÇÃO  
                            reg_Z <= z_in;                          
                        end else if (mode_coord == LINEAR) begin
                            reg_X <= x_in;
                            reg_Z <= z_reduzido; //substituido z_in por z reduzido
                        end else begin
                            reg_X <= x_in;
                            reg_Z <= z_in;
                        end
                    end else begin
                        reg_X <= x_in;
                        reg_Z <= z_in; 
                    end

                    reg_Y <= y_in;                      
                end

                UPDATE: begin
                    // Atualiza os registradores com os novos valores
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
                            iter_counter <= iter_counter + 1; // Incrementar o contador normalmente
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
                        
                    completed <= 1'b1; // Indica que completou a operação

                end

                default: begin
                    iter_counter <= 0;
                    reg_X        <= 32'b0;
                    reg_Y        <= 32'b0;
                    reg_Z        <= 32'b0;
                    X_out_aux    <= 32'b0;
                    Y_out_aux    <= 32'b0;
                    Z_out_aux    <= 32'b0;
                    completed    <= 1'b0;
                end
            endcase
        end
    end

    assign x_out = X_out_aux;
    assign y_out = Y_out_aux;
    assign z_out = Z_out_aux;
    assign valid = completed;


    function signed [WIDTH-1:0] circular_lut;
        input integer index;
        case (index)
            0:  circular_lut = 32'sd51472;   // atan(2^0) = 0.785398...
            1:  circular_lut = 32'sd30386;   // atan(2^-1) = 0.463647...
            2:  circular_lut = 32'sd16053;   // atan(2^-2) = 0.244978...
            3:  circular_lut = 32'sd8140;    // atan(2^-3) = 0.124354...
            4:  circular_lut = 32'sd4090;    // atan(2^-4) = 0.062418...
            5:  circular_lut = 32'sd2047;    // atan(2^-5) = 0.031239...
            6:  circular_lut = 32'sd1023;    // atan(2^-6) = 0.015620...
            7:  circular_lut = 32'sd511;     // atan(2^-7) = 0.007810...
            8:  circular_lut = 32'sd255;     // atan(2^-8) = 0.003906...
            9:  circular_lut = 32'sd127;     // atan(2^-9) = 0.001953...
            10: circular_lut = 32'sd63;      // atan(2^-10) = 0.000976...
            11: circular_lut = 32'sd31;      // atan(2^-11) = 0.000488...
            12: circular_lut = 32'sd15;      // atan(2^-12) = 0.000244...
            13: circular_lut = 32'sd7;       // atan(2^-13) = 0.000122...
            14: circular_lut = 32'sd3;       // atan(2^-14) = 0.000061...
            15: circular_lut = 32'sd1;       // atan(2^-15) = 0.000030...
            default: circular_lut = 32'sd0; // Para j >= FRACTIONAL_BITS (16), 2^-j é 0 em Q16.16, então atan(2^-j) também é 0.
        endcase
    endfunction

    function signed [WIDTH-1:0] linear_lut;
        input integer index;
        case (index)
            0 : linear_lut = 32'sd65536; // 2^0 = 1.0 em Q16.16
            1 : linear_lut = 32'sd32768; // 2^-1 = 0.5 em Q16.16
            2 : linear_lut = 32'sd16384; // 2^-2 = 0.25 em Q16.16
            3 : linear_lut = 32'sd8192;  // 2^-3 = 0.125 em Q16.16
            4 : linear_lut = 32'sd4096;  // 2^-4 = 0.0625 em Q16.16
            5 : linear_lut = 32'sd2048;  // 2^-5 = 0.03125 em Q16.16
            6 : linear_lut = 32'sd1024;  // 2^-6 = 0.015625 em Q16.16
            7 : linear_lut = 32'sd512;   // 2^-7 = 0.007812 em Q16.16
            8 : linear_lut = 32'sd256;   // 2^-8 = 0.003906 em Q16.16
            9 : linear_lut = 32'sd128;   // 2^-9 = 0.001953 em Q16.16
            10: linear_lut = 32'sd64;    // 2^-10 = 0.000976 em Q16.16
            11: linear_lut = 32'sd32;    // 2^-11 = 0.000488 em Q16.16
            12: linear_lut = 32'sd16;    // 2^-12 = 0.000244 em Q16.16
            13: linear_lut = 32'sd8;     // 2^-13 = 0.000122 em Q16.16
            14: linear_lut = 32'sd4;     // 2^-14 = 0.000061 em Q16.16
            15: linear_lut = 32'sd2;     // 2^-15 = 0.000030 em Q16.16
            default: linear_lut = 32'sd0;    // Para j >= FRACTIONAL_BITS (16), 2^-j é 0 em Q16.16, então atan(2^-j) também é 0.
        endcase
    endfunction

    function signed [WIDTH-1:0] hyperbolic_lut;
        input integer index;
        case (index)
            1 : hyperbolic_lut = 32'sd35999;   // tanh_inv(2^-1) = 0.549306...
            2 : hyperbolic_lut = 32'sd16743;   // tanh_inv(2^-2) = 0.255412...
            3 : hyperbolic_lut = 32'sd8234;    // tanh_inv(2^-3) = 0.125657...
            4 : hyperbolic_lut = 32'sd4104;    // tanh_inv(2^-4) = 0.062425... (Ponto de repetição)
            5 : hyperbolic_lut = 32'sd2050;    // tanh_inv(2^-5) = 0.031260...
            6 : hyperbolic_lut = 32'sd1024;    // tanh_inv(2^-6) = 0.015628...
            7 : hyperbolic_lut = 32'sd512;     // tanh_inv(2^-7) = 0.007812...
            8 : hyperbolic_lut = 32'sd256;     // tanh_inv(2^-8) = 0.003906...
            9 : hyperbolic_lut = 32'sd128;     // tanh_inv(2^-9) = 0.001953...
            10: hyperbolic_lut = 32'sd64;      // tanh_inv(2^-10) = 0.000976...
            11: hyperbolic_lut = 32'sd32;      // tanh_inv(2^-11) = 0.000488...
            12: hyperbolic_lut = 32'sd16;      // tanh_inv(2^-12) = 0.000244...
            13: hyperbolic_lut = 32'sd8;       // tanh_inv(2^-13) = 0.000122... // Ponto de repetição
            14: hyperbolic_lut = 32'sd4;       // tanh_inv(2^-14) = 0.000061...
            15: hyperbolic_lut = 32'sd2;       // tanh_inv(2^-15) = 0.000030...
            default: hyperbolic_lut = 32'sd0; // Para j == 0 ou >= FRACTIONAL_BITS (16) e 2^-j é 0 em Q16.16, então tanh_inv(2^-j) também é 0.
        endcase
    endfunction
    
endmodule


module corr_z_multi #(
    parameter WIDTH = 32 //tamanho dos dados de entrada e saída
)(
    input clk,
    input rst,
    input enable,
    input signed [WIDTH-1:0] z_in,
    output signed [WIDTH-1:0] z_out,
    output [WIDTH-1:0] count_div,
    output done
);

    localparam IDLE      = 2'b00;
    localparam VERIF     = 2'b01;
    localparam NORMALIZE = 2'b10;
    
    localparam ONE_POS = 32'sd65536;
    localparam ONE_NEG = -32'sd65536;
    localparam TWO_POS = 32'sd131072;
    localparam TWO_NEG = -32'sd131072;

    reg [1:0] state, next_state;
    reg signed [WIDTH-1:0] z_aux, z_normalized; 
    reg [WIDTH-1:0] count_aux, count_n_aux;
    reg completed;

    always @(*) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            next_state   <= IDLE;
            z_normalized <= 0;
            z_aux        <= 0;
            count_aux    <= 0;
            count_n_aux  <= 0;
            completed    <= 1'b0;
        end else begin
            next_state <= state;
            case (state)
                IDLE : begin
                    completed    <= 1'b0; 
                    if (enable) begin
                        z_normalized <= z_in;
                        count_aux    <= 0;                       
                        count_n_aux  <= 0;
                        next_state   <= VERIF;
                    end else begin
                        next_state   <= IDLE;  
                    end
                end
                VERIF : begin
                    count_n_aux <= count_aux;
                    if (z_normalized < TWO_POS && z_normalized > TWO_NEG) begin
                        completed  <= 1'b1;
                        next_state <= IDLE;
                    end else begin
                        z_aux      <= z_normalized;
                        completed  <= 1'b0;
                        next_state <= NORMALIZE;
                    end
                end
                NORMALIZE : begin
                    z_normalized <= z_aux >>> 1; // divide por 2
                    count_aux    <= count_n_aux + 1'b1; //soma 1 ao contador de divisões
                    completed    <= 1'b0;
                    next_state   <= VERIF;
                end
                default : begin
                    z_normalized <= 0;
                    z_aux        <= 0;
                    count_aux    <= 0;
                    count_n_aux  <= 0;
                    completed    <= 1'b0;
                end
            endcase
        end
    end

    assign z_out     = z_normalized;
    assign done      = completed;
    assign count_div = count_n_aux;
endmodule

module correcao_quadrante_pi_4 #(
    parameter WIDTH = 32 //tamanho dos dados de entrada e saída
) (
    input clk,
    input rst,
    input enable,
    input signed [WIDTH-1:0] z_in,
    output signed [WIDTH-1:0] z_out,
    output signed [2:0] quadrante,
    output done
);

    localparam START = 3'b000;
    localparam VERIF = 3'b001;
    localparam MAIOR = 3'b010;
    localparam MENOR = 3'b011;
    localparam VERIF_2 = 3'b100;
    localparam CORQUAD = 3'b101;

    localparam signed [31:0] _360_2PI     = 32'sd411775;   // 2π ≈ 6.28302
    localparam signed [31:0] _225_NEG     = -32'sd257359;  // ≈ -3.92883
    localparam signed [31:0] _225_POS     = 32'sd257359;   // ≈ 3.92883 225°
    localparam signed [31:0] _45_PI_4_POS = 32'sd51472;    // π/4 ≈ 0.78540
    localparam signed [31:0] _45_PI_4_NEG = -32'sd51472;   // -π/4 ≈ -0.78540
    localparam signed [31:0] _135_3PI_4   = 32'sd154416;   // 3π/4 ≈ 2.35620
    localparam signed [31:0] _90_PI_2     = 32'sd102944;   // π/2 ≈ 1.57106
    localparam signed [31:0] _180_PI      = 32'sd205887;   // π    ≈ 3.14154
    localparam signed [31:0] _315_5_5     = 32'sd360303;   // ≈ 5.50024
    localparam signed [31:0] _ZERO        = 32'd0;        // 0
    

    reg [2:0] state, next_state;
    reg signed [WIDTH-1:0] z_aux, z_tratado, z_normalizado;
    reg signed [2:0] quad_in;
    reg completed;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= START;
        end else 
            state <= next_state;
    end

    always @(*) begin
        if (rst) begin
            z_tratado <= 0;
            next_state <= START;
            z_normalizado <= 0;
            quad_in <= 3'b000;
            z_aux <= 0;
            completed <= 1'b0;
        end else begin
            next_state <= state;
            case (state)
                START : begin
                    completed <= 1'b0;
                    if (enable) begin
                        z_tratado <= z_in;
                        next_state <= VERIF;
                    end else begin
                        next_state <= START;
                    end
                end
                VERIF : begin
                    if (z_tratado > _360_2PI) begin
                        next_state <= MAIOR;
                    end else if ( z_tratado < _ZERO && z_tratado < _45_PI_4_NEG) begin
                        next_state <= MENOR;
                    end else if (z_tratado > _315_5_5 && z_tratado <= _360_2PI) begin
                        z_normalizado <= z_tratado - _360_2PI;
                        next_state <= CORQUAD;
                    end else begin
                        z_normalizado <= z_tratado;
                        next_state <= CORQUAD;
                    end
                end
                MAIOR : begin
                    z_normalizado <= z_tratado - _360_2PI;
                    next_state <= VERIF_2;
                end
                MENOR : begin
                    z_normalizado <= z_tratado + _360_2PI;
                    next_state <= VERIF_2;
                end 
                VERIF_2 : begin
                    if (z_normalizado > _360_2PI) begin
                        z_tratado <= z_normalizado;
                        next_state <= VERIF;
                    end else if (z_normalizado < _ZERO && z_normalizado < _45_PI_4_NEG) begin
                        z_tratado <= z_normalizado;
                        next_state <= VERIF;
                    end else begin
                        next_state <= CORQUAD;
                    end
                end         
                CORQUAD : begin
                    if (z_normalizado > _45_PI_4_POS && z_normalizado <= _135_3PI_4) begin // maior que 45° e menor ou igual a 135° 
                        z_aux <= z_normalizado - _90_PI_2; // θ° - 90°
                        quad_in <= 3'b001;
                        next_state <= START;
                    end else if (z_normalizado > _135_3PI_4 && z_normalizado <= _180_PI) begin // maior que 135° e menor ou igual a 180° 
                        z_aux <= z_normalizado - _180_PI; // θ° - 180°
                        quad_in <= 3'b010;
                        next_state <= START;
                    end else if (z_normalizado > _180_PI && z_normalizado <= _225_POS) begin // maior que 180° e menor ou igual a 225° 
                        z_aux <= z_normalizado + _180_PI - _360_2PI; // θ° + 180° - 360°
                        quad_in <= 3'b011;
                        next_state <= START;
                    end else if (z_normalizado > _225_POS && z_normalizado <= _315_5_5) begin // maior que 225° e menor ou igual a 315° 
                        z_aux <= z_normalizado + _90_PI_2 - _360_2PI; // θ° + 90° - 360°
                        quad_in <= 3'b100;
                        next_state <= START;
                    end else begin // entre -45° e 45°
                        z_aux <= z_normalizado; // não há alteração
                        quad_in <= 3'b000;
                        next_state <= START;
                    end
                    completed <= 1'b1;
                end
                default : next_state <= START;
            endcase
        end
    end

    assign quadrante = quad_in;
    assign z_out = z_aux;
    assign done = completed;

endmodule