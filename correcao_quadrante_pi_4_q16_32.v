module correcao_quadrante_pi_4_q16_32 #(
    parameter WIDTH = 32, // Tamanho dos dados de entrada (Q16.16)
    parameter INTERNAL_WIDTH = 48 // Tamanho dos dados internos e saída (Q16.32)
) (
    input clk,
    input rst,
    input enable,
    input signed [WIDTH-1:0] z_in, // Entrada em Q16.16
    output signed [INTERNAL_WIDTH-1:0] z_out, // Saída em Q16.32
    output [2:0] quadrante,
    output done
);

    localparam START   = 3'b000;
    localparam VERIF   = 3'b001;
    localparam MAIOR   = 3'b010;
    localparam MENOR   = 3'b011;
    localparam VERIF_2 = 3'b100;
    localparam CORQUAD = 3'b101;

    localparam FRACTIONAL_BITS = 32;

    localparam signed [INTERNAL_WIDTH-1:0] _360_2PI     = 48'sd26986075409;  // 2π ≈ 6.283185307 * 2^32
    localparam signed [INTERNAL_WIDTH-1:0] _225_NEG     = -48'sd16866297130; // ≈ -3.926990817 * 2^32
    localparam signed [INTERNAL_WIDTH-1:0] _225_POS     = 48'sd16866297130;  // ≈ 3.926990817 * 2^32
    localparam signed [INTERNAL_WIDTH-1:0] _45_PI_4_POS = 48'sd3373259426;   // π/4 ≈ 0.785398163 * 2^32
    localparam signed [INTERNAL_WIDTH-1:0] _45_PI_4_NEG = -48'sd3373259426;  // π/4 ≈ -0.785398163 * 2^32
    localparam signed [INTERNAL_WIDTH-1:0] _135_3PI_4   = 48'sd10119778278;  // 3π/4 ≈ 2.356194490 * 2^32
    localparam signed [INTERNAL_WIDTH-1:0] _90_PI_2     = 48'sd6746518852;   // π/2 ≈ 1.570796327 * 2^32
    localparam signed [INTERNAL_WIDTH-1:0] _180_PI      = 48'sd13493037704;  // π   ≈ 3.141592654 * 2^32
    localparam signed [INTERNAL_WIDTH-1:0] _315_5_5     = 48'sd23623350920;  // ≈ 5.50024 * 2^32
    localparam signed [INTERNAL_WIDTH-1:0] _ZERO        = 48'd0;             // 0

    reg [2:0] state, next_state;
    reg signed [INTERNAL_WIDTH-1:0] z_aux, z_tratado, z_normalizado;
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
                        // Converte z_in (Q16.16) para z_tratado (Q16.32)
                        z_tratado <= {z_in, {FRACTIONAL_BITS-16{1'b0}}};
                        next_state <= VERIF;
                    end else begin
                        next_state <= START;
                    end
                end
                VERIF : begin
                    if (z_tratado > _360_2PI) begin
                        next_state <= MAIOR;
                    end else if (z_tratado < _ZERO && z_tratado < _45_PI_4_NEG) begin // Verifica se é negativo e menor que -45°
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
                    end else if (z_normalizado > _135_3PI_4 && z_normalizado <= _180_PI) begin // maior que 135° e menor ou igual a 180° 
                        z_aux <= z_normalizado - _180_PI; // θ° - 180°
                        quad_in <= 3'b010;                        
                    end else if (z_normalizado > _180_PI && z_normalizado <= _225_POS) begin // maior que 180° e menor ou igual a 225° 
                        z_aux <= z_normalizado + _180_PI - _360_2PI; // θ° + 180° - 360°
                        quad_in <= 3'b011;                        
                    end else if (z_normalizado > _225_POS && z_normalizado <= _315_5_5) begin // maior que 225° e menor ou igual a 315° 
                        z_aux <= z_normalizado + _90_PI_2 - _360_2PI; // θ° + 90° - 360°
                        quad_in <= 3'b100;
                    end else begin // entre -45° e 45° (ou equivalente)
                        z_aux <= z_normalizado; // não há alteração
                        quad_in <= 3'b000;
                    end
                    completed <= 1'b1; // Concluiu a correção
                    next_state <= START;
                end
                default : begin
                    next_state <= START;
                    completed <= 1'b0;
                end
            endcase
        end
    end

    // Saídas
    assign quadrante = quad_in;
    assign z_out     = z_aux;
    assign done      = completed;

endmodule