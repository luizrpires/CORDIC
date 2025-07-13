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
    reg signed [WIDTH-1:0] alpha;
    reg sigma; // Sinal de direção: 0 para sinal neg, 1 para sinal pos
    reg hyperbolic_4, hyperbolic_13; // Sinais de controle para iterações específicas no modo hiperbólico
    reg completed; //Sinal para indicar que o cálculo está concluído
    reg sign_sin, sign_cos; //flag para correçao de quadrante, 1 para pos, 0 para neg
    //reg signed [2*WIDTH-1:0] mult_x, mult_y; // Variáveis para calcular ganho de X

    //Lógica para definir a direção da rotação ou vetorização
    always @(*) begin
        if (mode_op == ROTATION) begin
            if (reg_Z[WIDTH-1] == 1'b0) begin //testa se Z é positivo
                sigma = 1'b1; //1 para +1
            end else begin
                sigma = 1'b0; //0 para -1
            end
        end else begin //modo vetorização
            if (reg_Y[WIDTH-1] == 1'b0) begin //testa se Y é positivo
                sigma = 1'b0; //0 para -1
            end else begin
                sigma = 1'b1; //1 para +1
            end
        end
    end

    // Shift registers
    assign shift_X = reg_X >>> iter_counter;
    assign shift_Y = reg_Y >>> iter_counter;

    // Atualização de alpha
    assign alpha =  (mode_coord == CIRCULAR)    ?   circular_lut(iter_counter) : 
                    (mode_coord == LINEAR)      ?   linear_lut(iter_counter) : 
                    (mode_coord == HYPERBOLIC)  ?   hyperbolic_lut(iter_counter) : 32'sd0;
/*
    //cálculo do ganho K
    always @(*)begin
        if(mode_coord == HYPERBOLIC)begin
            mult_x <= (reg_X * K_INV_HYPERBOLIC) >>> FRACTIONAL_BITS;
            //mult_y <= (reg_Y * K_HYPERBOLIC);
        end else if(mode_coord == CIRCULAR)begin
            mult_x <= (reg_X * K_INV_CIRCULAR) >>> FRACTIONAL_BITS;
            //mult_y <= (reg_Y * K_CIRCULAR);
        end else
            mult_x <= 64'b0;
            //mult_y <= 64'b0;
    end
*/    
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
                next_state <= UPDATE;
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
            state         <= IDLE;
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
            state <= next_state;
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
                    iter_counter <= (mode_coord == HYPERBOLIC) ? 1 : 0; // Inicia o contador de iterações em 1 para hiperbólico, 0 para outros modos
                    reg_X        <= x_in;
                    reg_Y        <= y_in;

                    //CORREÇAO DE QUADRANTE PARA SENO E COSSENO
                    if (mode_coord == CIRCULAR && mode_op == ROTATION) begin
                        if (z_in >= -32'sd5898240 && z_in <= 32'sd5898240 ) begin // 1° ou 4° quadrante
                            reg_Z <= z_in; 
                            sign_cos <= 1'b1; // não há alteração
                            sign_sin <= 1'b1; // não há alteração
                        end else if (z_in > 32'sd5898240 && z_in <= 32'sd11796480) begin // 2° quadrante
                            reg_Z <= 32'sd11796480 - z_in; 
                            sign_sin <= 1'b1; // Seno é positivo no Q2
                            sign_cos <= 1'b0; // Cosseno é negativo no Q2
                        end else begin // 3° quadrante
                            reg_Z <= z_in - 32'sd11796480; 
                            sign_sin <= 1'b0; // Seno é negativo no Q3
                            sign_cos <= 1'b0; // Cosseno é negativo no Q3
                        end
                    end else begin
                        reg_Z <= z_in;
                    end
                end

                UPDATE: begin
                    // Atualiza os registros com os novos valores
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
                    
                    if (mode_coord == CIRCULAR && mode_op == ROTATION) begin
                        Y_out_aux <= (sign_sin) ? reg_Y : -reg_Y;
                        X_out_aux <= (sign_cos) ? reg_X : -reg_X; 
                    end else begin
                        X_out_aux <= reg_X;
                        Y_out_aux <= reg_Y;
                    end

                    Z_out_aux <= reg_Z;                 
                    completed <= 1'b1; // Indica que a saída é válida
/*
                    case (mode_coord)                        
                        CIRCULAR: begin 
                            if (mode_op == ROTATION) begin
                                X_out_aux <= reg_X;
                                Y_out_aux <= reg_Y;
                                Z_out_aux <= reg_Z;
                            end else begin
                                X_out_aux <= mult_x;
                                Y_out_aux <= reg_Y;
                                Z_out_aux <= reg_Z;
                            end                          
                        end
                        HYPERBOLIC: begin
                            if (mode_op == ROTATION) begin
                                X_out_aux <= mult_x;
                                Y_out_aux <= reg_Y;
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
*/
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