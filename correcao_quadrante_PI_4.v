module correcao_quadrante_pi_4 #(
    parameter WIDTH = 32 //tamanho dos dados de entrada e saída
) (
    input clk,
    input rst,
    input enable,
    input signed [WIDTH-1:0] z_in,
    output signed [WIDTH-1:0] z_out,
    output [2:0] quadrante,
    output done
);

    localparam START   = 3'b000;
    localparam VERIF   = 3'b001;
    localparam MAIOR   = 3'b010;
    localparam MENOR   = 3'b011;
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
    reg [2:0] quad_in;
    reg completed;

    always @(*) begin
        if (rst) begin
            state <= START;
        end else 
            state <= next_state;
    end

    always @(posedge clk or posedge rst) begin
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