module cordic #(
    parameter ITERATIONS = 32, //quantidade de iterações
    parameter WIDTH = 32 //tamanho dos dados de entrada e saída
)(
    input clk,
    input rst,
    input enable,
    input signed [1:0] mode_op,
    input signed [1:0] mode_coord, 
    input signed [WIDTH-1:0] x_in,
    input signed [WIDTH-1:0] y_in,
    input signed [WIDTH-1:0] z_in,
    output reg signed [WIDTH-1:0] x_out,
    output reg signed [WIDTH-1:0] y_out,
    output reg signed [WIDTH-1:0] z_out,
    output reg valid
);

    //MODO COORDENADA
    localparam  signed [1:0] CIRCULAR = 2'b01, //1 para Circular
                signed [1:0] LINEAR = 2'b00, //0 para Linear
                signed [1:0] HYPERBOLIC = 2'b11; //-1 para Hiperbólico

    //MODO OPERAÇÃO 
    localparam  signed [1:0] ROTATION = 2'b00, //0 para Rotação
                signed [1:0] VECTORING = 2'b01; //1 para Vetorização

    //ESTADOS
    localparam  [2:0] IDLE = 3'b000,
                [2:0] INITIALIZE = 3'b001,
                [2:0] ITERATE = 3'b010,
                [2:0] FINALIZE = 3'b011,
                [2:0] DONE = 3'b100;

    localparam signed [WIDTH-1:0] K_CIRCULAR_FIXED;  // 1.64676
    localparam signed [WIDTH-1:0] K_LINEAR_FIXED;    // 1.0
    localparam signed [WIDTH-1:0] K_HYPERBOLIC_FIXED; // 0.82816

    reg [2:0] state, next_state;
    reg [$clog2(ITERATIONS):0] iter_counter; 
    reg signed [WIDTH-1:0] reg_X, reg_Y, reg_Z, next_X, next_Y, next_Z, shift_X, shift_Y;
    reg signed [WIDTH-1:0] alpha;
    reg [0:0] sigma; // Sinal de direção: 0 para -1, 1 para +1
    reg hyperbolic_repeat; // Sinal de controle para repetição de iteração no modo hiperbólico
    reg hyperbolic_4, hyperbolic_13; // Sinais de controle para iterações específicas no modo hiperbólico


    initial begin
        hyperbolic_4 = 1'b1; // Inicializa o sinal de iteração 4 como verdadeiro
        hyperbolic_13 = 1'b1; // Inicializa o sinal de iteração 13 como verdadeiro
        valid = 1'b0; // Inicializa o sinal de saída como inválido
    end

    //Lógica para definir a direção da rotação ou vetorização
    always @(*) begin
        if (mode_op == ROTATION) begin
            if (reg_Z[WIDTH-1] == 1'b0) begin //testa se Z é positivo
                sigma = 1'b1; //1 para +1 
            end else begin
                sigma = 1'b0; //0 para -1
            end
        end 

        if (mode_op == VECTORING) begin
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
            CIRCULAR: begin
                alpha = atan_table[iter_counter]; // mode_coord = 1: alpha = atan(2^-j)
            end
            LINEAR: begin
                alpha = ; // mode_coord = 0: alpha = 2^-j
            end
            HYPERBOLIC: begin
                alpha = ; // mode_coord = -1: alpha = tanh_inv(2^-j)
            end
            default: begin
                alpha = 0; // Valor padrão para evitar latch
            end
        endcase
    end

    /* Shift registers*/
    always @(*) begin
        shift_X <= (iter_counter < WIDTH) ? (reg_X >>> iter_counter) : 0;
        shift_Y <= (iter_counter < WIDTH) ? (reg_Y >>> iter_counter) : 0;
    end

    //Lógica de transição de estados
    always @(*) begin
        case (state)
            IDLE: 
                next_state <= (enable) ? INITIALIZE : IDLE;
            INITIALIZE: 
                next_state <= ITERATE;
            ITERATE: 
                next_state <= (iter_counter == ITERATIONS) ? FINALIZE : ITERATE;
            FINALIZE: 
                next_state <= DONE;
            DONE: 
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

                INITIALIZE: begin
                    reg_X <= x_in;
                    reg_Y <= y_in;
                    reg_Z <= z_in;
                    iter_counter <= 0;
                    valid_out <= 1'b0;
                end

                ITERATE: begin
                    case (mode_coord)
                        //xi+1 = xi − μ σi yi 2^−i
                        //yi+1 = yi + σi xi 2^−i
                        //zi+1 = zi − σi αi

                        CIRCULAR: begin // m = 1
                           
                        end

                        LINEAR: begin // m = 0
                          
                        end

                        HYPERBOLIC: begin // m = -1                            
                            
                        end

                        default: begin
                            next_X = reg_X;
                            next_Y = reg_Y;
                            next_Z = reg_Z;
                        end
                    endcase

                    // Atualiza os registros com os novos valores
                    reg_X <= next_X;
                    reg_Y <= next_Y;
                    reg_Z <= next_Z;

                    // No modo hiperbólico, as iterações 4 e 13 são repetidas
                    if (coord_mode == HYPERBOLIC) begin
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
                            x_out <= (reg_X * K_CIRCULAR_FIXED);
                            y_out <= (reg_Y * K_CIRCULAR_FIXED);
                            z_out <= reg_Z;
                        end
                        HYPERBOLIC: begin
                            x_out <= (reg_X * K_HYPERBOLIC_FIXED);
                            y_out <= (reg_Y * K_HYPERBOLIC_FIXED);
                            z_out <= reg_Z;
                        end
                        default: begin
                            x_out <= reg_X;
                            y_out <= reg_Y;
                            z_out <= reg_Z;
                        end
                    endcase
                end

                DONE: begin
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


endmodule