# =============================================================================
# seg_saltos.s - saltos tomados: las dos instrucciones de detras no dejan rastro
#
#   x4=7  x30=0 x31=0 Mem[4]=0   beq tomado con dos ranuras visibles
#   x5=1                         bne no tomado: sigue de largo
#   x7=2  x28=0 x29=0            jal con dos ranuras
#   x9=5  x10=8 x26=0 x27=0      llamada y retorno con jalr
#   x11=55 x12=11 x14=1 x15=1    bucle 1..10 (9 saltos tomados hacia atras)
# =============================================================================
    addi  x1, x0, 3
    addi  x2, x0, 3
    add   x3, x1, x0
    beq   x3, x2, d1            # x3 dist 1: forwarding en el salto
    addi  x30, x0, 99           # ranura 1: debe morir
    sw    x1, 16(x0)            # ranura 2: debe morir (Mem[4] sigue en 0)
d1:
    addi  x4, x0, 7
    bne   x1, x2, mal           # no se toma
    addi  x5, x0, 1
    jal   x6, d2
    addi  x28, x0, 99
    addi  x29, x0, 99
d2:
    addi  x7, x0, 2

    jal   x1, funcion           # x1 = direccion de retorno
    addi  x9, x0, 5             # se ejecuta al volver, una sola vez
    jal   x0, bucle
mal:
    addi  x5, x0, 99
funcion:
    addi  x10, x0, 8
    jalr  x0, 0(x1)             # ret
    addi  x26, x0, 99           # ranura: debe morir
    addi  x27, x0, 99           # ranura: debe morir

bucle:
    addi  x11, x0, 0
    addi  x12, x0, 1
    addi  x13, x0, 11
lazo:
    add   x11, x11, x12
    addi  x12, x12, 1
    bne   x12, x13, lazo        # x12 dist 1
    addi  x14, x14, 1           # las dos de detras solo cuentan al salir
    addi  x15, x15, 1
fin:
    beq   x0, x0, fin
