#!/usr/bin/env python3
"""
rvasm.py - Ensamblador y desensamblador minimo de RV32I.

Existe por una razon concreta: el material de este curso llego a tener tres
programas de prueba con instrucciones escritas a mano en hexadecimal que NO
hacian lo que decia su comentario (un `sw` con offset 1 en vez de 4, un `beq`
que comparaba los registros equivocados, un `sub` que escribia en el registro
equivocado). Los estudiantes validaban su procesador contra vectores rotos.

Nadie deberia volver a escribir un hexadecimal de instruccion a mano.

Uso:
    python3 rvasm.py programa.s -o programa.hex        # ensamblar
    python3 rvasm.py programa.s --mif programa.mif     # generar .mif de Intel
    python3 rvasm.py --decode 0x00A00593               # desensamblar
    python3 rvasm.py --check 0x40110233 "sub x4, x2, x1"   # verificar un hex
"""

import argparse
import re
import sys

# ---------------------------------------------------------------------------
# Registros
# ---------------------------------------------------------------------------
ABI = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
    "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
    "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6",
]
REGS = {f"x{i}": i for i in range(32)}
REGS.update({name: i for i, name in enumerate(ABI)})
REGS["fp"] = 8

# ---------------------------------------------------------------------------
# Tablas de codificacion
# ---------------------------------------------------------------------------
OP_R, OP_I, OP_LOAD, OP_STORE = 0b0110011, 0b0010011, 0b0000011, 0b0100011
OP_BRANCH, OP_JAL, OP_JALR, OP_LUI, OP_AUIPC = 0b1100011, 0b1101111, 0b1100111, 0b0110111, 0b0010111

R_TYPE = {  # nombre: (funct3, funct7)
    "add": (0b000, 0b0000000), "sub": (0b000, 0b0100000),
    "sll": (0b001, 0b0000000), "slt": (0b010, 0b0000000),
    "sltu": (0b011, 0b0000000), "xor": (0b100, 0b0000000),
    "srl": (0b101, 0b0000000), "sra": (0b101, 0b0100000),
    "or": (0b110, 0b0000000), "and": (0b111, 0b0000000),
}
I_TYPE = {"addi": 0b000, "slti": 0b010, "sltiu": 0b011,
          "xori": 0b100, "ori": 0b110, "andi": 0b111}
I_SHIFT = {"slli": (0b001, 0b0000000), "srli": (0b101, 0b0000000),
           "srai": (0b101, 0b0100000)}
LOADS = {"lb": 0b000, "lh": 0b001, "lw": 0b010, "lbu": 0b100, "lhu": 0b101}
STORES = {"sb": 0b000, "sh": 0b001, "sw": 0b010}
BRANCHES = {"beq": 0b000, "bne": 0b001, "blt": 0b100,
            "bge": 0b101, "bltu": 0b110, "bgeu": 0b111}


class AsmError(Exception):
    pass


def reg(tok):
    t = tok.strip().lower()
    if t not in REGS:
        raise AsmError(f"registro desconocido: {tok!r}")
    return REGS[t]


def imm(tok, bits, signed=True):
    t = tok.strip()
    try:
        v = int(t, 0)
    except ValueError:
        raise AsmError(f"inmediato invalido: {tok!r}")
    if signed:
        lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    else:
        lo, hi = 0, (1 << bits) - 1
    if not (lo <= v <= hi):
        raise AsmError(f"inmediato {v} fuera de rango para {bits} bits [{lo}, {hi}]")
    return v & ((1 << bits) - 1)


def bits(value, hi, lo):
    """Extrae value[hi:lo] tratando value como entero sin signo de 32 bits."""
    return (value >> lo) & ((1 << (hi - lo + 1)) - 1)


# ---------------------------------------------------------------------------
# Codificadores por formato
# ---------------------------------------------------------------------------
def enc_r(op, rd, rs1, rs2, f3, f7):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(op, rd, rs1, imm12, f3):
    return ((imm12 & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(op, rs1, rs2, imm12, f3):
    return (bits(imm12, 11, 5) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | (bits(imm12, 4, 0) << 7) | op


def enc_b(op, rs1, rs2, imm13, f3):
    return (bits(imm13, 12, 12) << 31) | (bits(imm13, 10, 5) << 25) | \
           (rs2 << 20) | (rs1 << 15) | (f3 << 12) | \
           (bits(imm13, 4, 1) << 8) | (bits(imm13, 11, 11) << 7) | op


def enc_u(op, rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op


def enc_j(op, rd, imm21):
    return (bits(imm21, 20, 20) << 31) | (bits(imm21, 10, 1) << 21) | \
           (bits(imm21, 11, 11) << 20) | (bits(imm21, 19, 12) << 12) | (rd << 7) | op


# ---------------------------------------------------------------------------
# Ensamblador
# ---------------------------------------------------------------------------
MEM_OPERAND = re.compile(r"^\s*(-?(?:0[xX])?[0-9a-fA-F]+)?\s*\(\s*(\w+)\s*\)\s*$")

PSEUDO = {
    "nop":  lambda a: ("addi", ["x0", "x0", "0"]),
    "mv":   lambda a: ("addi", [a[0], a[1], "0"]),
    "not":  lambda a: ("xori", [a[0], a[1], "-1"]),
    "neg":  lambda a: ("sub",  [a[0], "x0", a[1]]),
    "seqz": lambda a: ("sltiu", [a[0], a[1], "1"]),
    "snez": lambda a: ("sltu", [a[0], "x0", a[1]]),
    "j":    lambda a: ("jal",  ["x0", a[0]]),
    "jr":   lambda a: ("jalr", ["x0", "0(" + a[0] + ")"]),
    "ret":  lambda a: ("jalr", ["x0", "0(ra)"]),
    "beqz": lambda a: ("beq",  [a[0], "x0", a[1]]),
    "bnez": lambda a: ("bne",  [a[0], "x0", a[1]]),
    "bltz": lambda a: ("blt",  [a[0], "x0", a[1]]),
    "bgez": lambda a: ("bge",  [a[0], "x0", a[1]]),
}


def split_operands(rest):
    if not rest.strip():
        return []
    return [p.strip() for p in rest.split(",")]


def parse_line(line):
    """Devuelve (etiqueta, mnemonico, operandos) o (etiqueta, None, [])."""
    line = line.split("#")[0].split("//")[0].strip()
    if not line:
        return None, None, []
    label = None
    if ":" in line:
        label, line = line.split(":", 1)
        label = label.strip()
        line = line.strip()
    if not line:
        return label, None, []
    parts = line.split(None, 1)
    mnem = parts[0].lower()
    ops = split_operands(parts[1]) if len(parts) > 1 else []
    return label, mnem, ops


def assemble(source, base=0):
    """Ensambla texto y devuelve (lista de palabras, lista de (pc, texto))."""
    raw = []
    labels = {}
    pc = base

    # Primera pasada: recoger etiquetas
    for lineno, line in enumerate(source.splitlines(), 1):
        label, mnem, ops = parse_line(line)
        if label is not None:
            if label in labels:
                raise AsmError(f"linea {lineno}: etiqueta duplicada {label!r}")
            labels[label] = pc
        if mnem is None:
            continue
        raw.append((lineno, pc, mnem, ops))
        pc += 4

    # Segunda pasada: codificar
    words, listing = [], []
    for lineno, pc, mnem, ops in raw:
        try:
            if mnem in PSEUDO:
                mnem, ops = PSEUDO[mnem](ops)
            word = encode(mnem, ops, pc, labels)
        except AsmError as e:
            raise AsmError(f"linea {lineno}: {e}")
        words.append(word)
        listing.append((pc, f"{mnem} {', '.join(ops)}"))
    return words, listing


def resolve(tok, pc, labels):
    """Un operando de salto puede ser una etiqueta o un desplazamiento literal."""
    t = tok.strip()
    if t in labels:
        return labels[t] - pc
    try:
        return int(t, 0)
    except ValueError:
        raise AsmError(f"etiqueta o desplazamiento invalido: {tok!r}")


def encode(mnem, ops, pc, labels):
    if mnem in R_TYPE:
        if len(ops) != 3:
            raise AsmError(f"{mnem} necesita 3 operandos")
        f3, f7 = R_TYPE[mnem]
        return enc_r(OP_R, reg(ops[0]), reg(ops[1]), reg(ops[2]), f3, f7)

    if mnem in I_TYPE:
        if len(ops) != 3:
            raise AsmError(f"{mnem} necesita 3 operandos")
        return enc_i(OP_I, reg(ops[0]), reg(ops[1]), imm(ops[2], 12), I_TYPE[mnem])

    if mnem in I_SHIFT:
        if len(ops) != 3:
            raise AsmError(f"{mnem} necesita 3 operandos")
        f3, f7 = I_SHIFT[mnem]
        shamt = imm(ops[2], 5, signed=False)
        return enc_i(OP_I, reg(ops[0]), reg(ops[1]), (f7 << 5) | shamt, f3)

    if mnem in LOADS or mnem in STORES:
        if len(ops) != 2:
            raise AsmError(f"{mnem} necesita 2 operandos, p. ej. 'lw a0, 8(sp)'")
        m = MEM_OPERAND.match(ops[1])
        if not m:
            raise AsmError(f"operando de memoria invalido: {ops[1]!r}")
        off = int(m.group(1), 0) if m.group(1) else 0
        base_reg = reg(m.group(2))
        off_enc = imm(str(off), 12)
        if mnem in LOADS:
            return enc_i(OP_LOAD, reg(ops[0]), base_reg, off_enc, LOADS[mnem])
        return enc_s(OP_STORE, base_reg, reg(ops[0]), off_enc, STORES[mnem])

    if mnem in BRANCHES:
        if len(ops) != 3:
            raise AsmError(f"{mnem} necesita 3 operandos")
        off = resolve(ops[2], pc, labels)
        if off % 2:
            raise AsmError(f"desplazamiento de salto impar: {off}")
        if not (-4096 <= off <= 4094):
            raise AsmError(f"desplazamiento {off} fuera del alcance de un branch (+-4 KiB)")
        return enc_b(OP_BRANCH, reg(ops[0]), reg(ops[1]), off & 0x1FFF, BRANCHES[mnem])

    if mnem == "jal":
        if len(ops) == 1:
            rd_v, target = 1, ops[0]          # jal etiqueta => rd = ra
        elif len(ops) == 2:
            rd_v, target = reg(ops[0]), ops[1]
        else:
            raise AsmError("jal necesita 1 o 2 operandos")
        off = resolve(target, pc, labels)
        if off % 2:
            raise AsmError(f"desplazamiento de salto impar: {off}")
        if not (-(1 << 20) <= off <= (1 << 20) - 2):
            raise AsmError(f"desplazamiento {off} fuera del alcance de jal (+-1 MiB)")
        return enc_j(OP_JAL, rd_v, off & 0x1FFFFF)

    if mnem == "jalr":
        if len(ops) == 2:
            m = MEM_OPERAND.match(ops[1])
            if not m:
                raise AsmError(f"operando invalido para jalr: {ops[1]!r}")
            off = int(m.group(1), 0) if m.group(1) else 0
            return enc_i(OP_JALR, reg(ops[0]), reg(m.group(2)), imm(str(off), 12), 0b000)
        if len(ops) == 3:
            return enc_i(OP_JALR, reg(ops[0]), reg(ops[1]), imm(ops[2], 12), 0b000)
        raise AsmError("jalr necesita 2 o 3 operandos")

    if mnem in ("lui", "auipc"):
        if len(ops) != 2:
            raise AsmError(f"{mnem} necesita 2 operandos")
        op = OP_LUI if mnem == "lui" else OP_AUIPC
        return enc_u(op, reg(ops[0]), imm(ops[1], 20, signed=False))

    raise AsmError(f"instruccion no soportada: {mnem!r}")


# ---------------------------------------------------------------------------
# Desensamblador (para verificar hexadecimales del material)
# ---------------------------------------------------------------------------
def sext(v, bits_n):
    if v & (1 << (bits_n - 1)):
        return v - (1 << bits_n)
    return v


def decode(word):
    word &= 0xFFFFFFFF
    op = word & 0x7F
    rd = bits(word, 11, 7)
    f3 = bits(word, 14, 12)
    rs1 = bits(word, 19, 15)
    rs2 = bits(word, 24, 20)
    f7 = bits(word, 31, 25)

    def rn(i):
        return f"x{i}"

    if op == OP_R:
        for name, (a, b) in R_TYPE.items():
            if a == f3 and b == f7:
                return f"{name} {rn(rd)}, {rn(rs1)}, {rn(rs2)}"
        return f".word 0x{word:08X}  # R-type desconocida"

    if op == OP_I:
        if f3 in (0b001, 0b101):
            for name, (a, b) in I_SHIFT.items():
                if a == f3 and b == bits(word, 31, 25):
                    return f"{name} {rn(rd)}, {rn(rs1)}, {bits(word, 24, 20)}"
            return f".word 0x{word:08X}  # shift desconocido"
        for name, a in I_TYPE.items():
            if a == f3:
                return f"{name} {rn(rd)}, {rn(rs1)}, {sext(bits(word, 31, 20), 12)}"
        return f".word 0x{word:08X}"

    if op == OP_LOAD:
        for name, a in LOADS.items():
            if a == f3:
                return f"{name} {rn(rd)}, {sext(bits(word, 31, 20), 12)}({rn(rs1)})"
        return f".word 0x{word:08X}"

    if op == OP_STORE:
        off = sext((f7 << 5) | rd, 12)
        for name, a in STORES.items():
            if a == f3:
                return f"{name} {rn(rs2)}, {off}({rn(rs1)})"
        return f".word 0x{word:08X}"

    if op == OP_BRANCH:
        off = sext((bits(word, 31, 31) << 12) | (bits(word, 7, 7) << 11) |
                   (bits(word, 30, 25) << 5) | (bits(word, 11, 8) << 1), 13)
        for name, a in BRANCHES.items():
            if a == f3:
                return f"{name} {rn(rs1)}, {rn(rs2)}, {off}"
        return f".word 0x{word:08X}"

    if op == OP_JAL:
        off = sext((bits(word, 31, 31) << 20) | (bits(word, 19, 12) << 12) |
                   (bits(word, 20, 20) << 11) | (bits(word, 30, 21) << 1), 21)
        return f"jal {rn(rd)}, {off}"

    if op == OP_JALR:
        return f"jalr {rn(rd)}, {sext(bits(word, 31, 20), 12)}({rn(rs1)})"

    if op == OP_LUI:
        return f"lui {rn(rd)}, 0x{bits(word, 31, 12):X}"

    if op == OP_AUIPC:
        return f"auipc {rn(rd)}, 0x{bits(word, 31, 12):X}"

    return f".word 0x{word:08X}  # opcode desconocido"


# ---------------------------------------------------------------------------
# Salidas
# ---------------------------------------------------------------------------
def to_hex(words, listing):
    out = []
    for (pc, text), w in zip(listing, words):
        out.append(f"{w:08x}  // 0x{pc:03x}: {text}")
    return "\n".join(out) + "\n"


def to_mif(words, listing, depth=256):
    lines = ["WIDTH=32;", f"DEPTH={depth};", "", "ADDRESS_RADIX=HEX;",
             "DATA_RADIX=HEX;", "", "CONTENT BEGIN"]
    for i, (w, (pc, text)) in enumerate(zip(words, listing)):
        lines.append(f"    {i:03X} : {w:08X};   -- {text}")
    if len(words) < depth:
        lines.append(f"    [{len(words):03X}..{depth - 1:03X}] : 00000013;   -- nop")
    lines.append("END;")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description="Ensamblador minimo de RV32I")
    ap.add_argument("source", nargs="?", help="archivo .s")
    ap.add_argument("-o", "--output", help="archivo .hex de salida (para $readmemh)")
    ap.add_argument("--mif", help="archivo .mif de salida (formato Intel)")
    ap.add_argument("--depth", type=int, default=256, help="profundidad de la memoria")
    ap.add_argument("--decode", help="desensamblar una palabra, p. ej. 0x00A00593")
    ap.add_argument("--check", nargs=2, metavar=("HEX", "ASM"),
                    help="verificar que HEX codifica ASM")
    args = ap.parse_args()

    if args.decode:
        w = int(args.decode, 0)
        print(f"0x{w:08X}  =  {decode(w)}")
        return 0

    if args.check:
        hex_s, asm_s = args.check
        want = int(hex_s, 0)
        words, _ = assemble(asm_s)
        got = words[0]
        if got == want:
            print(f"OK    0x{want:08X}  =  {asm_s}")
            return 0
        print(f"FALLO 0x{want:08X} no codifica {asm_s!r}")
        print(f"      0x{want:08X}  es  {decode(want)}")
        print(f"      {asm_s!r}  es  0x{got:08X}")
        return 1

    if not args.source:
        ap.error("hace falta un archivo fuente, --decode o --check")

    with open(args.source) as f:
        src = f.read()

    try:
        words, listing = assemble(src)
    except AsmError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    if args.output:
        with open(args.output, "w") as f:
            f.write(to_hex(words, listing))
        print(f"escrito {args.output} ({len(words)} instrucciones)")
    if args.mif:
        with open(args.mif, "w") as f:
            f.write(to_mif(words, listing, args.depth))
        print(f"escrito {args.mif} ({len(words)} instrucciones)")
    if not args.output and not args.mif:
        sys.stdout.write(to_hex(words, listing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
