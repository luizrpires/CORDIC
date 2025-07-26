# CORDIC IP Core (Circular, Linear, Hyperbolic Modes)

Este repositório contém uma implementação do algoritmo CORDIC (Coordinate Rotation Digital Computer) em Verilog, desenvolvido como um IP Core. O CORDIC é um algoritmo eficiente para calcular uma ampla gama de funções trigonométricas, hiperbólicas e lineares usando apenas operações de deslocamento (shift) e adição/subtração.

O projeto inclui diferentes implementações para atender a diversas necessidades de precisão e arquitetura:

* **`cordic.v`**: Implementação CORDIC sequencial com precisão de 32 bits em formato Q16.16.
* **`cordic_q16_32.v`**: Implementação CORDIC sequencial com precisão de 48 bits em formato Q16.32 para cálculos internos, com entrada e saída em Q16.16.
* **`cordic_parallel.v`**: Implementação CORDIC paralela com precisão de 32 bits em formato Q16.16.
* **`cordic_parallel_q16_32.v`**: Implementação CORDIC paralela com precisão de 48 bits em formato Q16.32 para cálculos internos, com entrada e saída em Q16.16.
* **`top_level_calc_cordic.v`**: Módulo de nível superior que abstrai as diferentes implementações CORDIC, permitindo a seleção da operação desejada.
* **Módulos Auxiliares**:
    * **`corr_z_multi.v` / `corr_z_multi_q16_32.v`**: Módulos para correção da entrada `z` para operações de Multiplicação (modo Linear).
    * **`correcao_quadrante_PI_4.v` / `correcao_quadrante_pi_4_q16_32.v`**: Módulos para correção de quadrante para as funções trigonométricas (Seno e Cosseno) no modo Circular.

## Visão Geral do CORDIC

O algoritmo CORDIC é uma técnica iterativa de rotação de vetor que pode ser usada para calcular funções trigonométricas, hiperbólicas e lineares. Ele opera em três modos principais:

* **Circular**: Utilizado para funções trigonométricas como seno, cosseno, arcotangente e módulo.
* **Linear**: Utilizado para multiplicação, divisão e outras operações lineares.
* **Hiperbólico**: Utilizado para seno hiperbólico, cosseno hiperbólico, arcotangente hiperbólica e módulo hiperbólico.

O CORDIC pode operar em dois modos de operação:

* **Rotação (Rotation)**: O vetor $(x, y)$ é girado por um ângulo $z$. O resultado são as novas coordenadas $(x', y')$ e o ângulo restante.
* **Vetorização (Vectoring)**: O vetor $(x, y)$ é girado até que $y$ se torne zero. O resultado é o módulo original do vetor e o ângulo necessário para a rotação.

## Estrutura do Projeto

O projeto é organizado da seguinte forma:

* **`top_level_calc_cordic.v`**: Este é o módulo principal que integra as diferentes implementações CORDIC e os módulos de pré-processamento/pós-processamento. Ele atua como uma interface unificada para todas as operações CORDIC disponíveis.
* **`cordic.v` / `cordic_q16_32.v`**: Contêm as implementações sequenciais do algoritmo CORDIC. 
* **`cordic_parallel.v` / `cordic_parallel_q16_32.v`**: Implementações paralelas do algoritmo CORDIC. Estas versões processam todas as iterações simultaneamente, oferecendo maior throughput em troca de maior área de hardware.
* **`TB_top_level_calc_cordicV3.v`**: Um testbench abrangente para o módulo `top_level_calc_cordic`, que realiza testes para todas as operações implementadas, lendo casos de teste de arquivos externos e reportando erros. 

## Precisão de Ponto Fixo

As implementações CORDIC neste projeto utilizam formatos de ponto fixo para representação de números:

* **Q16.16 (32 bits)**: Utilizado nas versões `cordic.v` e `cordic_parallel.v`. Possui 16 bits para a parte inteira e 16 bits para a parte fracionária.
* **Q16.32 (48 bits)**: Utilizado internamente nas versões `cordic_q16_32.v` e `cordic_parallel_q16_32.v`. Possui 16 bits para a parte inteira e 32 bits para a parte fracionária, o que proporciona maior precisão nos cálculos. A entrada e a saída dessas versões ainda mantém o formato Q16.16 (32 bits).

## Operações Suportadas

O módulo `top_level_calc_cordic` suporta as seguintes operações, controladas pela entrada `operation`:

| Operação Verilog | Valor Binário | Descrição                 | Modo CORDIC               |
| :--------------- | :------------ | :------------------------ | :------------------------ |
| `SIN`            | `4'b0000`     | Seno                      | Circular (Rotação)        |
| `COS`            | `4'b0001`     | Cosseno                   | Circular (Rotação)        |
| `ATAN`           | `4'b0010`     | Arco Tangente             | Circular (Vetorização)    |
| `MOD`            | `4'b0011`     | Módulo/Magnitude          | Circular (Vetorização)    |
| `MULT`           | `4'b0100`     | Multiplicação             | Linear (Rotação)          |
| `DIV`            | `4'b0101`     | Divisão                   | Linear (Vetorização)      |
| `SINH`           | `4'b0110`     | Seno Hiperbólico          | Hiperbólico (Rotação)     |
| `COSH`           | `4'b0111`     | Cosseno Hiperbólico       | Hiperbólico (Rotação)     |
| `ATANH`          | `4'b1000`     | Arco Tangente Hiperbólico | Hiperbólico (Vetorização) |
| `MODH`           | `4'b1001`     | Módulo Hiperbólico        | Hiperbólico (Vetorização) |
| `DEFAULT`        | `4'b1111`     | Sem Uso / Padrão          | -                         |

## Parâmetros Configuráveis

Os módulos CORDIC (sequencial e paralelo) e o módulo de nível superior (`top_level_calc_cordic`) possuem um parâmetro `ITERATIONS` que define o número de iterações do algoritmo CORDIC. Um número maior de iterações geralmente resulta em maior precisão, mas também em maior latência (para versões sequenciais) ou maior área (para versões paralelas). O numero de iterações recomendado é de no máximo 32 para as versões Q16.32 e de 16 para as versões Q16.16. 

### Exemplos de Uso (Referência para `top_level_calc_cordic.v`)

O módulo `top_level_calc_cordic` aceita as seguintes entradas:

```verilog
module top_level_calc_cordic #(
    parameter ITERATIONS = 16 // quantidade de iterações
)(
    input clk,
    input rst,
    input enable,
    input [3:0] operation, // Seleção da operação
    input signed [31:0] x_in, // Entrada X
    input signed [31:0] y_in, // Entrada Y
    input signed [31:0] z_in, // Entrada Z (ângulo para rotação, ou parte do dividendo/multiplicador)
    output signed [31:0] result, // Saída do cálculo
    output done // Sinal de conclusão
);
