module corr_z_multi_q16_32 #(
    parameter WIDTH = 32, // Tamanho dos dados de entrada (Q16.16)
    parameter INTERNAL_WIDTH = 48 // Tamanho dos dados internos e saída (Q16.32)
)(
    input clk,
    input rst,
    input enable,
    input signed [WIDTH-1:0] z_in, // Entrada em Q16.16
    output signed [INTERNAL_WIDTH-1:0] z_out, // Saída em Q16.32
    output [3:0] count_div, 
    output done
);

    localparam IDLE      = 2'b00;
    localparam VERIF     = 2'b01;
    localparam NORMALIZE = 2'b10;
    
    localparam FRACTIONAL_BITS = 32;
    localparam signed [INTERNAL_WIDTH-1:0] ONE_POS = 48'sd4294967296;  // 1.0 * 2^32
    localparam signed [INTERNAL_WIDTH-1:0] ONE_NEG = -48'sd4294967296; // -1.0 * 2^32
    localparam signed [INTERNAL_WIDTH-1:0] TWO_POS = 48'sd8589934592;  // 2.0 * 2^32
    localparam signed [INTERNAL_WIDTH-1:0] TWO_NEG = -48'sd8589934592; // -2.0 * 2^32

    reg [1:0] state, next_state;
    reg signed [INTERNAL_WIDTH-1:0] z_aux, z_normalized; 
    reg [3:0] count_aux, count_n_aux; 
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
            z_normalized <= {INTERNAL_WIDTH{1'b0}};
            z_aux        <= {INTERNAL_WIDTH{1'b0}};
            count_aux    <= 0;
            count_n_aux  <= 0;
            completed    <= 1'b0;
        end else begin
            next_state <= state;
            case (state)
                IDLE : begin   
                    completed   <= 1'b0;       
                    if (enable) begin
                        z_normalized <= {z_in, {FRACTIONAL_BITS-16{1'b0}}}; 
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
                    count_aux    <= count_n_aux + 1; //soma 1 ao contador de divisões
                    completed    <= 1'b0;
                    next_state   <= VERIF;
                end
                default : begin
                    z_normalized <= {INTERNAL_WIDTH{1'b0}};
                    z_aux        <= {INTERNAL_WIDTH{1'b0}};
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