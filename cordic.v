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
    output reg signed [WIDTH-1:0] x_out,
    output reg signed [WIDTH-1:0] y_out,
    output reg signed [WIDTH-1:0] z_out,
    output reg valid
);

    localparam FRACTIONAL_BITS = 16; //16 bits fracionários para Q16.16

    //MODO COORDENADA
    localparam  CIRCULAR = 2'b01, //1 para Circular
                LINEAR = 2'b00, //0 para Linear
                HYPERBOLIC = 2'b11; //-1 para Hiperbólico

    //MODO OPERAÇÃO 
    localparam  ROTATION = 1'b0, //0 para Rotação
                VECTORING = 1'b1; //1 para Vetorização

    //ESTADOS
    localparam  IDLE = 3'b000,
                INITIALIZE = 3'b001,
                CALCULATE = 3'b010,
                UPDATE = 3'b011,
                ITERATE = 3'b100,
                //FINALIZE = 3'b101,
                DONE = 3'b110;

    reg [2:0] state, next_state;
    reg [$clog2(ITERATIONS)-1:0] iter_counter; 
    reg signed [WIDTH-1:0] reg_X, reg_Y, reg_Z, next_X, next_Y, next_Z;
    wire signed [WIDTH-1:0] shift_X, shift_Y;
    reg signed [WIDTH-1:0] alpha;
    reg sigma; // Sinal de direção: 0 para sinal neg, 1 para sinal pos
    reg hyperbolic_4, hyperbolic_13; // Sinais de controle para iterações específicas no modo hiperbólico
    //reg signed [2*WIDTH-1:0] mult_x, mult_y; // Variáveis para multiplicação


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

    //Lógica para definir o valor de alpha baseado no modo de coordenada
    always @(*) begin
        case (mode_coord)
            CIRCULAR: begin // mode_coord = 1: alpha = atan(2^-j)
                case (iter_counter)
                    0:  alpha <= 32'd51472;   // atan(2^0) = 0.785398...
                    1:  alpha <= 32'd30386;   // atan(2^-1) = 0.463647...
                    2:  alpha <= 32'd16053;   // atan(2^-2) = 0.244978...
                    3:  alpha <= 32'd8140;    // atan(2^-3) = 0.124354...
                    4:  alpha <= 32'd4090;    // atan(2^-4) = 0.062418...
                    5:  alpha <= 32'd2047;    // atan(2^-5) = 0.031239...
                    6:  alpha <= 32'd1023;    // atan(2^-6) = 0.015620...
                    7:  alpha <= 32'd511;     // atan(2^-7) = 0.007810...
                    8:  alpha <= 32'd255;     // atan(2^-8) = 0.003906...
                    9:  alpha <= 32'd127;     // atan(2^-9) = 0.001953...
                    10: alpha <= 32'd63;      // atan(2^-10) = 0.000976...
                    11: alpha <= 32'd31;      // atan(2^-11) = 0.000488...
                    12: alpha <= 32'd15;      // atan(2^-12) = 0.000244...
                    13: alpha <= 32'd7;       // atan(2^-13) = 0.000122...
                    14: alpha <= 32'd3;       // atan(2^-14) = 0.000061...
                    15: alpha <= 32'd1;       // atan(2^-15) = 0.000030...
                    default: alpha <= 0; // Para j >= FRACTIONAL_BITS (16), 2^-j é 0 em Q16.16, então atan(2^-j) também é 0.
                endcase
            end
            LINEAR: begin // mode_coord = 0: alpha = 2^-j
                case (iter_counter)
                    0 : alpha <= 32'd65536; // 2^0 = 1.0 em Q16.16
                    1 : alpha <= 32'd32768; // 2^-1 = 0.5 em Q16.16
                    2 : alpha <= 32'd16384; // 2^-2 = 0.25 em Q16.16
                    3 : alpha <= 32'd8192;  // 2^-3 = 0.125 em Q16.16
                    4 : alpha <= 32'd4096;  // 2^-4 = 0.0625 em Q16.16
                    5 : alpha <= 32'd2048;  // 2^-5 = 0.03125 em Q16.16
                    6 : alpha <= 32'd1024;  // 2^-6 = 0.015625 em Q16.16
                    7 : alpha <= 32'd512;   // 2^-7 = 0.007812 em Q16.16
                    8 : alpha <= 32'd256;   // 2^-8 = 0.003906 em Q16.16
                    9 : alpha <= 32'd128;   // 2^-9 = 0.001953 em Q16.16
                    10: alpha <= 32'd64;    // 2^-10 = 0.000976 em Q16.16
                    11: alpha <= 32'd32;    // 2^-11 = 0.000488 em Q16.16
                    12: alpha <= 32'd16;    // 2^-12 = 0.000244 em Q16.16
                    13: alpha <= 32'd8;     // 2^-13 = 0.000122 em Q16.16
                    14: alpha <= 32'd4;     // 2^-14 = 0.000061 em Q16.16
                    15: alpha <= 32'd2;     // 2^-15 = 0.000030 em Q16.16
                    default: alpha <= 0;    // Para j >= FRACTIONAL_BITS (16), 2^-j é 0 em Q16.16, então atan(2^-j) também é 0.
                endcase
            end

            HYPERBOLIC: begin // mode_coord = -1: alpha = tanh_inv(2^-j)
                case (iter_counter)
                    1 : alpha <= 32'd35999;   // tanh_inv(2^-1) = 0.549306...
                    2 : alpha <= 32'd16743;   // tanh_inv(2^-2) = 0.255412...
                    3 : alpha <= 32'd8234;    // tanh_inv(2^-3) = 0.125657...
                    4 : alpha <= 32'd4104;    // tanh_inv(2^-4) = 0.062425... (Ponto de repetição)
                    5 : alpha <= 32'd2050;    // tanh_inv(2^-5) = 0.031260...
                    6 : alpha <= 32'd1024;    // tanh_inv(2^-6) = 0.015628...   
                    7 : alpha <= 32'd512;     // tanh_inv(2^-7) = 0.007812...
                    8 : alpha <= 32'd256;     // tanh_inv(2^-8) = 0.003906...
                    9 : alpha <= 32'd128;     // tanh_inv(2^-9) = 0.001953...
                    10: alpha <= 32'd64;      // tanh_inv(2^-10) = 0.000976...
                    11: alpha <= 32'd32;      // tanh_inv(2^-11) = 0.000488...
                    12: alpha <= 32'd16;      // tanh_inv(2^-12) = 0.000244...
                    13: alpha <= 32'd8;       // tanh_inv(2^-13) = 0.000122... // Ponto de repetição
                    14: alpha <= 32'd4;       // tanh_inv(2^-14) = 0.000061...
                    15: alpha <= 32'd2;       // tanh_inv(2^-15) = 0.000030...  
                    default: alpha <= 0; // Para j == 0 ou >= FRACTIONAL_BITS (16) e 2^-j é 0 em Q16.16, então tanh_inv(2^-j) também é 0.
                endcase
            end

            default: begin
                alpha <= 0; // Valor padrão para evitar latch
            end
        endcase
    end

    // Shift registers
    assign shift_X = reg_X >>> iter_counter;
    assign shift_Y = reg_Y >>> iter_counter;


    //Lógica de transição de estados
    always @(*) begin
        case (state)
            IDLE: 
                next_state <= (enable) ? INITIALIZE : IDLE;
            INITIALIZE: 
                next_state <= CALCULATE;
            CALCULATE: 
                next_state <= UPDATE;
            UPDATE: 
                next_state <= ITERATE;
            ITERATE: 
                next_state <= (iter_counter == ITERATIONS-1) ? DONE : CALCULATE;
            DONE: 
                next_state <= IDLE;
            default: 
                next_state <= IDLE;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            iter_counter <= 0;
            reg_X <= 0;
            reg_Y <= 0;
            reg_Z <= 0;
            next_X <= 0;
            next_Y <= 0;
            next_Z <= 0;
            x_out <= 0;
            y_out <= 0;
            z_out <= 0;
            valid <= 0;
            hyperbolic_4 <= 1'b1;
            hyperbolic_13 <= 1'b1;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    iter_counter <= (mode_coord == HYPERBOLIC) ? 1 : 0; // Inicia o contador de iterações em 1 para hiperbólico, 0 para outros modos
                    reg_X <= 0;
                    reg_Y <= 0;
                    reg_Z <= 0;
                    next_X <= 0;
                    next_Y <= 0;
                    next_Z <= 0;
                    x_out <= 0;
                    y_out <= 0;
                    z_out <= 0;
                    valid <= 0;
                    hyperbolic_4 <= 1'b1;
                    hyperbolic_13 <= 1'b1;
                end

                INITIALIZE: begin
                    reg_X <= x_in;
                    reg_Y <= y_in;
                    reg_Z <= z_in;
                end

                CALCULATE: begin
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

                UPDATE: begin
                    // Atualiza os registros com os novos valores
                    reg_X <= next_X;
                    reg_Y <= next_Y;
                    reg_Z <= next_Z;
                end

                ITERATE: begin                    
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

                DONE: begin
                    x_out <= reg_X;
                    y_out <= reg_Y;
                    z_out <= reg_Z;
                    valid <= 1'b1; // Indica que a saída é válida
                end

                default: begin
                    iter_counter <= 0;
                    reg_X <= 0;
                    reg_Y <= 0;
                    reg_Z <= 0;
                    next_X <= 0;
                    next_Y <= 0;
                    next_Z <= 0;
                    x_out <= 0;
                    y_out <= 0;
                    z_out <= 0;
                    valid <= 0;
                end
            endcase
        end
    end
    
endmodule


/*
reg signed [WIDTH-1:0] atan_table_lut [0:ITERATIONS-1];
    initial begin
        // Valores calculados com precisão e arredondados para Q16.16
        // float_val = atan(2.0**(-j))
        // fixed_val = int(round(float_val * (2**FRACTIONAL_BITS)))
        atan_table_lut[0]  = 32'd51472;   // atan(2^0) = 0.785398...
        atan_table_lut[1]  = 32'd30386;   // atan(2^-1) = 0.463647...
        atan_table_lut[2]  = 32'd16053;   // atan(2^-2) = 0.244978...
        atan_table_lut[3]  = 32'd8140;    // atan(2^-3) = 0.124354...
        atan_table_lut[4]  = 32'd4090;    // atan(2^-4) = 0.062418...
        atan_table_lut[5]  = 32'd2047;    // atan(2^-5) = 0.031239...
        atan_table_lut[6]  = 32'd1023;    // atan(2^-6) = 0.015620...
        atan_table_lut[7]  = 32'd511;     // atan(2^-7) = 0.007810...
        atan_table_lut[8]  = 32'd255;     // atan(2^-8) = 0.003906...
        atan_table_lut[9]  = 32'd127;     // atan(2^-9) = 0.001953...
        atan_table_lut[10] = 32'd63;      // atan(2^-10) = 0.000976...
        atan_table_lut[11] = 32'd31;      // atan(2^-11) = 0.000488...
        atan_table_lut[12] = 32'd15;      // atan(2^-12) = 0.000244...
        atan_table_lut[13] = 32'd7;       // atan(2^-13) = 0.000122...
        atan_table_lut[14] = 32'd3;       // atan(2^-14) = 0.000061...
        atan_table_lut[15] = 32'd1;       // atan(2^-15) = 0.000030...
        // Para j >= FRACTIONAL_BITS (16), 2^-j é 0 em Q16.16, então atan(2^-j) também é 0.
        for (integer i = 16; i < ITERATIONS; i = i + 1) begin
            atan_table_lut[i] = 0; 
        end
    end
     // LUT de 2^-j para modo LINEAR
    reg signed [WIDTH-1:0] linear_table_lut [0:ITERATIONS-1];
    initial begin
        for (integer i = 0; i < ITERATIONS; i = i + 1) begin
            if (i < FRACTIONAL_BITS) begin // Enquanto o shift não elimina o 1
                linear_table_lut[i] = (1 << (FRACTIONAL_BITS - i)); // 2^-j
            end else begin
                linear_table_lut[i] = 0; // Se j >= FRACTIONAL_BITS, 2^-j é 0 em Q16.16
            end
        end
    end
    // LUT de tanh_inv(2^-j) para modo HIPERBÓLICO
    reg signed [WIDTH-1:0] tanh_inv_table_lut [0:ITERATIONS-1];
    initial begin
        // tanh_inv(2^-0) = INF, geralmente não usado. Começa de j=1.
        tanh_inv_table_lut[0]  = 0; // Para j=0
        tanh_inv_table_lut[1]  = 32'd35999;   // tanh_inv(2^-1) = 0.549306...
        tanh_inv_table_lut[2]  = 32'd16743;   // tanh_inv(2^-2) = 0.255412...
        tanh_inv_table_lut[3]  = 32'd8234;    // tanh_inv(2^-3) = 0.125657...
        tanh_inv_table_lut[4]  = 32'd4104;    // tanh_inv(2^-4) = 0.062581... (Ponto de repetição)
        tanh_inv_table_lut[5]  = 32'd2050;    // tanh_inv(2^-5) = 0.031260...
        tanh_inv_table_lut[6]  = 32'd1024;    // tanh_inv(2^-6) = 0.015628...
        tanh_inv_table_lut[7]  = 32'd512;     // tanh_inv(2^-7) = 0.007812...
        tanh_inv_table_lut[8]  = 32'd256;     // tanh_inv(2^-8) = 0.003906...
        tanh_inv_table_lut[9]  = 32'd128;     // tanh_inv(2^-9) = 0.001953...
        tanh_inv_table_lut[10] = 32'd64;      // tanh_inv(2^-10) = 0.000976...
        tanh_inv_table_lut[11] = 32'd32;      // tanh_inv(2^-11) = 0.000488...
        tanh_inv_table_lut[12] = 32'd16;      // tanh_inv(2^-12) = 0.000244...
        tanh_inv_table_lut[13] = 32'd8;       // tanh_inv(2^-13) = 0.000122... (Ponto de repetição)
        tanh_inv_table_lut[14] = 32'd4;       // tanh_inv(2^-14) = 0.000061...
        tanh_inv_table_lut[15] = 32'd2;       // tanh_inv(2^-15) = 0.000030...
        // Para j >= FRACTIONAL_BITS (16), 2^-j é 0 em Q16.16, então tanh_inv(2^-j) também é 0.
        for (integer i = 16; i < ITERATIONS; i = i + 1) begin
            tanh_inv_table_lut[i] = 0; 
        end
    end


    // LUT de arctangentes em formato fixo (32 bits)
   reg signed [31:0] atan_table [0:30];
   initial begin
      atan_table[00] = 32'b00100000000000000000000000000000; // 45.000 degrees -> atan(2^0)
      atan_table[01] = 32'b00010010111001000000010100011101; // 26.565 degrees -> atan(2^-1)
      atan_table[02] = 32'b00001001111110110011100001011011; // 14.036 degrees -> atan(2^-2)
      atan_table[03] = 32'b00000101000100010001000111010100; // atan(2^-3)
      atan_table[04] = 32'b00000010100010110000110101000011;
      atan_table[05] = 32'b00000001010001011101011111100001;
      atan_table[06] = 32'b00000000101000101111011000011110;
      atan_table[07] = 32'b00000000010100010111110001010101;
      atan_table[08] = 32'b00000000001010001011111001010011;
      atan_table[09] = 32'b00000000000101000101111100101110;
      atan_table[10] = 32'b00000000000010100010111110011000;
      atan_table[11] = 32'b00000000000001010001011111001100;
      atan_table[12] = 32'b00000000000000101000101111100110;
      atan_table[13] = 32'b00000000000000010100010111110011;
      atan_table[14] = 32'b00000000000000001010001011111001;
      atan_table[15] = 32'b00000000000000000101000101111100;
      atan_table[16] = 32'b00000000000000000010100010111110;
      atan_table[17] = 32'b00000000000000000001010001011111;
      atan_table[18] = 32'b00000000000000000000101000101111;
      atan_table[19] = 32'b00000000000000000000010100010111;
      atan_table[20] = 32'b00000000000000000000001010001011;
      atan_table[21] = 32'b00000000000000000000000101000101;
      atan_table[22] = 32'b00000000000000000000000010100010;
      atan_table[23] = 32'b00000000000000000000000001010001;
      atan_table[24] = 32'b00000000000000000000000000101000;
      atan_table[25] = 32'b00000000000000000000000000010100;
      atan_table[26] = 32'b00000000000000000000000000001010;
      atan_table[27] = 32'b00000000000000000000000000000101;
      atan_table[28] = 32'b00000000000000000000000000000010;
      atan_table[29] = 32'b00000000000000000000000000000001;
      atan_table[30] = 32'b00000000000000000000000000000000;
   end

    FINALIZE: begin
        case (mode_coord)
            CIRCULAR: begin                            
                mult_x = reg_X * K_CIRCULAR_FIXED;
                mult_y = reg_Y * K_CIRCULAR_FIXED;
                
                x_out <= mult_x >>> FRACTIONAL_BITS;
                y_out <=x_out <= mult_y >>> FRACTIONAL_BITS;
                z_out <= reg_Z;                            
            end
            HYPERBOLIC: begin                            
                mult_x = reg_X * K_HYPERBOLIC_FIXED;
                mult_y = reg_Y * K_HYPERBOLIC_FIXED;

                x_out <= mult_x >>> FRACTIONAL_BITS;
                y_out <= mult_y >>> FRACTIONAL_BITS;
                z_out <= reg_Z;                            
            end
            default: begin
                x_out <= reg_X;
                y_out <= reg_Y;
                z_out <= reg_Z;
            end
        endcase
    end
*/