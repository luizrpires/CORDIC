module top_level_calc_cordic #(
    parameter ITERATIONS = 16, //quantidade de iterações
    parameter WIDTH = 32 //tamanho dos dados de entrada e saída
)(
    input clk,
    input rst,
    input enable,
    input [3:0] operation,
    input signed [WIDTH-1:0] x_in,
    input signed [WIDTH-1:0] y_in,
    input signed [WIDTH-1:0] z_in,
    output reg signed [WIDTH-1:0] result,
    output reg done
);

    //MODO COORDENADA
    localparam  CIRCULAR   = 2'b01, //1 para Circular
                LINEAR     = 2'b00, //0 para Linear
                HYPERBOLIC = 2'b11; //-1 para Hiperbólico

    //MODO OPERAÇÃO 
    localparam  ROTATION  = 1'b0, //0 para Rotação
                VECTORING = 1'b1; //1 para Vetorização

    // OPERAÇÕES
    localparam  SIN      = 4'b0000, //0 para Seno
                COS      = 4'b0001, //1 para Cosseno
                TAN      = 4'b0010, //2 para Tangente
                ATAN     = 4'b0011, //3 para Arco Tangente
                MAG      = 4'b0100, //4 para Magnitude
                POLtoREC = 4'b0101, //5 para Conversão Polar para Retangular
                RECtoPOL = 4'b0110, //6 para Conversão Retangular para Polar
                MULT     = 4'b0111, //7 para Multiplicação
                DIV      = 4'b1000, //8 para Divisão
                SINH     = 4'b1001, //9 para Seno Hiperbólico
                COSH     = 4'b1010, //10 para Cosseno Hiperbólico
                ATANH    = 4'b1011, //11 para Arco Tangente Hiperbólico
                EXP      = 4'b1100, //12 para Exponencial
                LOG      = 4'b1101, //13 para Logaritmo
                SQRT     = 4'b1110, //14 para Raiz Quadrada
                DEFAULT  = 4'b1111; // Padrão/Sem uso

    
    localparam K_INV_CIRCULAR   = 32'd39797;    // 1 / 1.64676 = 0.6072529350088813 * 2^16
    localparam K_CIRCULAR       = 32'd107936;   // 1.646760258121066 * 2^16
    localparam K_INV_HYPERBOLIC = 32'd79134;    // 1 / 0.82816 = 1.2074970677630726 * 2^16
    localparam K_HYPERBOLIC     = 32'd54275;    // 0.8281593606 * 2^16

    reg [1:0] mode_coord;
    reg mode_op; // (0 para Rotação, 1 para Vetorização)
    reg signed [WIDTH-1:0] x_aux, y_aux, z_aux;
    reg signed [WIDTH-1:0] result_aux;
    reg completed;
    wire signed [WIDTH-1:0] x_out, y_out, z_out;
    wire valid;

    cordic #(
        .ITERATIONS(ITERATIONS), 
        .WIDTH(WIDTH) 
    ) ins_cordic (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .mode_op(mode_op),
        .mode_coord(mode_coord), 
        .x_in(x_aux),
        .y_in(y_aux),
        .z_in(z_aux),
        .x_out(x_out),
        .y_out(y_out),
        .z_out(z_out),
        .valid(valid)
    );

    always @(*) begin
        if (rst) begin
            //mode_coord <= ; // Padrão
            //mode_op    <= ; // Padrão
            x_aux        <= 32'sb0;
            y_aux        <= 32'sb0;
            z_aux        <= 32'sb0;
        end else begin
            case (operation)
                SIN: begin
                    mode_coord <= CIRCULAR;
                    mode_op    <= ROTATION;
                    x_aux      <= K_INV_CIRCULAR;
                    y_aux      <= 0.0;
                    z_aux      <= z_in;
                end

                COS: begin
                    mode_coord <= CIRCULAR;
                    mode_op    <= ROTATION;
                    x_aux      <= K_INV_CIRCULAR;
                    y_aux      <= 0.0;
                    z_aux      <= z_in;
                end
                
                MULT: begin
                    mode_coord <= LINEAR;
                    mode_op    <= ROTATION;
                    x_aux      <= x_in;
                    y_aux      <= 32'sb0;
                    z_aux      <= z_in;
                end
                
                DIV: begin
                    mode_coord <= LINEAR;
                    mode_op    <= VECTORING;
                    x_aux      <= x_in; //divisor
                    y_aux      <= y_in; //dividendo
                    z_aux      <= 32'sb0;
                end
                
                SINH: begin
                    mode_coord <= HYPERBOLIC;
                    mode_op    <= ROTATION;
                    x_aux      <= K_INV_HYPERBOLIC;
                    y_aux      <= 0.0;
                    z_aux      <= z_in;
                end
                
                COSH: begin
                    mode_coord <= HYPERBOLIC;
                    mode_op    <= ROTATION;
                    x_aux      <= K_INV_HYPERBOLIC;
                    y_aux      <= 0.0;
                    z_aux      <= z_in;
                end

                default: begin
                    //mode_coord <= ; // Padrão
                    //mode_op    <= ; // Padrão
                    x_aux        <= 32'sb0;
                    y_aux        <= 32'sb0;
                    z_aux        <= 32'sb0;
                end
            endcase
        end
    end

    always @(*) begin
        if (rst) begin
            completed  <= 1'b0;
            result_aux <= 32'sb0;
        end else begin
            if (valid) begin
                case (operation) 
                    SIN: result_aux     <= y_out;
                    COS: result_aux     <= x_out;
                    MULT: result_aux    <= y_out;
                    DIV: result_aux     <= z_out;
                    SINH: result_aux    <= y_out;
                    COSH: result_aux    <= x_out;
                    default: result_aux <= 32'sb0;
                endcase
                completed <= 1'b1;
            end else begin 
                completed  <= 1'b0;
                result_aux <= 32'sb0;
            end
        end 
    end

    assign result = result_aux;
    assign done   = completed;
    
endmodule