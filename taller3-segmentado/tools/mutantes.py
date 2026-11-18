#!/usr/bin/env python3
"""
mutantes.py - Comprueba que los programas de prueba CAZAN los defectos de la
seccion 19 de la guia. Inyecta cada defecto en el modelo del pipeline y mira que
programa lo delata (estado final distinto de la referencia). Un defecto que
ningun programa delata es un hueco en las pruebas.

    python3 tools/mutantes.py
"""
import glob, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import modelo

MUTANTES = [
    ("sin_fwd_b",         "solo ForwardAE implementado"),
    ("prio_invertida",    "prioridad invertida (gana MEM/WB)"),
    ("sin_x0",            "falta la condicion rs != 0"),
    ("sin_regwrite",      "falta la condicion RegWrite"),
    ("ex_mem_solo_alu",   "EX/MEM solo lleva el resultado de la ALU"),
    ("sin_stall",         "sin deteccion de load-use"),
    ("stall_sin_burbuja", "para pero no vacia ID/EX (se ejecuta dos veces)"),
    ("burbuja_sin_stall", "vacia ID/EX pero no para (se pierde una instruccion)"),
    ("stall_solo_rs1",    "la condicion de parada solo mira rs1"),
    ("sin_flushd",        "salto tomado sin FlushD"),
    ("sin_flushe_salto",  "salto tomado sin FlushE"),
    ("rf_posedge",        "banco escribe en flanco de subida (falla dist. 3)"),
    ("bit0",              "ResultSrcE: solo el bit 0 (para de mas con lui)"),
]

progs = sorted(glob.glob("prog/*.hex"))
imems = {p: modelo.cargar(p) for p in progs}
ref = {p: modelo.correr_isa(imems[p]) for p in progs}

def correr(p):
    try:
        x, m, c, _ = modelo.correr_pipe(imems[p], max_ciclos=2000)
    except RuntimeError:
        return None, None, "no termina"
    return x, m, c

base = {p: correr(p) for p in progs}
assert all(base[p][0] == ref[p][0] and base[p][1] == ref[p][1] for p in progs), "el modelo sano no coincide"

print(f"{'defecto':20} {'que es':52} delatado por")
print("-" * 110)
huecos = 0
for nombre, desc in MUTANTES:
    modelo.BUGS = {nombre}
    por = []
    for p in progs:
        x, m, c = correr(p)
        if x is None: por.append(os.path.basename(p)[:-4] + "(cuelga)"); continue
        if x != ref[p][0] or m != ref[p][1]: por.append(os.path.basename(p)[:-4])
        elif c != base[p][2]: por.append(os.path.basename(p)[:-4] + "(solo ciclos)")
    modelo.BUGS = set()
    if not por: huecos += 1
    print(f"{nombre:20} {desc:52} {', '.join(por) if por else '*** NADIE ***'}")
print("-" * 110)
print("huecos:", huecos)
sys.exit(1 if huecos else 0)
