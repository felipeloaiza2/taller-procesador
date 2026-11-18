# =============================================================================
# bytes.s - Los accesos de byte y de media palabra
#
# La memoria guarda una PALABRA por fila, pero la ISA tiene accesos de 8 y de
# 16 bits. Este programa comprueba que leer y escribir un trozo de fila
# funciona y, sobre todo, que no pisa lo que hay al lado.
#
# Una constante de 32 bits no cabe en una instruccion de 32 bits, asi que
# 0xDEADBEEF se carga en dos pasos: lui pone los 20 de arriba y addi los 12 de
# abajo. El addi lleva un inmediato NEGATIVO a proposito.
#
# Estado esperado al terminar:
#   x2  = 0xDEADBEEF   la palabra entera
#   x3  = 0xFFFFFFEF   lb  del byte 0, con signo
#   x4  = 0x000000EF   lbu del byte 0, sin signo
#   x5  = 0xFFFFBEEF   lh  de la media baja, con signo
#   x6  = 0x0000BEEF   lhu de la media baja, sin signo
#   x8  = 0xDEAD55EF   tras sb del 0x55 en el byte 1
#   x10 = 0x012355EF   tras sh del 0x0123 en la media alta
#   x11 = 0x00000123   lhu de la media alta
#   Mem[0] = 0x012355EF
# =============================================================================

    # --- 0xDEADBEEF en dos pasos ---
    lui   x1, 0xDEADC           # x1 = 0xDEADC000
    addi  x1, x1, -273          # x1 = 0xDEADBEEF   (-273 = -0x111)
    sw    x1, 0(x0)             # Mem[0] = 0xDEADBEEF

    # --- Las cinco formas de leer la misma fila ---
    lw    x2, 0(x0)             # x2 = 0xDEADBEEF
    lb    x3, 0(x0)             # x3 = 0xFFFFFFEF
    lbu   x4, 0(x0)             # x4 = 0x000000EF
    lh    x5, 0(x0)             # x5 = 0xFFFFBEEF
    lhu   x6, 0(x0)             # x6 = 0x0000BEEF

    # --- Escribir un byte sin pisar los otros tres ---
    addi  x7, x0, 85            # x7 = 0x55
    sb    x7, 1(x0)             # Mem[0] = 0xDEAD55EF
    lw    x8, 0(x0)             # x8 = 0xDEAD55EF

    # --- Y media palabra, igual ---
    addi  x9, x0, 291           # x9 = 0x123
    sh    x9, 2(x0)             # Mem[0] = 0x012355EF
    lw    x10, 0(x0)            # x10 = 0x012355EF
    lhu   x11, 2(x0)            # x11 = 0x00000123

fin:
    beq   x0, x0, fin           # bucle infinito
