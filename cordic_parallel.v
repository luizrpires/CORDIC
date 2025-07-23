module cordic_parallel #(
    parameter ITERATIONS = 16, //quantidade de iterações
    parameter WIDTH = 32 //tamanho dos dados de entrada e saída
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
    output valid
);

    //VARIAVEIS PARA CORREÇÃO DO MODULO
    localparam K_INV_CIRCULAR   = 32'sd39797;    // 1 / 1.64676 = 0.6072529350088813 * 2^16
    localparam K_CIRCULAR       = 32'sd107936; // 1.646760258121066 * 2^16
    localparam K_INV_HYPERBOLIC = 32'sd79134;    // 1 / 0.82816 = 1.2074970677630726 * 2^16
    localparam K_HYPERBOLIC     = 32'sd54275;  // 0.8281593606 * 2^16

    localparam FRACTIONAL_BITS  = 16; //16 bits fracionários para Q16.16

    //MODO COORDENADA
    localparam CIRCULAR = 2'b01, //1 para Circular
               LINEAR = 2'b00, //0 para Linear
               HYPERBOLIC = 2'b11; //-1 para Hiperbólico
    //MODO OPERAÇÃO 
    localparam ROTATION = 1'b0, //0 para Rotação
               VECTORING = 1'b1; //1 para Vetorização

    localparam N = ITERATIONS;
    
    reg signed [WIDTH-1:0] x_in_aux, y_in_aux, z_in_aux;
    reg signed [WIDTH-1:0] x_out_aux, y_out_aux, z_out_aux;
    reg [2*WIDTH-1:0] mult;
    reg reg_valid;
    reg enable_start;
    wire done_iter[0:N-1];
    wire signed [WIDTH-1:0] x[0:N], y[0:N], z[0:N];
    wire enable_iter[0:N];

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

    always @(*) begin
        if (done_iter[N-1]) begin
            if (mode_op == VECTORING) begin
                if(mode_coord == HYPERBOLIC)begin
                    mult = (x[N][WIDTH-1] == 1) ? (-x[N] * K_INV_HYPERBOLIC) >>> FRACTIONAL_BITS : 
                                                  (x[N] * K_INV_HYPERBOLIC) >>> FRACTIONAL_BITS ;
                end else if(mode_coord == CIRCULAR)begin
                    mult = (x[N][WIDTH-1] == 1) ? (-x[N] * K_INV_CIRCULAR) >>> FRACTIONAL_BITS : 
                                                  (x[N] * K_INV_CIRCULAR) >>> FRACTIONAL_BITS ;
                end else
                    mult = 0;
            end else begin
                mult = 0;
            end            
        end else begin
            mult = 0;
        end
    end

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
                    z_in_aux <= z_in;
                    enable_start <= enable;  
                end else if (mode_coord == LINEAR) begin
                    x_in_aux <= x_in;
                    z_in_aux <= z_reduzido;
                    enable_start <= done_diviz;
                end else begin
                    x_in_aux <= x_in;
                    z_in_aux <= z_in;        
                    enable_start <= enable;
                end
            end else begin
                x_in_aux <= x_in;
                z_in_aux <= z_in;        
                enable_start <= enable;
            end
            y_in_aux <= y_in;
        end

    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_out_aux <= 0;
            y_out_aux <= 0;
            z_out_aux <= 0;
            reg_valid <= 0;
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
            reg_valid <= 1;
        end else begin
            x_out_aux <= 0;
            y_out_aux <= 0;
            z_out_aux <= 0;
            reg_valid <= 0;
        end
    end

    assign enable_iter[0] = enable_start;
    assign x[0] = x_in_aux;
    assign y[0] = y_in_aux;
    assign z[0] = z_in_aux;

    genvar i;
    generate
        for (i = 0; i < ITERATIONS; i = i + 1) begin
            cordic_calc #(
                .I(i),          //iteração atual
                .ITERATIONS(N), //quantidade de iterações
                .WIDTH(WIDTH)   //tamanho dos dados de entrada e saída
            ) cordic_calc_inst (
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
    assign x_out = x_out_aux;
    assign y_out = y_out_aux;
    assign z_out = z_out_aux;
    assign valid = reg_valid;

endmodule

module cordic_calc #( 
    parameter I = 0, //iteração atual
    parameter ITERATIONS = 16, //quantidade de iterações
    parameter WIDTH = 32 //tamanho dos dados de entrada e saída
)(
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
    wire [WIDTH-1:0] alpha;
    wire signed [WIDTH-1:0] x_shift,y_shift;
    reg sigma;
    reg signed [WIDTH-1:0] next_X, next_Y, next_Z;
    reg done_calc;

    assign iteration = iter_index(I, mode_coord);

    assign alpha =  (mode_coord == CIRCULAR)   ? circular_lut(iteration) : 
                    (mode_coord == LINEAR)     ? linear_lut(iteration) : 
                    (mode_coord == HYPERBOLIC) ? hyperbolic_lut(iteration) : 32'sd0;

    always @(*) begin
        if (mode_op == ROTATION) begin
            if (z_in[WIDTH-1] == 1'b0) begin //testa se Z é positivo
                sigma = 1'b1; //1 para +1
            end else begin
                sigma = 1'b0; //0 para -1
            end
        end else begin //modo vetorização
            if (y_in[WIDTH-1] == x_in[WIDTH-1]) begin // testa se Y e X têm o mesmo sinal
                sigma = 1'b0; //0 para -1
            end else begin
                sigma = 1'b1; //1 para +1
            end
        end
    end
    
    assign x_shift = x_in >>> iteration;
    assign y_shift = y_in >>> iteration;

    always @(*)begin
        if (rst) begin
            next_X    = 0;
            next_Y    = 0;
            next_Z    = 0;
            done_calc = 0;
        end else if (enable) begin
            case (mode_coord)
                //xi+1 = xi − μ σi yi 2^−i
                //yi+1 = yi + σi xi 2^−i
                //zi+1 = zi − σi αi
                CIRCULAR: begin // m = 1
                    next_X = x_in - (sigma ? y_shift : -y_shift);
                    next_Y = y_in + (sigma ? x_shift : -x_shift);
                    next_Z = z_in - (sigma ? alpha : -alpha);
                end

                LINEAR: begin // m = 0
                    next_X = x_in;
                    next_Y = y_in + (sigma ? x_shift : -x_shift);
                    next_Z = z_in - (sigma ? alpha : -alpha);
                end

                HYPERBOLIC: begin // m = -1
                    next_X = x_in + (sigma ? y_shift : -y_shift);
                    next_Y = y_in + (sigma ? x_shift : -x_shift);
                    next_Z = z_in - (sigma ? alpha : -alpha);
                end
                
                default: begin
                    next_X = x_in;
                    next_Y = y_in;
                    next_Z = z_in;
                end
            endcase
            done_calc = 1;
        end else begin
            next_X    = 0;
            next_Y    = 0;
            next_Z    = 0;
            done_calc = 0;
        end
    end

    assign x_out = next_X;
    assign y_out = next_Y;
    assign z_out = next_Z;
    assign done  = done_calc;



    //FUNÇÕES AUXILIARES
    function [$clog2(ITERATIONS)-1:0] iter_index;
        input integer iter;
        input [1:0] mode_coordinate;
        
        if (mode_coordinate == HYPERBOLIC) begin
            if (iter >= 0 && iter <= 3) begin
                iter_index = iter + 1;
            end else if (iter >= 14 && iter < ITERATIONS) begin
                iter_index = iter - 1;                
            end else begin
                iter_index = iter;
            end
        end else begin
            iter_index = iter;
        end
    endfunction

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

    localparam signed [WIDTH-1:0] _360_2PI     = 32'sd411775;   // 2π ≈ 6.28302
    localparam signed [WIDTH-1:0] _225_NEG     = -32'sd257359;  // ≈ -3.92883
    localparam signed [WIDTH-1:0] _225_POS     = 32'sd257359;   // ≈ 3.92883 225°
    localparam signed [WIDTH-1:0] _45_PI_4_POS = 32'sd51472;    // π/4 ≈ 0.78540
    localparam signed [WIDTH-1:0] _45_PI_4_NEG = -32'sd51472;   // -π/4 ≈ -0.78540
    localparam signed [WIDTH-1:0] _135_3PI_4   = 32'sd154416;   // 3π/4 ≈ 2.35620
    localparam signed [WIDTH-1:0] _90_PI_2     = 32'sd102944;   // π/2 ≈ 1.57106
    localparam signed [WIDTH-1:0] _180_PI      = 32'sd205887;   // π    ≈ 3.14154
    localparam signed [WIDTH-1:0] _315_5_5     = 32'sd360303;   // ≈ 5.50024
    localparam signed [WIDTH-1:0] _ZERO        = 32'd0;         // 0
    

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
