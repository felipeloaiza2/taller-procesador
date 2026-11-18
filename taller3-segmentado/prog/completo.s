# =============================================================================
# completo.s - Programa de prueba del procesador monociclo
#
# Ejercita todos los grupos de instrucciones del ISA obligatorio del proyecto.
# Se ensambla con tools/rvasm.py; NUNCA se escribe el hexadecimal a mano.
#
# Estado esperado al terminar (lo comprueba tb_cpu):
#   x1  = 0x4C       x2  = 10         x3  = 15         x4  = 5
#   x5  = 0          x6  = 15         x7  = 15         x8  = 1
#   x9  = 15         x10 = 1          x11 = 2          x12 = 3
#   x13 = 0x12345000 x14 = 40         x15 = 1
#
# OJO con x1: vale 5 durante la primera mitad del programa, pero al llegar a
# "jal ra, duplica" el hardware escribe PC+4 en ra, y ra ES x1. Por eso al
# final x1 = 0x4C (la direccion de retorno) y no 5.
#
# Esto no es un fallo del procesador: es exactamente por que ra es CALLER-SAVED
# y por que toda funcion no-hoja tiene que guardarlo en el stack. El programa
# lo deja a la vista a proposito.
# =============================================================================

    # --- Constantes con addi (incluye un inmediato negativo, que es donde
    #     fallaba el decodificador de la ALU sin el termino op[5]) ---
    addi  x1, x0, 5             # x1 = 5
    addi  x2, x0, 10            # x2 = 10

    # --- Aritmetica y logica tipo R ---
    add   x3, x1, x2            # x3 = 15
    sub   x4, x2, x1            # x4 = 5
    and   x5, x1, x2            # x5 = 5 & 10 = 0
    or    x6, x1, x2            # x6 = 5 | 10 = 15
    xor   x7, x1, x2            # x7 = 5 ^ 10 = 15
    slt   x8, x1, x2            # x8 = (5 < 10) = 1

    # --- Memoria: store y load de palabra ---
    sw    x3, 0(x0)             # Mem[0] = 15
    lw    x9, 0(x0)             # x9 = 15

    # --- Branch NO tomado: x1 != x2, sigue de largo ---
    beq   x1, x2, mal
    addi  x10, x0, 1            # x10 = 1   (se ejecuta)

    # --- Branch SI tomado: x3 == x9 == 15, salta ---
    beq   x3, x9, salto
    addi  x11, x0, 99           # no debe ejecutarse

salto:
    addi  x11, x0, 2            # x11 = 2
    addi  x12, x0, 3            # x12 = 3

    # --- lui: carga los 20 bits altos ---
    lui   x13, 0x12345          # x13 = 0x12345000

    # --- Llamada a funcion: jal escribe PC+4 en ra, jalr vuelve ---
    addi  x14, x0, 20
    jal   ra, duplica           # ra = direccion de retorno
    # al volver, x14 = 40

    # --- Comparacion sin signo: -1 no es menor que 1 sin signo ---
    addi  x15, x0, -1           # x15 = 0xFFFFFFFF  (inmediato negativo)
    sltu  x15, x15, x1          # x15 = (0xFFFFFFFF < 5) sin signo = 0
    addi  x15, x15, 1           # x15 = 1

fin:
    beq   x0, x0, fin           # bucle infinito: el procesador se queda aqui

mal:
    addi  x10, x0, 99           # marcador de fallo; no debe alcanzarse
    beq   x0, x0, fin

# --- Funcion hoja: duplica x14 ---
duplica:
    add   x14, x14, x14         # x14 = 40
    jalr  x0, 0(ra)             # ret
