module correcao_quadrante_1_4_graus #(
    parameter ITERATIONS = 16, //quantidade de iterações
    parameter WIDTH = 32 //tamanho dos dados de entrada e saída
) (
    input clk,
    input rst,
    input signed [WIDTH-1:0] z,
    output reg signed [WIDTH-1:0] z_in,
    output reg signed [1:0] sinal_seno,
    output reg signed [1:0] sinal_cosseno
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
             z_in <= 0;
             sinal_seno <= 2'sd1;
             sinal_cosseno <= 2'sd1;
        end
        else if (z >= -32'sd5898240 && z <= 32'sd5898240 ) begin // 1° ou 4° quarante, sem correção
                z_in <= z;
                sinal_seno <= 2'sd1;
                sinal_cosseno <= 2'sd1;

        end else if (z > 32'sd5898240 && z <= 32'sd11796480) begin // 2° quadrante, com correção para 
                z_in <= 32'sd11796480 - z; // 180° - Z
                sinal_seno <= 2'sd1;
                sinal_cosseno <= -2'sd1;
        end else begin // 3° quadrante com correção
                z_in <= -32'sd11796480 - z; // -180° - Z
                sinal_seno <= 2'sd1;
                sinal_cosseno <= -2'sd1;
            end
    end
endmodule