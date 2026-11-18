#!/usr/bin/env python3
"""
modelo.py - Dos simuladores de RV32I para el Taller 3.

  isa   ejecuta instruccion por instruccion (la REFERENCIA: lo que "deberia dar")
  pipe  modelo ciclo a ciclo del procesador de cinco etapas, con la MISMA logica
        que riscv_segmentado.sv (forwarding, riesgos, flush, banco a medio ciclo)

Uso:
    python3 tools/modelo.py prog/humo.hex            # estado final y ciclos
    python3 tools/modelo.py prog/humo.hex --traza    # traza etapa por etapa
    python3 tools/modelo.py prog/humo.hex --regs 1,2,3 --mem 0,1

El estado de la referencia es el que hay que comparar contra el procesador.
Un programa "termina" cuando llega a una instruccion que salta a si misma
(el bucle  fin: beq x0, x0, fin  de todos los .s del curso).
"""
import argparse, sys

M = 0xFFFFFFFF
def sx(v, b): return v - (1 << b) if v & (1 << (b - 1)) else v
def s32(v): return sx(v & M, 32)

def cargar(path, depth=256):
    mem = [0x00000013] * depth
    i = 0
    for ln in open(path):
        t = ln.split("//")[0].strip()
        if t:
            mem[i] = int(t.split()[0], 16); i += 1
    return mem

def campos(w):
    return dict(op=w & 0x7F, rd=(w >> 7) & 31, f3=(w >> 12) & 7, rs1=(w >> 15) & 31,
                rs2=(w >> 20) & 31, b30=(w >> 30) & 1)

def inmediato(w, fmt):
    if fmt == "I": return sx(w >> 20, 12)
    if fmt == "S": return sx(((w >> 25) << 5) | ((w >> 7) & 31), 12)
    if fmt == "B": return sx(((w >> 31) << 12) | (((w >> 7) & 1) << 11) | (((w >> 25) & 63) << 5) | (((w >> 8) & 15) << 1), 13)
    if fmt == "J": return sx(((w >> 31) << 20) | (((w >> 12) & 255) << 12) | (((w >> 20) & 1) << 11) | (((w >> 21) & 1023) << 1), 21)
    if fmt == "U": return s32(w & 0xFFFFF000)

# Control: espejo de control_unit.sv. (reg_write, imm, src_a, src_b, mem_write, result_src, branch, jump, jalr, alu_op)
CTRL = {
    0b0110011: (1, "I", 0, 0, 0, 0, 0, 0, 0, "F"),   # R
    0b0010011: (1, "I", 0, 1, 0, 0, 0, 0, 0, "F"),   # I
    0b0000011: (1, "I", 0, 1, 0, 1, 0, 0, 0, "A"),   # load
    0b0100011: (0, "S", 0, 1, 1, 0, 0, 0, 0, "A"),   # store
    0b1100011: (0, "B", 0, 0, 0, 0, 1, 0, 0, "S"),   # branch
    0b1101111: (1, "J", 0, 0, 0, 2, 0, 1, 0, "A"),   # jal
    0b1100111: (1, "I", 0, 1, 0, 2, 0, 1, 1, "A"),   # jalr
    0b0110111: (1, "U", 0, 0, 0, 3, 0, 0, 0, "A"),   # lui
    0b0010111: (1, "U", 1, 1, 0, 0, 0, 0, 0, "A"),   # auipc
}
NULA = (0, "I", 0, 0, 0, 0, 0, 0, 0, "A")

def alu(op, f3, b30, opc, a, b):
    a &= M; b &= M
    if op == "A": k = "add"
    elif op == "S": k = "sub"
    else:
        mod = b30 & (((opc >> 5) & 1) | (1 if (opc == 0b0010011 and f3 == 5) else 0))
        k = {0: "sub" if mod else "add", 1: "sll", 2: "slt", 3: "sltu", 4: "xor",
             5: "sra" if mod else "srl", 6: "or", 7: "and"}[f3]
    r = {"add": a + b, "sub": a - b, "sll": a << (b & 31), "slt": int(s32(a) < s32(b)),
         "sltu": int(a < b), "xor": a ^ b, "srl": a >> (b & 31), "sra": s32(a) >> (b & 31),
         "or": a | b, "and": a & b}[k]
    return r & M

def banderas(a, b): return (a == b, s32(a) < s32(b), (a & M) < (b & M))

def tomado(f3, z, l, lu):
    return {0: z, 1: not z, 4: l, 5: not l, 6: lu, 7: not lu}.get(f3, False)

class Mem:
    def __init__(s, depth=256): s.w = [0] * depth
    def leer(s, addr, f3):
        w = s.w[(addr >> 2) % len(s.w)]; o = addr & 3
        byte = (w >> (8 * o)) & 0xFF; half = (w >> (16 if o & 2 else 0)) & 0xFFFF
        return {0: sx(byte, 8) & M, 1: sx(half, 16) & M, 2: w, 4: byte, 5: half}.get(f3, 0)
    def escribir(s, addr, f3, v):
        i = (addr >> 2) % len(s.w); o = addr & 3
        if f3 == 0: s.w[i] = (s.w[i] & ~(0xFF << (8 * o))) | ((v & 0xFF) << (8 * o))
        elif f3 == 1:
            sh = 16 if o & 2 else 0
            s.w[i] = (s.w[i] & ~(0xFFFF << sh)) | ((v & 0xFFFF) << sh)
        elif f3 == 2: s.w[i] = v & M

# ---------------------------------------------------------------------------
# Referencia: una instruccion por paso
# ---------------------------------------------------------------------------
def correr_isa(imem, max_instr=100000):
    x = [0] * 32; mem = Mem(); pc = 0; n = 0
    while n < max_instr:
        w = imem[(pc >> 2) % len(imem)]; c = campos(w)
        rg, fmt, sa, sb, mw, rs, br, jp, jr, aop = CTRL.get(c["op"], NULA)
        imm = inmediato(w, fmt)
        a = pc if sa else x[c["rs1"]]
        b = imm if sb else x[c["rs2"]]
        r = alu(aop, c["f3"], c["b30"], c["op"], a, b)
        z, l, lu = banderas(x[c["rs1"]], x[c["rs2"]])
        nxt = pc + 4
        if (br and tomado(c["f3"], z, l, lu)) or (jp and not jr): nxt = pc + imm
        if jr: nxt = r & ~1
        if mw: mem.escribir(r, c["f3"], x[c["rs2"]])
        val = {0: r, 1: mem.leer(r, c["f3"]) if rs == 1 else 0, 2: pc + 4, 3: imm}[rs] & M
        if rg and c["rd"]: x[c["rd"]] = val
        n += 1
        if nxt == pc: break                       # bucle fin: salta a si misma
        pc = nxt & M
    return x, mem.w, n

# ---------------------------------------------------------------------------
# Las dos unidades: funciones puras, espejo de los .sv
# ---------------------------------------------------------------------------
BUGS = set()   # defectos inyectables, solo para tools/mutantes.py

def forwarding(rs, rd_m, rw_m, rd_w, rw_w, operando="A"):
    if operando == "B" and "sin_fwd_b" in BUGS: return 0b00
    nz = True if "sin_x0" in BUGS else (rs != 0)
    if "sin_regwrite" in BUGS: rw_m = rw_w = 1
    if "prio_invertida" in BUGS:
        if nz and rw_w and rd_w == rs: return 0b01
        if nz and rw_m and rd_m == rs: return 0b10
        return 0b00
    if nz and rw_m and rd_m == rs: return 0b10
    if nz and rw_w and rd_w == rs: return 0b01
    return 0b00

def riesgos(rs1_d, rs2_d, rd_e, res_e, pcsrc_e):
    cond = (res_e & 1) == 1 if "bit0" in BUGS else (res_e == 1)
    dep = rs1_d == rd_e if "stall_solo_rs1" in BUGS else (rs1_d == rd_e or rs2_d == rd_e)
    lw = cond and dep
    if "sin_stall" in BUGS: lw = False
    sf = sd = lw
    fe = lw or bool(pcsrc_e)
    fd = bool(pcsrc_e)
    if "stall_sin_burbuja" in BUGS: fe = bool(pcsrc_e)
    if "burbuja_sin_stall" in BUGS: sf = sd = False
    if "sin_flushd" in BUGS: fd = False
    if "sin_flushe_salto" in BUGS: fe = lw
    return dict(stall_f=sf, stall_d=sd, flush_d=fd, flush_e=fe)

# ---------------------------------------------------------------------------
# Modelo del pipeline, ciclo a ciclo
# ---------------------------------------------------------------------------
BURBUJA_IFID = dict(instr=0, pc=0, pc4=0)
def burbuja_idex():
    return dict(rd1=0, rd2=0, pc=0, pc4=0, imm=0, rs1=0, rs2=0, rd=0, f3=0, sa=0, sb=0, aluop="A",
                b30=0, opc=0, br=0, jp=0, jr=0, mw=0, rw=0, rs=0, txt="--")
def burbuja_exmem(): return dict(fin=0, res=0, wd=0, rd=0, f3=0, mw=0, rw=0, rs=0, txt="--")
def burbuja_memwb(): return dict(rdata=0, res=0, rd=0, rw=0, rs=0, txt="--")

def correr_pipe(imem, ciclos=None, fin_en=None, traza=False, max_ciclos=100000):
    """Corre hasta que el PC llega a la instruccion 'fin' (o 'ciclos' fijos).
    Devuelve regs, memoria y los ciclos en los que se retiro la ultima instruccion real."""
    from importlib import import_module
    x = [0] * 32; dm = Mem(); pc = 0
    ifid = dict(BURBUJA_IFID); idex = burbuja_idex(); exmem = burbuja_exmem(); memwb = burbuja_memwb()
    stats = dict(stall=0, flush_d=0, flush_e=0)
    ciclo = 0
    while True:
        ciclo += 1
        if stats.get("fetch_fin") is None and imem[(pc >> 2) % len(imem)] == 0x00000063:
            stats["fetch_fin"] = ciclo          # ciclo en que el beq de 'fin' esta en IF
        # ---- WB (el banco escribe a mitad de ciclo, ANTES de que ID lea) ----
        res_w = memwb["rdata"] if memwb["rs"] == 1 else memwb["res"]
        if "rf_posedge" not in BUGS and memwb["rw"] and memwb["rd"]: x[memwb["rd"]] = res_w
        # ---- ID: lectura (ve la escritura de WB) ----
        w = ifid["instr"]; c = campos(w)
        rg, fmt, sa, sb, mw, rs, br, jp, jr, aop = CTRL.get(c["op"], NULA)
        id_ = dict(rd1=x[c["rs1"]], rd2=x[c["rs2"]], pc=ifid["pc"], pc4=ifid["pc4"], imm=inmediato(w, fmt) & M,
                   rs1=c["rs1"], rs2=c["rs2"], rd=c["rd"], f3=c["f3"], sa=sa, sb=sb, aluop=aop, b30=c["b30"],
                   opc=c["op"], br=br, jp=jp, jr=jr, mw=mw, rw=rg, rs=rs, txt=f"{w:08x}" if w else "--")
        if "rf_posedge" in BUGS and memwb["rw"] and memwb["rd"]: x[memwb["rd"]] = res_w
        # ---- EX ----
        e = idex
        fa = forwarding(e["rs1"], exmem["rd"], exmem["rw"], memwb["rd"], memwb["rw"])
        fb = forwarding(e["rs2"], exmem["rd"], exmem["rw"], memwb["rd"], memwb["rw"], "B")
        va = {0: e["rd1"], 2: exmem["res"], 1: res_w, 3: e["rd1"]}[fa]
        vb = {0: e["rd2"], 2: exmem["res"], 1: res_w, 3: e["rd2"]}[fb]
        sa_v = e["pc"] if e["sa"] else va
        sb_v = e["imm"] if e["sb"] else vb
        ar = alu(e["aluop"], e["f3"], e["b30"], e["opc"], sa_v, sb_v)
        z, l, lu = banderas(sa_v, sb_v)
        tgt = (e["pc"] + e["imm"]) & M
        if e["jr"]: tgt = ar & ~1
        pcsrc = (e["br"] and tomado(e["f3"], z, l, lu)) or bool(e["jp"])
        res_e = {0: ar, 1: ar, 2: e["pc4"], 3: e["imm"]}[e["rs"]]
        # ---- MEM ----
        m = exmem
        rdata = 0
        if m["mw"]: dm.escribir(m["res"], m["f3"], m["wd"])
        if m["rs"] == 1: rdata = dm.leer(m["res"], m["f3"])
        # ---- Riesgos ----
        hz = riesgos(c["rs1"], c["rs2"], e["rd"], e["rs"], pcsrc)
        if traza:
            print(f"c{ciclo:<3} pc={pc:#06x} IF/ID={ifid['instr']:08x} ID/EX={e['txt']} "
                  f"fwd=({fa:02b},{fb:02b}) stall={int(hz['stall_f'])} flushD={int(hz['flush_d'])} flushE={int(hz['flush_e'])}")
        stats["stall"] += hz["stall_f"]; stats["flush_d"] += hz["flush_d"]; stats["flush_e"] += hz["flush_e"]
        # ---- Actualizar registros (todos en el mismo flanco) ----
        memwb_n = dict(rdata=rdata, res=m.get("fin", m["res"]), rd=m["rd"], rw=m["rw"], rs=m["rs"], txt=m["txt"])
        exmem_n = dict(fin=res_e & M, res=(ar if "ex_mem_solo_alu" in BUGS else res_e) & M, wd=vb, rd=e["rd"], f3=e["f3"], mw=e["mw"], rw=e["rw"], rs=e["rs"], txt=e["txt"])
        idex_n = burbuja_idex() if hz["flush_e"] else id_
        if hz["flush_d"]: ifid_n = dict(BURBUJA_IFID)
        elif hz["stall_d"]: ifid_n = ifid
        else: ifid_n = dict(instr=imem[(pc >> 2) % len(imem)], pc=pc, pc4=(pc + 4) & M)
        pc_n = pc if hz["stall_f"] else ((tgt if pcsrc else (pc + 4) & M))
        memwb, exmem, idex, ifid, pc = memwb_n, exmem_n, idex_n, ifid_n, pc_n
        # condicion de fin: el beq de bucle esta en EX y se toma a si mismo
        if fin_en is None and e["br"] and pcsrc and tgt == e["pc"] and e["txt"] != "--":
            # el beq esta en EX: le faltan MEM y WB (2 ciclos) para retirarse
            for _ in range(2):
                ciclo += 1
                res_w = memwb["rdata"] if memwb["rs"] == 1 else memwb["res"]
                if memwb["rw"] and memwb["rd"]: x[memwb["rd"]] = res_w
                m = exmem
                if m["mw"]: dm.escribir(m["res"], m["f3"], m["wd"])
                rdata = dm.leer(m["res"], m["f3"]) if m["rs"] == 1 else 0
                memwb = dict(rdata=rdata, res=m["res"], rd=m["rd"], rw=m["rw"], rs=m["rs"], txt=m["txt"])
                exmem = burbuja_exmem()
            return x, dm.w, ciclo, stats
        if ciclos is not None and ciclo >= ciclos: return x, dm.w, ciclo, stats
        if ciclo >= max_ciclos: raise RuntimeError("no termina")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("hex"); ap.add_argument("--traza", action="store_true")
    ap.add_argument("--regs", default=""); ap.add_argument("--mem", default="")
    a = ap.parse_args()
    imem = cargar(a.hex)
    xi, mi, n = correr_isa(imem)
    xp, mp, cyc, st = correr_pipe(imem, traza=a.traza)
    print(f"referencia ISA : {n} instrucciones (= {n} ciclos en el monociclo)")
    print(f"segmentado     : {cyc} ciclos  (paradas load-use={st['stall']}, saltos tomados={st['flush_d']})")
    ok = xi == xp and mi == mp
    print("estado final   :", "IGUAL a la referencia" if ok else "DISTINTO de la referencia  <<<<<")
    if not ok:
        for i in range(32):
            if xi[i] != xp[i]: print(f"  x{i}: ref={xi[i]:#010x} pipe={xp[i]:#010x}")
        for i in range(len(mi)):
            if mi[i] != mp[i]: print(f"  mem[{i}]: ref={mi[i]:#010x} pipe={mp[i]:#010x}")
    for r in filter(None, a.regs.split(",")): print(f"  x{r} = {xi[int(r)]:#010x}")
    for r in filter(None, a.mem.split(",")): print(f"  mem[{r}] = {mi[int(r)]:#010x}")
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
