# =============================================================================
# seg_carga.s - load-use: parada de UN ciclo, burbuja y casos que NO deben parar
#
#   x6=19 x8=19 x10=30       lw seguido de uso por rs1, por rs2 y por ambos
#   x13=16                   lw, una independiente, el uso (no hay parada)
#   Mem[2]=15                lw seguido de sw del dato cargado
#   x16=0 x17=0 x18=1        lw seguido de un beq que se toma
#   x20=4                    la direccion de un lw viene de otro lw
#   x21=4                    lw a x0 y lectura de x0
#   x23=0x2000               lui seguido de uso: NO debe parar
#   x24=15                   acumulador: parar sin burbuja da 23
# =============================================================================
    addi  x1, x0, 15
    sw    x1, 0(x0)             # Mem[0] = 15
    addi  x2, x0, 4
    sw    x2, 4(x0)             # Mem[1] = 4
    nop
    nop

    lw    x5, 0(x0)
    add   x6, x5, x2            # load-use por rs1                  -> 19
    lw    x7, 0(x0)
    add   x8, x2, x7            # load-use por rs2                  -> 19
    lw    x9, 0(x0)
    add   x10, x9, x9           # por los dos                       -> 30

    lw    x11, 0(x0)
    addi  x12, x0, 1            # independiente: la distancia pasa a 2
    add   x13, x11, x12         # sin parada                        -> 16

    lw    x14, 0(x0)
    sw    x14, 8(x0)            # el dato del store viene del load  -> Mem[2] = 15

    lw    x15, 0(x0)
    beq   x15, x1, destino      # se toma: 15 == 15
    addi  x16, x0, 99           # ranura: no debe dejar rastro
    addi  x17, x0, 99           # ranura: no debe dejar rastro
destino:
    addi  x18, x0, 1

    lw    x19, 4(x0)            # x19 = 4
    lw    x20, 0(x19)           # direccion 4 -> Mem[1] = 4         -> 4

    lw    x0, 0(x0)             # el destino es x0
    add   x21, x0, x2           # x21 = 0 + 4                       -> 4

    lui   x22, 1
    add   x23, x22, x22         # lui NO es un load                 -> 0x2000

    addi  x24, x0, 0
    lw    x25, 8(x0)            # Mem[2] = 15 (direccion 8: distinta del dato)
    add   x24, x24, x25         # acumulador: 15. Sin burbuja se ejecuta dos veces
                                # (una con la direccion 8 adelantada, otra con 15) -> 23

fin:
    beq   x0, x0, fin
