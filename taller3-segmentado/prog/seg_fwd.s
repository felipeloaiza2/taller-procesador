# =============================================================================
# seg_fwd.s - Forwarding: distancias, operandos A y B, prioridad, x0, sw, lui, jal
#
# Cada bloque provoca UN defecto de la tabla de la seccion 19. El estado
# esperado lo da la referencia:  python3 tools/modelo.py prog/seg_fwd.hex
#
#   x3=12 x4=12 x5=12   dist 1 por A y por B, y dist 2 de rs1
#   x7=10 x9=20         dist 2 por A y por B
#   x11=60              dist 3 (lo resuelve el banco a medio ciclo)
#   x13=2 x16=4         doble hazard: gana la mas reciente (EX/MEM)
#   x18=9 x19=1 x20=9   rd = x0 seguido de lectura de x0: x0 sigue valiendo 0
#   x25=123             sw con desplazamiento 24 seguido de leer x24
#   x27=0x12345000 x29=0xABCDE000   lui adelantado (dist 1 y dist 2)
#   x31 = x30           jal adelanta PC+4
# =============================================================================
    addi  x1, x0, 5
    addi  x2, x0, 7
    add   x3, x1, x2            # x1 dist 2 (A), x2 dist 1 (B)      -> 12
    add   x4, x3, x0            # x3 dist 1 por A                   -> 12
    add   x5, x0, x4            # x4 dist 1 por B                   -> 12

    addi  x6, x0, 10
    nop
    add   x7, x6, x0            # dist 2 por A                      -> 10
    addi  x8, x0, 20
    nop
    add   x9, x0, x8            # dist 2 por B                      -> 20

    addi  x10, x0, 30
    nop
    nop
    add   x11, x10, x10         # dist 3: ya lo resuelve el banco   -> 60

    # --- doble hazard: dos escrituras seguidas y una lectura ---
    addi  x12, x0, 1
    addi  x12, x0, 2
    add   x13, x12, x0          # debe leer 2, no 1                 -> 2
    addi  x15, x0, 3
    addi  x15, x0, 4
    add   x16, x0, x15          # por B                             -> 4

    # --- rd = x0 seguido de una lectura de x0 ---
    addi  x17, x0, 9
    addi  x0, x17, 5            # escribe x0: se descarta
    add   x18, x17, x0          # B = x0, dist 1: debe seguir en 0  -> 9
    addi  x0, x17, 5
    addi  x19, x0, 1            # A = x0, dist 1                    -> 1
    addi  x0, x17, 5
    nop
    add   x20, x17, x0          # dist 2 (rd=x0 en MEM/WB)         -> 9

    # --- sw con desplazamiento 24: sus bits 11:7 parecen rd = x24 ---
    addi  x24, x0, 123
    addi  x22, x0, 77
    nop
    sw    x22, 24(x0)           # Mem[6] = 77
    add   x25, x24, x0          # debe leer 123, no la direccion 24 -> 123

    # --- lui y jal: el valor definitivo de rd, no el de la ALU ---
    lui   x26, 0x12345
    add   x27, x26, x0          # dist 1                            -> 0x12345000
    lui   x28, 0xABCDE
    nop
    add   x29, x28, x0          # dist 2                            -> 0xABCDE000
    jal   x30, sigue            # x30 = PC+4
sigue:
    add   x31, x30, x0          # dist 1 del jal (el jal salta a la siguiente)

fin:
    beq   x0, x0, fin
