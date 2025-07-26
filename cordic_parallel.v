module cordic_parallel #(
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

    //VARIAVEIS PARA CORREÇÃO DO MODULO
    localparam signed [WIDTH-1:0] K_INV_CIRCULAR   = 32'sd39797;    // 1 / 1.64676 = 0.6072529350088813 * 2^16
    localparam signed [WIDTH-1:0] K_CIRCULAR       = 32'sd107936; // 1.646760258121066 * 2^16
    localparam signed [WIDTH-1:0] K_INV_HYPERBOLIC = 32'sd79134;    // 1 / 0.82816 = 1.2074970677630726 * 2^16
    localparam signed [WIDTH-1:0] K_HYPERBOLIC     = 32'sd54275;  // 0.8281593606 * 2^16

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
    reg signed [2*WIDTH-1:0] mult;
    reg completed;
    reg enable_start;
    wire done_iter[0:N-1];
    wire signed [WIDTH-1:0] x[0:N], y[0:N], z[0:N];
    wire enable_iter[0:N];

    //CORREÇAO DE QUADRANTE PARA SENO E COSSENO
    wire signed [WIDTH-1:0] z_tratado;
    wire [2:0] quadrante;
    wire done_corquad;
    wire enable_corquad;
    assign enable_corquad = (enable && mode_op==ROTATION && mode_coord==CIRCULAR) ? 1'b1 : 1'b0;
    correcao_quadrante_pi_4 #(WIDTH) corquad (clk, rst, enable_corquad, z_in, z_tratado, quadrante, done_corquad);

    //CORREÇAO DE Z PARA MULTIPLICAÇÃO
    wire signed [WIDTH-1:0] z_reduzido;
    wire [3:0] cont_div;
    wire done_corz;
    wire enable_corz;
    assign enable_corz = (enable && mode_op==ROTATION && mode_coord==LINEAR) ? 1'b1 : 1'b0;
    corr_z_multi #(WIDTH) corz (clk, rst, enable_corz, z_in, z_reduzido, cont_div, done_corz);

    always @(*) begin
        if (done_iter[N-1]) begin
            if (mode_op == VECTORING) begin
                if(mode_coord == HYPERBOLIC)begin
                    mult <= (x[N][WIDTH-1] == 1) ? (-x[N] * K_INV_HYPERBOLIC) >>> FRACTIONAL_BITS : 
                                                  (x[N] * K_INV_HYPERBOLIC) >>> FRACTIONAL_BITS ;
                end else if(mode_coord == CIRCULAR)begin
                    mult <= (x[N][WIDTH-1] == 1) ? (-x[N] * K_INV_CIRCULAR) >>> FRACTIONAL_BITS : 
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
                    enable_start <= done_corz;
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
            cordic_calc_parallel #(
                .I(i),          //iteração atual
                .ITERATIONS(N), //quantidade de iterações
                .WIDTH(WIDTH)   //tamanho dos dados de entrada e saída
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
    assign x_out = x_out_aux;
    assign y_out = y_out_aux;
    assign z_out = z_out_aux;
    assign valid = completed;

endmodule

module cordic_calc_parallel #( 
    parameter I = 0, //iteração atual
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
                    (mode_coord == HYPERBOLIC) ? hyperbolic_lut(iteration) : 32'sd0;

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
