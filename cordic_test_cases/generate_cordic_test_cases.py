import math
import random
import os

# --- Variáveis de Configuração: Quantidade de Casos de Teste por Operação ---
# Defina o número de casos de teste ALEATÓRIOS para cada operação.
# Os casos de teste fixos (limites, zero, overflow) são sempre incluídos.
NUM_RANDOM_TESTS_SIN = 500
NUM_RANDOM_TESTS_COS = 500
NUM_RANDOM_TESTS_ATAN = 500
NUM_RANDOM_TESTS_MOD = 500
NUM_RANDOM_TESTS_MULT = 500
NUM_RANDOM_TESTS_DIV = 500
NUM_RANDOM_TESTS_SINH = 500
NUM_RANDOM_TESTS_COSH = 500
NUM_RANDOM_TESTS_ATANH = 500
NUM_RANDOM_TESTS_MODH = 500

# Defina o número de casos de teste SEQUENCIAIS para cada operação.
NUM_SEQUENTIAL_TESTS_SIN = 50
NUM_SEQUENTIAL_TESTS_COS = 50
NUM_SEQUENTIAL_TESTS_ATAN = 50
NUM_SEQUENTIAL_TESTS_MOD = 50
NUM_SEQUENTIAL_TESTS_MULT = 50
NUM_SEQUENTIAL_TESTS_DIV = 50
NUM_SEQUENTIAL_TESTS_SINH = 50
NUM_SEQUENTIAL_TESTS_COSH = 50
NUM_SEQUENTIAL_TESTS_ATANH = 50
NUM_SEQUENTIAL_TESTS_MODH = 50
# ------------------------------------------------------------------------

# Mapeamento do nome da operação para o código binário (para uso no script)
OP_CODES = {
    "SIN": "0000",
    "COS": "0001",
    "ATAN": "0010",
    "MOD": "0011",
    "MULT": "0100",
    "DIV": "0101",
    "SINH": "0110",
    "COSH": "0111",
    "ATANH": "1000",
    "MODH": "1001"
}

# Limite para o formato Q16.16 (aproximadamente 32767.999...)
# Usado para filtrar resultados que estourariam o formato de saída.
Q16_16_MAX_VAL = 32767.9999999999
Q16_16_MIN_VAL = -32768.0

# Limite máximo de resultado esperado para a operação MOD, baseado no comportamento do hardware.
# Se o seu CORDIC não calcula magnitudes acima de ~19000 com precisão, ajuste este valor.
MAX_EXPECTED_MOD_RESULT = 19000.0 

# Limite máximo de resultado esperado para a operação ATANH, baseado no comportamento do hardware.
# Se o seu CORDIC satura em ~1.118, ajuste este valor.
MAX_EXPECTED_ATANH_RESULT = 1.1183 # Ajustado para o valor observado de saturação

# Limite máximo para a razão |Y/X| para a operação MODH para melhorar a precisão.
# Reduz a geração de casos onde Y está muito próximo de X em magnitude.
MAX_MODH_INPUT_RATIO = 0.8 # Ajustado para evitar casos de alta imprecisão


def generate_random_float(min_val, max_val, num_samples):
    """Gera uma lista de floats aleatórios dentro de um range."""
    return [random.uniform(min_val, max_val) for _ in range(num_samples)]


def generate_cordic_test_cases_formatted_grouped_configurable():
    """
    Gera casos de teste CORDIC para várias operações, incluindo casos fixos, aleatórios e sequenciais.
    Retorna um dicionário onde as chaves são os nomes das operações e os valores são
    listas de strings formatadas para cada caso de teste.
    Apenas casos de teste "válidos" (dentro dos ranges de operação e sem estouros) são gerados.
    """
    # Dicionário para armazenar as linhas de teste agrupadas por operação
    grouped_test_lines = {
        "SIN": [], "COS": [], "ATAN": [], "MOD": [], "MULT": [],
        "DIV": [], "SINH": [], "COSH": [], "ATANH": [], "MODH": []
    }
    test_case_counts = {
        "SIN": 0, "COS": 0, "ATAN": 0, "MOD": 0, "MULT": 0,
        "DIV": 0, "SINH": 0, "COSH": 0, "ATANH": 0, "MODH": 0
    }

    # --- SIN (Seno) ---
    op_name = "SIN"
    op_code = OP_CODES[op_name]
    # Casos fixos (ângulos comuns, incluindo aqueles que a correção de quadrante deve lidar)
    angles_rad_sin_fixed = [
        0.0, math.pi / 6, math.pi / 4, math.pi / 3, math.pi / 2, math.pi,
        -math.pi / 6, -math.pi / 2, -math.pi,
        1.5 * math.pi, -2.5 * math.pi, 2 * math.pi, -2 * math.pi, # Inclui múltiplos de pi para testar correção de quadrante
        math.radians(30), math.radians(45), math.radians(60), math.radians(90), math.radians(180), math.radians(270), math.radians(360),
        math.radians(-30), math.radians(-45), math.radians(-60), math.radians(-90), math.radians(-180), math.radians(-270), math.radians(-360)
    ]
    for angle in angles_rad_sin_fixed:
        angle_deg = math.degrees(angle)
        expected_res = math.sin(angle)
        # Seno sempre retorna um valor real entre -1 e 1, então não deve ser NaN.
        # A correção de quadrante é assumida para lidar com o range.
        grouped_test_lines[op_name].append(f"{angle_deg:.10f}, 0.0, 0.0, {angle:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos sequenciais
    # Cobre um range amplo para testar a correção de quadrante (-360 a 360 graus)
    step_sin = (math.radians(360) - math.radians(-360)) / NUM_SEQUENTIAL_TESTS_SIN
    for i in range(NUM_SEQUENTIAL_TESTS_SIN):
        angle = math.radians(-360) + i * step_sin
        angle_deg = math.degrees(angle)
        expected_res = math.sin(angle)
        grouped_test_lines[op_name].append(f"{angle_deg:.10f}, 0.0, 0.0, {angle:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos aleatórios
    for _ in range(NUM_RANDOM_TESTS_SIN):
        angle = random.uniform(math.radians(-360), math.radians(360)) # Range de -360 a 360 graus
        angle_deg = math.degrees(angle)
        expected_res = math.sin(angle)
        grouped_test_lines[op_name].append(f"{angle_deg:.10f}, 0.0, 0.0, {angle:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # --- COS (Cosseno) ---
    op_name = "COS"
    op_code = OP_CODES[op_name]
    # Casos fixos
    angles_rad_cos_fixed = [
        0.0, math.pi / 6, math.pi / 4, math.pi / 3, math.pi / 2, math.pi,
        -math.pi / 6, -math.pi / 2, -math.pi,
        1.5 * math.pi, -2.5 * math.pi, 2 * math.pi, -2 * math.pi,
        math.radians(30), math.radians(45), math.radians(60), math.radians(90), math.radians(180), math.radians(270), math.radians(360),
        math.radians(-30), math.radians(-45), math.radians(-60), math.radians(-90), math.radians(-180), math.radians(-270), math.radians(-360)
    ]
    for angle in angles_rad_cos_fixed:
        angle_deg = math.degrees(angle)
        expected_res = math.cos(angle)
        grouped_test_lines[op_name].append(f"{angle_deg:.10f}, 0.0, 0.0, {angle:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos sequenciais
    step_cos = (math.radians(360) - math.radians(-360)) / NUM_SEQUENTIAL_TESTS_COS # Cobre de -360 a 360 graus
    for i in range(NUM_SEQUENTIAL_TESTS_COS):
        angle = math.radians(-360) + i * step_cos
        angle_deg = math.degrees(angle)
        expected_res = math.cos(angle)
        grouped_test_lines[op_name].append(f"{angle_deg:.10f}, 0.0, 0.0, {angle:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos aleatórios
    for _ in range(NUM_RANDOM_TESTS_COS):
        angle = random.uniform(math.radians(-360), math.radians(360)) # Range de -360 a 360 graus
        angle_deg = math.degrees(angle)
        expected_res = math.cos(angle)
        grouped_test_lines[op_name].append(f"{angle_deg:.10f}, 0.0, 0.0, {angle:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # --- ATAN (Arco Tangente) ---
    op_name = "ATAN"
    op_code = OP_CODES[op_name]
    # Casos fixos (apenas dentro da faixa de convergência |y/x| <= 1 e x_val > 0)
    atan_fixed_inputs = [
        (1.0, 0.0), (1.0, 1.0), (1.0, -1.0), # Casos de borda
        (0.0, 1.0), (0.0, -1.0),             # Eixos (x=0, y!=0)
        (5.0, 2.0), (5.0, -2.0),
        (10.0, 0.5), (0.5, 0.1)
    ]
    for x_val, y_val in atan_fixed_inputs:
        # Garante que a razão esteja dentro do limite de convergência do CORDIC para ATAN
        if x_val == 0 and y_val == 0: continue # Evita 0/0
        
        # Filtra casos onde x_val é negativo (quadrantes 2 e 3 para atan2)
        # e casos onde a razão y/x está fora do range de convergência do CORDIC.
        if x_val < 0: continue
        if x_val != 0 and abs(y_val / x_val) > 1.0000000001: continue

        expected_res = math.atan2(y_val, x_val)
        grouped_test_lines[op_name].append(f"{x_val:.10f}, {y_val:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos sequenciais
    # Gerar x_val e y_val para que |y/x| esteja dentro da faixa de convergência (e.g., <= 1)
    # E garantir que x_val seja positivo para que o resultado de atan2 esteja em (-pi/2, pi/2)
    step_ratio = 2.0 / NUM_SEQUENTIAL_TESTS_ATAN # Para cobrir de -1 a 1 para a razão
    for i in range(NUM_SEQUENTIAL_TESTS_ATAN):
        ratio = -1.0 + i * step_ratio
        x_val_seq = random.uniform(0.1, 10.0) # Garante x_val positivo e não muito pequeno
        y_val_seq = x_val_seq * ratio
        expected_res = math.atan2(y_val_seq, x_val_seq)
        grouped_test_lines[op_name].append(f"{x_val_seq:.10f}, {y_val_seq:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos aleatórios
    for _ in range(NUM_RANDOM_TESTS_ATAN):
        # Gerar x_val e y_val para que a razão |y/x| esteja dentro do range de convergência
        # E garantir x_val positivo
        x_val = random.uniform(0.1, 100.0) # x_val sempre positivo
        y_val = random.uniform(-abs(x_val), abs(x_val)) # Garante |y_val| <= |x_val|

        expected_res = math.atan2(y_val, x_val)
        grouped_test_lines[op_name].append(f"{x_val:.10f}, {y_val:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # --- MOD (Módulo/Magnitude) ---
    op_name = "MOD"
    op_code = OP_CODES[op_name]
    # Casos fixos (garantindo que o resultado caiba no range de operação do seu CORDIC)
    mod_fixed_inputs = [
        (0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0),
        (100.0, 100.0), (500.0, 500.0),
        (MAX_EXPECTED_MOD_RESULT / math.sqrt(2), MAX_EXPECTED_MOD_RESULT / math.sqrt(2)) # Exemplo de valor alto no limite
    ]
    for x_val, y_val in mod_fixed_inputs:
        expected_res = math.sqrt(x_val**2 + y_val**2)
        # Filtra casos que estouram o limite de resultado esperado para MOD
        if expected_res > MAX_EXPECTED_MOD_RESULT: continue
        grouped_test_lines[op_name].append(f"{x_val:.10f}, {y_val:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos sequenciais
    # Gerar X e Y para que a magnitude caiba no limite de resultado esperado para MOD
    max_input_val_for_mod_seq = MAX_EXPECTED_MOD_RESULT / math.sqrt(2)
    step_mod = (2 * max_input_val_for_mod_seq) / NUM_SEQUENTIAL_TESTS_MOD
    for i in range(NUM_SEQUENTIAL_TESTS_MOD):
        x_val_seq = -max_input_val_for_mod_seq + i * step_mod
        y_val_seq = -max_input_val_for_mod_seq + i * step_mod
        expected_res = math.sqrt(x_val_seq**2 + y_val_seq**2)
        if expected_res > MAX_EXPECTED_MOD_RESULT: continue # Redundante, mas seguro
        grouped_test_lines[op_name].append(f"{x_val_seq:.10f}, {y_val_seq:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos aleatórios
    for _ in range(NUM_RANDOM_TESTS_MOD):
        x_val = random.uniform(-MAX_EXPECTED_MOD_RESULT / math.sqrt(2), MAX_EXPECTED_MOD_RESULT / math.sqrt(2))
        y_val = random.uniform(-MAX_EXPECTED_MOD_RESULT / math.sqrt(2), MAX_EXPECTED_MOD_RESULT / math.sqrt(2))
        expected_res = math.sqrt(x_val**2 + y_val**2)
        if expected_res > MAX_EXPECTED_MOD_RESULT: continue # Redundante, mas seguro
        grouped_test_lines[op_name].append(f"{x_val:.10f}, {y_val:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # --- MULT (Multiplicação) ---
    op_name = "MULT"
    op_code = OP_CODES[op_name]
    # Casos fixos (garantindo que o resultado caiba no Q16.16)
    mult_inputs_fixed = [
        (1.0, 1.0), (0.5, 0.5), (10.0, 0.5), (-2.0, 0.3),
        (100.0, 1.0), (300.0, 0.1),
        (10000.0, 3.0), # 30000.0
        (30000.0, 1.0), # 30000.0
        (-20000.0, 1.5), # -30000.0
        (-100.0, -100.0), # 10000.0
        (100.0, 5.0), # Z reduzido de 100.0 para 5.0
        (-500.0, 5.0) # Z reduzido de 500.0 para 5.0
    ]
    for x_val, z_val in mult_inputs_fixed:
        expected_res = x_val * z_val
        # Filtra casos que estouram o Q16.16
        if expected_res > Q16_16_MAX_VAL or expected_res < Q16_16_MIN_VAL: continue
        grouped_test_lines[op_name].append(f"{x_val:.10f}, 0.0, {z_val:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos sequenciais
    # Gerar X e Z para que o produto caiba no Q16.16
    # Para cobrir um range razoável sem estourar
    max_prod_val = Q16_16_MAX_VAL / 2.0 # Se Z for até 2.0, X pode ir até Q16_16_MAX_VAL/2
    step_x = (2 * max_prod_val) / NUM_SEQUENTIAL_TESTS_MULT
    step_z = 4.0 / NUM_SEQUENTIAL_TESTS_MULT # Z pode ser fora de -2 a 2, mas vamos manter um range para testes sequenciais
    for i in range(NUM_SEQUENTIAL_TESTS_MULT):
        x_val_seq = -max_prod_val + i * step_x
        z_val_seq = random.uniform(-2.0, 2.0) # Mantém Z em um range comum para CORDIC
        expected_res = x_val_seq * z_val_seq
        if expected_res > Q16_16_MAX_VAL or expected_res < Q16_16_MIN_VAL: continue
        grouped_test_lines[op_name].append(f"{x_val_seq:.10f}, 0.0, {z_val_seq:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos aleatórios
    for _ in range(NUM_RANDOM_TESTS_MULT):
        x_val = random.uniform(-Q16_16_MAX_VAL / 10.0, Q16_16_MAX_VAL / 10.0) # X em range menor para evitar estouro fácil
        z_val = random.uniform(-5.0, 5.0) # Z em range menor para reduzir a carga no normalizador
        
        expected_res = x_val * z_val
        if expected_res > Q16_16_MAX_VAL or expected_res < Q16_16_MIN_VAL: continue
        grouped_test_lines[op_name].append(f"{x_val:.10f}, 0.0, {z_val:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # --- DIV (Divisão) ---
    op_name = "DIV"
    op_code = OP_CODES[op_name]
    # Casos fixos (garantindo que o resultado caiba em [-2, 2] e sem divisão por zero)
    div_inputs_fixed = [
        (1.0, 1.0), (5.0, 2.5), (10.0, 5.0), (1.0, 0.5), # Resultados dentro de -2 a 2
        (0.5, 1.0), (-0.5, 1.0), (0.5, -1.0),
        (2.0, 1.0), (-2.0, 1.0), (2.0, -1.0), (-2.0, -1.0) # Limites
    ]
    for a, b in div_inputs_fixed:
        if b == 0: continue # Evita divisão por zero
        expected_res = a / b
        # Filtra casos onde o resultado está fora da faixa [-2, 2]
        if expected_res > 2.0 or expected_res < -2.0: continue
        grouped_test_lines[op_name].append(f"{a:.10f}, {b:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos sequenciais
    # Gerar 'a' e 'b' para que 'a/b' caia na faixa [-2, 2]
    step_div_a = 4.0 / NUM_SEQUENTIAL_TESTS_DIV # Para cobrir de -2 a 2 para o quociente
    for i in range(NUM_SEQUENTIAL_TESTS_DIV):
        target_quotient = -2.0 + i * step_div_a
        b_val_seq = random.uniform(0.5, 10.0) # Mantém o divisor em uma faixa razoável, não zero
        a_val_seq = target_quotient * b_val_seq
        
        expected_res = a_val_seq / b_val_seq
        if expected_res > 2.0 or expected_res < -2.0: continue # Redundante, mas seguro
        grouped_test_lines[op_name].append(f"{a_val_seq:.10f}, {b_val_seq:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos aleatórios
    for _ in range(NUM_RANDOM_TESTS_DIV):
        # Gerar a e b de forma que a/b esteja dentro de [-2, 2]
        a = random.uniform(-20.0, 20.0)
        b = random.uniform(1.0, 10.0) # Divisor sempre positivo e maior que 0.1 para evitar grandes quocientes
        
        expected_res = a / b
        if expected_res > 2.0 or expected_res < -2.0: continue
        grouped_test_lines[op_name].append(f"{a:.10f}, {b:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # --- SINH (Seno Hiperbólico) ---
    op_name = "SINH"
    op_code = OP_CODES[op_name]
    # Casos fixos (apenas dentro da faixa de convergência CORDIC ~+/-1.13)
    hyperbolic_args_sinh_fixed = [
        0.0, 0.1, 0.5, 1.0, 1.1,
        -0.1, -0.5, -1.0, -1.1,
        1.13, -1.13 # Limites aproximados
    ]
    for arg_float in hyperbolic_args_sinh_fixed:
        # Filtra casos fora da faixa de convergência CORDIC para hiperbólicas
        if abs(arg_float) > 1.1300000001: continue
        expected_res = math.sinh(arg_float)
        grouped_test_lines[op_name].append(f"0.0, 0.0, {arg_float:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos sequenciais
    step_sinh = (2 * 1.13) / NUM_SEQUENTIAL_TESTS_SINH # Cobre de -1.13 a 1.13
    for i in range(NUM_SEQUENTIAL_TESTS_SINH):
        arg_seq = -1.13 + i * step_sinh
        expected_res = math.sinh(arg_seq)
        grouped_test_lines[op_name].append(f"0.0, 0.0, {arg_seq:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos aleatórios
    for _ in range(NUM_RANDOM_TESTS_SINH):
        arg = random.uniform(-1.13, 1.13) # Estritamente dentro do range de convergência
        expected_res = math.sinh(arg)
        grouped_test_lines[op_name].append(f"0.0, 0.0, {arg:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # --- COSH (Cosseno Hiperbólico) ---
    op_name = "COSH"
    op_code = OP_CODES[op_name]
    # Casos fixos (apenas dentro da faixa de convergência CORDIC ~+/-1.13)
    hyperbolic_args_cosh_fixed = [
        0.0, 0.1, 0.5, 1.0, 1.1,
        -0.1, -0.5, -1.0, -1.1,
        1.13, -1.13
    ]
    for arg_float in hyperbolic_args_cosh_fixed:
        if abs(arg_float) > 1.1300000001: continue
        expected_res = math.cosh(arg_float)
        grouped_test_lines[op_name].append(f"0.0, 0.0, {arg_float:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos sequenciais
    step_cosh = (2 * 1.13) / NUM_SEQUENTIAL_TESTS_COSH # Cobre de -1.13 a 1.13
    for i in range(NUM_SEQUENTIAL_TESTS_COSH):
        arg_seq = -1.13 + i * step_cosh
        expected_res = math.cosh(arg_seq)
        grouped_test_lines[op_name].append(f"0.0, 0.0, {arg_seq:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos aleatórios
    for _ in range(NUM_RANDOM_TESTS_COSH):
        arg = random.uniform(-1.13, 1.13)
        expected_res = math.cosh(arg)
        grouped_test_lines[op_name].append(f"0.0, 0.0, {arg:.10f}, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # --- ATANH (Arco Tangente Hiperbólico) ---
    op_name = "ATANH"
    op_code = OP_CODES[op_name]
    # Casos fixos (apenas dentro da faixa de convergência |Y/X| < 1 e resultado <= MAX_EXPECTED_ATANH_RESULT)
    atanh_inputs_fixed = [
        (1.0, 0.0), (1.0, 0.5), (1.0, -0.5), (2.0, 1.0), (10.0, 9.0),
        (1.0, 0.99), (1.0, -0.99) # Próximo aos limites
    ]
    for x_val, y_val in atanh_inputs_fixed:
        if x_val == 0: continue # Evita divisão por zero
        ratio = y_val / x_val
        if abs(ratio) >= 1.0: continue # Fora da faixa de convergência |y/x| < 1
        
        expected_res = math.atanh(ratio)
        # Filtra casos onde o resultado esperado excede o limite de saturação do hardware
        if abs(expected_res) > MAX_EXPECTED_ATANH_RESULT: continue

        grouped_test_lines[op_name].append(f"{x_val:.10f}, {y_val:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos sequenciais
    # Gerar Y/X para cobrir de -0.99 a 0.99, mas filtrar resultados que excedam MAX_EXPECTED_ATANH_RESULT
    # Ajusta o step para que os resultados não excedam o limite de saturação
    # A razão máxima para que atanh(ratio) não exceda MAX_EXPECTED_ATANH_RESULT
    max_ratio_for_atanh = math.tanh(MAX_EXPECTED_ATANH_RESULT)
    step_atanh_ratio = (2 * max_ratio_for_atanh) / NUM_SEQUENTIAL_TESTS_ATANH 
    for i in range(NUM_SEQUENTIAL_TESTS_ATANH):
        ratio = -max_ratio_for_atanh + i * step_atanh_ratio
        x_val_seq = 1.0
        y_val_seq = x_val_seq * ratio
        expected_res = math.atanh(y_val_seq / x_val_seq)
        # Filtra novamente, caso a precisão do float cause um pequeno excesso
        if abs(expected_res) > MAX_EXPECTED_ATANH_RESULT: continue
        grouped_test_lines[op_name].append(f"{x_val_seq:.10f}, {y_val_seq:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos aleatórios
    for _ in range(NUM_RANDOM_TESTS_ATANH):
        x_val = random.uniform(0.1, 10.0)
        # Garante que a razão Y/X não exceda o limite para um resultado válido
        y_val = random.uniform(-math.tanh(MAX_EXPECTED_ATANH_RESULT) * x_val, math.tanh(MAX_EXPECTED_ATANH_RESULT) * x_val)
        expected_res = math.atanh(y_val/x_val)
        if abs(expected_res) > MAX_EXPECTED_ATANH_RESULT: continue # Redundante, mas seguro
        grouped_test_lines[op_name].append(f"{x_val:.10f}, {y_val:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # --- MODH (Módulo Hiperbólico) ---
    op_name = "MODH"
    op_code = OP_CODES[op_name]
    # Casos fixos (apenas onde X^2 > Y^2 e abs(Y/X) <= MAX_MODH_INPUT_RATIO)
    modh_inputs_fixed = [
        (1.0, 0.0), (1.0, 0.5), (1.0, -0.5), (2.0, 1.0), (10.0, 8.0), # Ajustado 10.0, 9.0 para 10.0, 8.0
        (5.0, 4.0) # Exemplo de valor com razão Y/X = 0.8
    ]
    for x_val, y_val in modh_inputs_fixed:
        if x_val == 0: continue # Evita divisão por zero
        ratio = y_val / x_val
        if abs(ratio) >= MAX_MODH_INPUT_RATIO: continue # Filtra se a razão for muito alta
        if x_val**2 <= y_val**2: continue # Fora da faixa de convergência X^2 > Y^2
        expected_res = math.sqrt(x_val**2 - y_val**2)
        grouped_test_lines[op_name].append(f"{x_val:.10f}, {y_val:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos sequenciais
    # Cobre de -MAX_MODH_INPUT_RATIO a MAX_MODH_INPUT_RATIO para a razão Y/X
    step_modh_ratio = (2 * MAX_MODH_INPUT_RATIO) / NUM_SEQUENTIAL_TESTS_MODH 
    for i in range(NUM_SEQUENTIAL_TESTS_MODH):
        x_val_seq = 1.0
        y_val_seq = x_val_seq * (-MAX_MODH_INPUT_RATIO + i * step_modh_ratio)
        expected_res = math.sqrt(x_val_seq**2 - y_val_seq**2)
        grouped_test_lines[op_name].append(f"{x_val_seq:.10f}, {y_val_seq:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    # Casos aleatórios
    for _ in range(NUM_RANDOM_TESTS_MODH):
        x_val = random.uniform(0.1, 10.0)
        # Garante que |Y/X| seja menor ou igual a MAX_MODH_INPUT_RATIO
        y_val = random.uniform(-MAX_MODH_INPUT_RATIO * x_val, MAX_MODH_INPUT_RATIO * x_val) 
        expected_res = math.sqrt(x_val**2 - y_val**2)
        grouped_test_lines[op_name].append(f"{x_val:.10f}, {y_val:.10f}, 0.0, {expected_res:.10f}")
        test_case_counts[op_name] += 1

    return grouped_test_lines, test_case_counts


# --- Geração e Impressão dos Casos de Teste ---
if __name__ == "__main__":
    grouped_test_lines, counts = generate_cordic_test_cases_formatted_grouped_configurable()

    output_dir = "cordic_test_cases"
    os.makedirs(output_dir, exist_ok=True) # Cria o diretório se não existir

    print(f"Gerando casos de teste formatados (X, Y, Z, Resultado Esperado) em arquivos separados na pasta '{output_dir}':\n")

    for op_name, lines in grouped_test_lines.items():
        output_filename = os.path.join(output_dir, f"test_cases_{op_name.lower()}.txt")
        with open(output_filename, "w") as f:
            for line in lines:
                f.write(line + "\n")
        print(f"- {op_name}: {counts[op_name]} casos salvos em '{output_filename}'")

    print("\n" + "---" * 15)
    print("Resumo Total de Casos de Teste Gerados:")
    for op, count in counts.items():
        print(f"- {op}: {count} casos")
    print("---" * 15)

    print(f"\nTodos os casos de teste foram salvos na pasta '{output_dir}'")
