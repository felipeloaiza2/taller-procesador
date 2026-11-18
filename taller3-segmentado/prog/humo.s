# =============================================================================
# humo.s - Prueba de humo: lo minimo para saber si el procesador arranca
#
# Cinco instrucciones. Si esto no pasa, no tiene sentido mirar nada mas.
# Ejercita: addi (tipo I), add (tipo R), sw (tipo S) y beq (tipo B).
#
# Estado esperado al terminar:
#   x1 = 5    x2 = 10    x3 = 15    Mem[0] = 15
# =============================================================================

    addi  x1, x0, 5             # x1 = 5
    addi  x2, x0, 10            # x2 = 10
    add   x3, x1, x2            # x3 = 15
    sw    x3, 0(x0)             # Mem[0] = 15

fin:
    beq   x0, x0, fin           # bucle infinito: el procesador se queda aqui
