#!/usr/bin/env python3
"""
scan_overflow_risks.py — scanner heurístico de risco de overflow em Dart/Flutter.

Pré-filtro estático: aponta padrões que costumam estourar (Row com texto sem
flex, lista dentro de Column, form sem scroll, etc.) pra você revisar rápido.
Roda em qualquer máquina com Python 3 — NÃO precisa do Flutter SDK.

IMPORTANTE: é heurística (análise por parênteses/chaves, não AST completo).
Espere alguns falsos positivos e negativos. Use a saída como lista de "olha
aqui", não como verdade — confirme com testes de widget (veja overflow_guard.dart).

Uso:
    python3 scan_overflow_risks.py lib/
    python3 scan_overflow_risks.py lib/widgets/user_tile.dart
    python3 scan_overflow_risks.py lib/ --json
    python3 scan_overflow_risks.py lib/ --exit-zero   # nunca falha (CI informativo)

Saída: lista de achados com arquivo:linha, id da regra e o trecho.
Código de saída: 1 se houver achados, 0 se limpo (use --exit-zero pra sempre 0).
"""

import argparse
import bisect
import json
import os
import re
import sys

# Palavras que vêm antes de "(" mas NÃO são construção de widget.
NON_WIDGET = {
    "if", "for", "while", "switch", "catch", "return", "await", "assert",
    "super", "this", "print", "setState", "sizeOf", "of", "and", "or", "in",
}

TEXT_WIDGETS = {"Text", "TextField", "TextFormField", "RichText", "SelectableText"}
FIELD_WIDGETS = {"TextField", "TextFormField"}
LIST_WIDGETS = {"ListView", "GridView", "PageView", "ReorderableListView", "AnimatedList"}
SCROLLABLES = {"SingleChildScrollView", "CustomScrollView", "ListView", "GridView", "PageView"}
# Widgets que, entre o Text e o Row, resolvem o ajuste horizontal:
SAFE_BETWEEN = {"Expanded", "Flexible", "Wrap", "FittedBox"} | SCROLLABLES
# Widgets que dão altura/largura limitada a uma lista:
BOUNDING = {"Expanded", "Flexible", "SizedBox", "ConstrainedBox", "AspectRatio", "FractionallySizedBox"}

RULES = {
    "row-unflexed-text": "Texto dinâmico dentro de Row sem Expanded/Flexible — risco de overflow horizontal. Envolva o Text em Expanded/Flexible (+ maxLines + TextOverflow.ellipsis) ou troque o Row por Wrap.",
    "list-in-flex": "Lista/grid rolável dentro de {axis} sem limite de tamanho — gera 'unbounded {dim}'. Envolva em Expanded (ou SizedBox), ou use shrinkWrap: true se a lista é curta.",
    "form-no-scroll": "Campo de texto dentro de Scaffold sem scroll em volta — vai estourar embaixo quando o teclado abrir. Envolva o corpo em SingleChildScrollView.",
    "fixed-large-size": "Tamanho fixo grande ({val}px) cravado — costuma caber no seu device e quebrar em outro. Prefira Expanded/Flexible/LayoutBuilder ou fração do espaço.",
    "mediaquery-size": "MediaQuery.of(context).size causa rebuild a cada mudança de métricas. Prefira MediaQuery.sizeOf(context).",
}


class Frame:
    __slots__ = ("name", "base", "open", "close", "parent")

    def __init__(self, name, open_idx, parent):
        self.name = name
        self.base = name.split(".")[0]
        self.open = open_idx
        self.close = None
        self.parent = parent  # índice em frames, ou -1


def parse_frames(src):
    """Extrai chamadas Nome(...) como frames, pulando strings e comentários.

    Retorna a lista de frames. Cada frame conhece seu parente (a chamada que o
    envolve), permitindo subir a árvore depois.
    """
    frames = []
    stack = []  # lista de (is_call, frame_idx_ou_None) pra casar parênteses
    n = len(src)
    i = 0

    def nearest_call_parent():
        for is_call, fidx in reversed(stack):
            if is_call:
                return fidx
        return -1

    while i < n:
        c = src[i]
        # comentário de linha
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        # comentário de bloco
        if c == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue
        # strings (com aspas simples/duplas e triplas)
        if c == '"' or c == "'":
            q = c
            if src[i:i + 3] == q * 3:
                i += 3
                while i + 2 < n and src[i:i + 3] != q * 3:
                    i += 2 if src[i] == "\\" else 1
                i += 3
            else:
                i += 1
                while i < n and src[i] != q:
                    i += 2 if src[i] == "\\" else 1
                i += 1
            continue
        if c == "(":
            # identificador imediatamente antes do "(" (pulando espaços)
            j = i - 1
            while j >= 0 and src[j].isspace():
                j -= 1
            k = j
            while k >= 0 and (src[k].isalnum() or src[k] in "_."):
                k -= 1
            name = src[k + 1:j + 1].strip(".")
            base = name.split(".")[0] if name else ""
            is_call = bool(base) and (base[0].isalpha() or base[0] == "_") and base not in NON_WIDGET
            if is_call:
                idx = len(frames)
                frames.append(Frame(name, i, nearest_call_parent()))
                stack.append((True, idx))
            else:
                stack.append((False, None))
            i += 1
            continue
        if c == ")":
            if stack:
                is_call, fidx = stack.pop()
                if is_call and fidx is not None:
                    frames[fidx].close = i
            i += 1
            continue
        i += 1

    return frames


def line_index(line_starts, pos):
    """Número da linha (1-based) para um índice de caractere."""
    return bisect.bisect_right(line_starts, pos)


def ancestors(frames, f):
    """Itera os frames ancestrais de f, do mais próximo ao mais distante."""
    p = f.parent
    while p != -1:
        yield frames[p]
        p = frames[p].parent


def first_arg(src, f):
    """Primeiro argumento posicional de uma chamada (heurística simples)."""
    if f.close is None:
        return ""
    body = src[f.open + 1:f.close]
    depth = 0
    for idx, ch in enumerate(body):
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            return body[:idx].strip()
    return body.strip()


def text_is_risky(arg):
    """True se o conteúdo do Text parece dinâmico ou longo (risco real)."""
    a = arg.strip()
    if a.startswith("const "):
        a = a[6:].strip()
    if not a:
        return False
    if a[0] in "\"'":
        q = a[0]
        # interpolação => dinâmico => risco
        if "$" in a:
            return True
        # literal puro: só é risco se for longo
        end = a.find(q, 1)
        content = a[1:end] if end != -1 else a[1:]
        return len(content) > 20
    # identificador / expressão => dinâmico => risco
    return True


def scan_source(src, path, findings):
    line_starts = [0] + [m.start() + 1 for m in re.finditer(r"\n", src)]
    frames = parse_frames(src)

    def add(pos, rule, msg):
        findings.append({
            "file": path,
            "line": line_index(line_starts, pos),
            "rule": rule,
            "message": msg,
            "snippet": src[line_starts[line_index(line_starts, pos) - 1]:].split("\n", 1)[0].strip(),
        })

    flagged_scaffolds = set()

    for f in frames:
        # R1: Text "solto" (dinâmico) cujo ancestral Flex mais próximo é um Row
        if f.base in TEXT_WIDGETS and text_is_risky(first_arg(src, f)):
            for a in ancestors(frames, f):
                if a.base in SAFE_BETWEEN:
                    break
                if a.base == "Row":
                    add(f.open, "row-unflexed-text", RULES["row-unflexed-text"])
                    break
                if a.base == "Column":
                    break  # crescimento vertical de um Text só raramente estoura

        # R2: lista rolável dentro de Column/Row sem limite de tamanho
        if f.base in LIST_WIDGETS:
            body = src[f.open + 1:(f.close if f.close else f.open + 1)]
            if re.search(r"shrinkWrap\s*:\s*true", body):
                continue
            for a in ancestors(frames, f):
                if a.base in BOUNDING:
                    break
                if a.base == "Column":
                    add(f.open, "list-in-flex",
                        RULES["list-in-flex"].format(axis="Column", dim="height"))
                    break
                if a.base == "Row":
                    add(f.open, "list-in-flex",
                        RULES["list-in-flex"].format(axis="Row", dim="width"))
                    break
                if a.base in SCROLLABLES:
                    break  # scroll aninhado: outro problema, fora do escopo aqui

        # R3: campo de texto sob Scaffold sem scrollable em volta
        if f.base in FIELD_WIDGETS:
            safe = False
            scaffold_idx = None
            p = f.parent
            while p != -1:
                a = frames[p]
                if a.base in SCROLLABLES:
                    safe = True
                    break
                if a.base == "Scaffold":
                    scaffold_idx = p
                    break
                p = a.parent
            if not safe and scaffold_idx is not None and scaffold_idx not in flagged_scaffolds:
                add(f.open, "form-no-scroll", RULES["form-no-scroll"])
                flagged_scaffolds.add(scaffold_idx)

    # R4 / R5: regex por linha (independem da árvore)
    for m in re.finditer(r"(?<![A-Za-z])(height|width)\s*:\s*(\d+(?:\.\d+)?)", src):
        val = float(m.group(2))
        if val > 400:
            findings.append({
                "file": path,
                "line": line_index(line_starts, m.start()),
                "rule": "fixed-large-size",
                "message": RULES["fixed-large-size"].format(val=m.group(2)),
                "snippet": src[line_starts[line_index(line_starts, m.start()) - 1]:].split("\n", 1)[0].strip(),
            })
    for m in re.finditer(r"MediaQuery\s*\.\s*of\s*\(\s*context\s*\)\s*\.\s*size", src):
        findings.append({
            "file": path,
            "line": line_index(line_starts, m.start()),
            "rule": "mediaquery-size",
            "message": RULES["mediaquery-size"],
            "snippet": src[line_starts[line_index(line_starts, m.start()) - 1]:].split("\n", 1)[0].strip(),
        })


def discover(path):
    if os.path.isfile(path):
        return [path] if path.endswith(".dart") else []
    out = []
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in {".dart_tool", "build", ".git", "node_modules"}]
        for fn in files:
            if fn.endswith(".dart") and not fn.endswith((".g.dart", ".freezed.dart", ".gr.dart", ".config.dart")):
                out.append(os.path.join(root, fn))
    return sorted(out)


def main():
    ap = argparse.ArgumentParser(description="Scanner heurístico de risco de overflow em Dart/Flutter.")
    ap.add_argument("path", help="arquivo .dart ou diretório (ex.: lib/)")
    ap.add_argument("--json", action="store_true", help="saída em JSON")
    ap.add_argument("--exit-zero", action="store_true", help="sempre sai com código 0")
    args = ap.parse_args()

    files = discover(args.path)
    findings = []
    for fp in files:
        try:
            with open(fp, "r", encoding="utf-8") as fh:
                src = fh.read()
        except (OSError, UnicodeDecodeError):
            continue
        scan_source(src, fp, findings)

    findings.sort(key=lambda x: (x["file"], x["line"], x["rule"]))

    if args.json:
        print(json.dumps({"scanned_files": len(files), "findings": findings}, ensure_ascii=False, indent=2))
    else:
        print("flutter-overflow-guard · scanner heurístico")
        print("=" * 44)
        if not findings:
            print(f"Nenhum risco óbvio em {len(files)} arquivo(s). ✅")
            print("(Lembre: heurística não substitui teste — rode os testes de overflow.)")
        else:
            current = None
            for f in findings:
                if f["file"] != current:
                    current = f["file"]
                    print(f"\n{current}")
                print(f"  L{f['line']:<4} [{f['rule']}]")
                print(f"        {f['message']}")
                if f["snippet"]:
                    print(f"        > {f['snippet']}")
            files_with = len({f['file'] for f in findings})
            print(f"\n{files_with} arquivo(s), {len(findings)} achado(s).")
            print("Heurístico — revise cada um e confirme com testes de widget (overflow_guard.dart).")

    sys.exit(0 if (args.exit_zero or not findings) else 1)


if __name__ == "__main__":
    main()
