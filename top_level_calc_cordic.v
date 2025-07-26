module top_level_calc_cordic #(
    parameter ITERATIONS = 16 //quantidade de iterações
)(
    clk, rst, enable, 
    operation, 
    x_in, y_in, z_in,
    result,
    done
);
    localparam WIDTH = 32; //tamanho dos dados de entrada e saída

    input clk;
    input rst;
    input enable;
    input [3:0] operation;
    input signed [WIDTH-1:0] x_in;
    input signed [WIDTH-1:0] y_in;
    input signed [WIDTH-1:0] z_in;
    output signed [WIDTH-1:0] result;
    output done;

    //MODO COORDENADA
    localparam  CIRCULAR   = 2'b01, //1 para Circular
                LINEAR     = 2'b00, //0 para Linear
                HYPERBOLIC = 2'b11; //-1 para Hiperbólico

    //MODO OPERAÇÃO 
    localparam  ROTATION  = 1'b0, //0 para Rotação
                VECTORING = 1'b1; //1 para Vetorização

    // OPERAÇÕES
    localparam  SIN     = 4'b0000, //0 para Seno
                COS     = 4'b0001, //1 para Cosseno
                ATAN    = 4'b0010, //2 para Arc Tangente
                MOD     = 4'b0011, //3 para Módulo/Magnitude
                MULT    = 4'b0100, //4 para Multiplicação
                DIV     = 4'b0101, //5 para Divisão
                SINH    = 4'b0110, //6 para Seno Hiperbólico
                COSH    = 4'b0111, //7 para Cosseno Hiperbólico
                ATANH   = 4'b1000, //8 para Arc Tangente Hiperbólico
                MODH    = 4'b1001, //9 para Módulo Hiperbólico
                //      = 4'b1010, //10 para 
                //      = 4'b1011, //11 para 
                //      = 4'b1100, //12 para  
                //      = 4'b1101, //13 para 
                //      = 4'b1110, //14 para 
                DEFAULT = 4'b1111; // Padrão/Sem uso

    
    localparam signed [WIDTH-1:0] K_INV_CIRCULAR   = 32'sd39797;    // 1 / 1.64676 = 0.6072529350088813 * 2^16
    localparam signed [WIDTH-1:0] K_CIRCULAR       = 32'sd107936;   // 1.646760258121066 * 2^16
    localparam signed [WIDTH-1:0] K_INV_HYPERBOLIC = 32'sd79134;    // 1 / 0.82816 = 1.2074970677630726 * 2^16
    localparam signed [WIDTH-1:0] K_HYPERBOLIC     = 32'sd54275;    // 0.8281593606 * 2^16

    reg [1:0] mode_coord;
    reg mode_op; // (0 para Rotação, 1 para Vetorização)
    reg signed [WIDTH-1:0] x_aux, y_aux, z_aux;
    reg signed [WIDTH-1:0] result_aux;
    reg completed;
    wire signed [WIDTH-1:0] x_out, y_out, z_out;
    wire valid;

    //INSTANCIA DA ARQUITETURA 
    cordic_parallel_q16_32 #(
    //cordic_parallel #(
    //cordic_q16_32 #(
    //cordic #(
        .ITERATIONS(ITERATIONS) 
    ) ins_cordic (
        .clk(clk),
        .rst(rst),
        .enable(enable), 
        .x_in(x_aux),
        .y_in(y_aux),
        .z_in(z_aux),
        .mode_op(mode_op),
        .mode_coord(mode_coord),
        .x_out(x_out),
        .y_out(y_out),
        .z_out(z_out),
        .valid(valid)
    );

    always @(*) begin
        if (rst) begin
            x_aux <= 32'b0;
            y_aux <= 32'b0;
            z_aux <= 32'b0;
        end else begin
            case (operation)
                // CIRCULAR + ROTATION
                SIN: begin
                    mode_coord <= CIRCULAR;
                    mode_op    <= ROTATION;
                    x_aux      <= 32'b0;
                    y_aux      <= 32'b0;
                    z_aux      <= z_in;
                end

                COS: begin
                    mode_coord <= CIRCULAR;
                    mode_op    <= ROTATION;
                    x_aux      <= 32'b0;
                    y_aux      <= 32'b0;
                    z_aux      <= z_in;
                end
                //////////////////////

                // CIRCULAR + VECTORING
                ATAN, MOD: begin
                    mode_coord <= CIRCULAR;
                    mode_op    <= VECTORING;
                    x_aux      <= x_in;
                    y_aux      <= y_in;
                    z_aux      <= 32'b0;
                end
                ///////////////////////

                // LINEAR + VECTORING
                DIV: begin
                    mode_coord <= LINEAR;
                    mode_op    <= VECTORING;
                    x_aux      <= x_in; //divisor
                    y_aux      <= y_in; //dividendo
                    z_aux      <= 32'b0;
                end
                /////////////////////

                // LINEAR + ROTATION
                MULT: begin
                    mode_coord <= LINEAR;
                    mode_op    <= ROTATION;
                    x_aux      <= x_in;
                    y_aux      <= 32'b0;
                    z_aux      <= z_in;
                end
                ////////////////////

                // HYPERBOLIC + ROTATION
                SINH: begin
                    mode_coord <= HYPERBOLIC;
                    mode_op    <= ROTATION;
                    x_aux      <= 32'b0;
                    y_aux      <= 32'b0;
                    z_aux      <= z_in;
                end
                
                COSH: begin
                    mode_coord <= HYPERBOLIC;
                    mode_op    <= ROTATION;
                    x_aux      <= 32'b0;
                    y_aux      <= 32'b0;
                    z_aux      <= z_in;
                end
                ////////////////////////

                // HYPERBOLIC + VECTORING
                MODH, ATANH: begin
                    mode_coord <= HYPERBOLIC;
                    mode_op    <= VECTORING;
                    x_aux      <= x_in;
                    y_aux      <= y_in;
                    z_aux      <= 32'b0;
                end
                /////////////////////////            

                default: begin
                    x_aux <= 32'b0;
                    y_aux <= 32'b0;
                    z_aux <= 32'b0;
                end
            endcase
        end
    end

    always @(*) begin
        if (rst) begin
            completed  <= 1'b0;
            result_aux <= 32'b0;
        end else begin
            if (valid) begin
                case (operation) 
                    //CIRCULAR
                    SIN:begin
                        result_aux <= y_out;
                    end
                      
                    COS: begin
                        result_aux <= x_out;
                    end
                    
                    MOD: begin
                        result_aux <= x_out;                        
                    end 

                    ATAN: begin
                        result_aux <= z_out;
                    end 

                    //LINEAR
                    MULT: begin
                        result_aux <= y_out;                       
                    end 
                    DIV: begin
                        result_aux <= z_out;
                    end  

                    //HIPERBÓLICO
                    SINH: begin
                        result_aux <= y_out;
                    end 
                    COSH: begin
                        result_aux <= x_out;
                    end
                    MODH: begin
                        result_aux <= x_out;                    
                    end 
                    ATANH: begin
                        result_aux <= z_out;
                    end 

                    default: result_aux <= 32'b0;
                endcase
                completed <= 1'b1;
            end else begin 
                completed  <= 1'b0;
                result_aux <= 32'b0;
            end
        end 
    end

    assign result = result_aux;
    assign done   = completed;    
endmodule