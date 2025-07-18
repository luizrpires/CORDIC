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
        case (state)
            IDLE:      next_state = (enable) ? VERIF : IDLE;
            VERIF:     next_state = (z_normalized < TWO_POS && z_normalized > TWO_NEG) ? IDLE : NORMALIZE;
            NORMALIZE: next_state = VERIF;
            default:   next_state = IDLE;
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
            z_normalized <= 0;
            z_aux        <= 0;
            count_aux    <= 0;
            count_n_aux  <= 0;
            completed    <= 1'b0;
        end else begin
            case (state)
                IDLE : begin
                    z_normalized <= (enable) ? z_in : 1'b0;
                    z_aux        <= 0;
                    count_aux    <= 0;
                    completed    <= 1'b0;     
                end
                VERIF : begin
                    count_n_aux <= count_aux;
                    if (z_normalized < TWO_POS && z_normalized > TWO_NEG) begin
                        completed <= 1'b1;
                    end else begin
                        z_aux <= z_normalized;
                        completed <= 1'b0;
                    end
                end
                NORMALIZE : begin
                    z_normalized <= z_aux >>> 1; // divide por 2
                    count_aux <= count_n_aux + 1'b1; //soma 1 ao contador de divisões
                    completed <= 1'b0;
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