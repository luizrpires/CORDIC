module calc_cordic #(
    parameter ITERATIONS = 16, //quantidade de iterações
    parameter WIDTH = 32 //tamanho dos dados de entrada e saída
)(
    input clk,
    input rst,
    input enable,
    input [2:0] operation,
    input signed [WIDTH-1:0] x_in,
    input signed [WIDTH-1:0] y_in,
    input signed [WIDTH-1:0] z_in,
    output reg signed [WIDTH-1:0] result,
    output reg done
);

    //MODO COORDENADA
    localparam  CIRCULAR = 2'b01, //1 para Circular
                LINEAR = 2'b00, //0 para Linear
                HYPERBOLIC = 2'b11; //-1 para Hiperbólico

    //MODO OPERAÇÃO 
    localparam  ROTATION = 1'b0, //0 para Rotação
                VECTORING = 1'b1; //1 para Vetorização

    // OPERAÇÕES
    localparam  SIN = 3'b000, //0 para Seno
                COS = 3'b001, //1 para Cosseno
                MULT = 3'b010, //2 para Multiplicação
                DIV = 3'b011, //3 para Divisão
                SIN_HIP = 3'b100, //4 para Seno Hiperbólico
                COS_HIP = 3'b101; //5 para Cosseno Hiperbólico
    
    localparam K_CIRCULAR = 32'd39797;    // 1/1.64676 * 2^16
    localparam K_HYPERBOLIC = 32'd79102;    // 1/0.82816 * 2^16

    reg [1:0] mode_coord;
    reg mode_op; // 1 bit para modo de operação (0 para Rotação, 1 para Vetorização)
    reg signed [WIDTH-1:0] x_aux, y_aux, z_aux;
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
            //mode_coord = ; // Padrão
            //mode_op = ; // Padrão
            x_aux = 32'b0;
            y_aux = 32'b0;
            z_aux = 32'b0;
        end else begin
            case (operation)
                SIN: begin
                    mode_coord = CIRCULAR;
                    mode_op = ROTATION;
                    x_aux = K_CIRCULAR; 
                    y_aux = 32'b0;
                    z_aux = z_in;
                end

                COS: begin
                    mode_coord = CIRCULAR;
                    mode_op = ROTATION;
                    x_aux = K_CIRCULAR;
                    y_aux = 32'b0;
                    z_aux = z_in;
                end
                
                MULT: begin
                    mode_coord = LINEAR;
                    mode_op = ROTATION;
                    x_aux = x_in;
                    y_aux = 32'b0;
                    z_aux = z_in;
                end
                
                DIV: begin
                    mode_coord = LINEAR;
                    mode_op = VECTORING;
                    x_aux = x_in; //divisor
                    y_aux = y_in; //dividendo
                    z_aux = 32'b0;
                end
                
                SIN_HIP: begin
                    mode_coord = HYPERBOLIC;
                    mode_op = ROTATION;
                    x_aux = K_HYPERBOLIC;
                    y_aux = 32'b0;
                    z_aux = z_in;
                end
                
                COS_HIP: begin
                    mode_coord = HYPERBOLIC;
                    mode_op = ROTATION;
                    x_aux = K_HYPERBOLIC;
                    y_aux = 32'b0;
                    z_aux = z_in;
                end

                default: begin
                    //mode_coord = ; // Padrão
                    //mode_op = ; // Padrão
                    x_aux = 32'b0;
                    y_aux = 32'b0;
                    z_aux = 32'b0;
                end
            endcase
        end
    end

    always @(*) begin
        if (rst) begin
            done = 1'b0;
            result = 32'b0;
        end else begin
            if (valid) begin
                done = 1'b1;
                case (operation) 
                    SIN: result = y_out;
                    COS: result = x_out;
                    MULT: result = y_out;
                    DIV: result = z_out;
                    SIN_HIP: result = y_out;
                    COS_HIP: result = x_out;
                    default: result = 32'b0;
                endcase
            end else begin 
                done = 1'b0;
                result = 32'b0;
            end
        end 
    end
    



endmodule