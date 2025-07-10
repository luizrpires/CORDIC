module cordic_stage #(parameter I = 0)(
    input  wire clk,
    input  wire signed [31:0] x_in,
    input  wire signed [31:0] y_in,
    input  wire signed [31:0] z_in,
    output reg  signed [31:0] x_out,
    output reg  signed [31:0] y_out,
    output reg  signed [31:0] z_out
);

    function signed [31:0] atan_lookup;
        input integer index;
        case (index)
            0:  atan_lookup = 32'sd51471;
            1:  atan_lookup = 32'sd30385;
            2:  atan_lookup = 32'sd16055;
            3:  atan_lookup = 32'sd8149;
            4:  atan_lookup = 32'sd4090;
            5:  atan_lookup = 32'sd2045;
            6:  atan_lookup = 32'sd1023;
            7:  atan_lookup = 32'sd511;
            8:  atan_lookup = 32'sd256;
            9:  atan_lookup = 32'sd128;
            10: atan_lookup = 32'sd64;
            11: atan_lookup = 32'sd32;
            12: atan_lookup = 32'sd16;
            13: atan_lookup = 32'sd8;
            14: atan_lookup = 32'sd4;
            15: atan_lookup = 32'sd2;
            default: atan_lookup = 32'sd0;
        endcase
    endfunction

    wire signed [31:0] x_shift = x_in >>> I;
    wire signed [31:0] y_shift = y_in >>> I;
    wire d = z_in[31];

    wire signed [31:0] x_next = d ? (x_in + y_shift) : (x_in - y_shift);
    wire signed [31:0] y_next = d ? (y_in - x_shift) : (y_in + x_shift);
    wire signed [31:0] z_next = d ? (z_in + atan_lookup(I)) : (z_in - atan_lookup(I));

    //Insere Flip-flop na saída de cada estágio
    always @(posedge clk) begin
        x_out <= x_next;
        y_out <= y_next;
        z_out <= z_next;
    end
endmodule


module cordic_pipeline (
    input  wire clk,
    input  wire signed [31:0] angle,
    output wire signed [31:0] cos_out,
    output wire signed [31:0] sin_out
);

    // Número de estágios
    parameter N = 16;

    // Declaração de sinais intermediários (x, y, z)
    wire signed [31:0] x0,  x1,  x2,  x3,  x4,  x5,  x6,  x7,
                       x8,  x9,  x10, x11, x12, x13, x14, x15, x16;
    wire signed [31:0] y0,  y1,  y2,  y3,  y4,  y5,  y6,  y7,
                       y8,  y9,  y10, y11, y12, y13, y14, y15, y16;
    wire signed [31:0] z0,  z1,  z2,  z3,  z4,  z5,  z6,  z7,
                       z8,  z9,  z10, z11, z12, z13, z14, z15, z16;

    // Inicialização
    assign x0 = 32'sd39797; // K ≈ 0.60725293 * 2^16
    assign y0 = 32'sd0;
    assign z0 = angle;

    // Estágios do pipeline
    cordic_stage #(0) s0 (clk, x0,  y0,  z0,  x1,  y1,  z1);
    cordic_stage #(1) s1 (clk, x1,  y1,  z1,  x2,  y2,  z2);
    cordic_stage #(2) s2 (clk, x2,  y2,  z2,  x3,  y3,  z3);
    cordic_stage #(3) s3 (clk, x3,  y3,  z3,  x4,  y4,  z4);
    cordic_stage #(4) s4 (clk, x4,  y4,  z4,  x5,  y5,  z5);
    cordic_stage #(5) s5 (clk, x5,  y5,  z5,  x6,  y6,  z6);
    cordic_stage #(6) s6 (clk, x6,  y6,  z6,  x7,  y7,  z7);
    cordic_stage #(7) s7 (clk, x7,  y7,  z7,  x8,  y8,  z8);
    cordic_stage #(8) s8 (clk, x8,  y8,  z8,  x9,  y9,  z9);
    cordic_stage #(9) s9 (clk, x9,  y9,  z9,  x10, y10, z10);
    cordic_stage #(10) s10(clk, x10, y10, z10, x11, y11, z11);
    cordic_stage #(11) s11(clk, x11, y11, z11, x12, y12, z12);
    cordic_stage #(12) s12(clk, x12, y12, z12, x13, y13, z13);
    cordic_stage #(13) s13(clk, x13, y13, z13, x14, y14, z14);
    cordic_stage #(14) s14(clk, x14, y14, z14, x15, y15, z15);
    cordic_stage #(15) s15(clk, x15, y15, z15, x16, y16, z16);

    // Saídas
    assign cos_out = x16;
    assign sin_out = y16;

endmodule
