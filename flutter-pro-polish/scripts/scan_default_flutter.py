#!/usr/bin/env python3
"""
scan_default_flutter.py — detector estático dos "tells" de default-Flutter e vibecoding.

Pure Python 3, sem dependências e sem precisar de Flutter instalado. Varre arquivos
.dart e aponta os sinais que dão "cara de Flutter de fábrica" ou "cara de AI/vibecoding":

  warn  missing-app-theme     MaterialApp/CupertinoApp sem `theme:` (= 100% defaults)
  warn  stock-seed-color      ColorScheme.fromSeed(seedColor: Colors.X) ou primarySwatch
  warn  default-typography    arquivo monta ThemeData mas não define fonte/textTheme (Roboto)
  warn  hardcoded-color       Color(0x..) / Colors.X fora do arquivo de tema (cor descentralizada)
  warn  inconsistent-radius   (agregado) raios de canto distintos demais no projeto
  info  magic-spacing         espaçamento "no olho" (ímpar/quebrado) fora de uma escala
  info  material-icons        (agregado) uso intenso de Icons. (icon set padrão do Google)

Uso:
  python scan_default_flutter.py lib/
  python scan_default_flutter.py lib/ --json
  python scan_default_flutter.py lib/ --exit-zero

Sai com código 1 se houver achados `warn` (a menos que --exit-zero). `info` nunca falha.
O scanner é heurístico: é o despertador, não o juiz. Polish final é decisão humana.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from typing import Iterable

# ---------------------------------------------------------------------------
# Arquivos a ignorar
# ---------------------------------------------------------------------------
SKIP_DIRS = {".dart_tool", "build", ".git", "node_modules", ".idea", ".vscode"}
GENERATED_SUFFIXES = (".g.dart", ".freezed.dart", ".gr.dart", ".config.dart", ".pb.dart", ".mocks.dart")

# nomes de arquivo onde cor crua é PERMITIDA (a "casa" das cores/tokens)
THEME_FILE_HINTS = ("theme", "color", "colour", "token", "palette", "design", "style", "scheme", "brand")

STOCK_SWATCHES = (
    "red", "pink", "purple", "deeppurple", "indigo", "blue", "lightblue", "cyan",
    "teal", "green", "lightgreen", "lime", "yellow", "amber", "orange", "deeporange",
    "brown", "grey", "gray", "bluegrey", "bluegray",
)


# ---------------------------------------------------------------------------
# Achado
# ---------------------------------------------------------------------------
@dataclass
class Finding:
    rule: str
    severity: str  # "warn" | "info"
    file: str
    line: int
    message: str
    hint: str = ""

    def to_dict(self) -> dict:
        return asdict(self)


# ---------------------------------------------------------------------------
# Stripping de comentários e strings (preserva newlines p/ números de linha)
# ---------------------------------------------------------------------------
def strip_comments_and_strings(src: str) -> str:
    """Substitui o conteúdo de strings e comentários por espaços, mantendo as
    quebras de linha, para que regex não case dentro de literais/comentários e
    os números de linha continuem corretos."""
    out = []
    i, n = 0, len(src)
    NORMAL, LINE, BLOCK, S1, S2, T1, T2 = range(7)
    state = NORMAL
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if state == NORMAL:
            if c == "/" and nxt == "/":
                state = LINE; out.append("  "); i += 2; continue
            if c == "/" and nxt == "*":
                state = BLOCK; out.append("  "); i += 2; continue
            if c == "'" and src[i:i + 3] == "'''":
                state = T1; out.append("   "); i += 3; continue
            if c == '"' and src[i:i + 3] == '"""':
                state = T2; out.append("   "); i += 3; continue
            if c == "'":
                state = S1; out.append(" "); i += 1; continue
            if c == '"':
                state = S2; out.append(" "); i += 1; continue
            out.append(c); i += 1; continue
        # dentro de comentário/string: preserva só newlines
        if state == LINE:
            if c == "\n":
                state = NORMAL; out.append("\n")
            else:
                out.append(" ")
            i += 1; continue
        if state == BLOCK:
            if c == "*" and nxt == "/":
                state = NORMAL; out.append("  "); i += 2; continue
            out.append("\n" if c == "\n" else " "); i += 1; continue
        if state == S1:
            if c == "\\":
                out.append("  "); i += 2; continue
            if c == "'" or c == "\n":
                state = NORMAL; out.append(" " if c == "'" else "\n")
            else:
                out.append(" ")
            i += 1; continue
        if state == S2:
            if c == "\\":
                out.append("  "); i += 2; continue
            if c == '"' or c == "\n":
                state = NORMAL; out.append(" " if c == '"' else "\n")
            else:
                out.append(" ")
            i += 1; continue
        if state == T1:
            if src[i:i + 3] == "'''":
                state = NORMAL; out.append("   "); i += 3; continue
            out.append("\n" if c == "\n" else " "); i += 1; continue
        if state == T2:
            if src[i:i + 3] == '"""':
                state = NORMAL; out.append("   "); i += 3; continue
            out.append("\n" if c == "\n" else " "); i += 1; continue
    return "".join(out)


def line_of(text: str, idx: int) -> int:
    return text.count("\n", 0, idx) + 1


def matching_paren(text: str, open_idx: int) -> int:
    """Dado o índice de um '(', devolve o índice do ')' correspondente (ou len)."""
    depth = 0
    i = open_idx
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return n


def is_theme_file(path: str) -> bool:
    base = os.path.basename(path).lower()
    return any(h in base for h in THEME_FILE_HINTS)


# ---------------------------------------------------------------------------
# Regras por arquivo
# ---------------------------------------------------------------------------
APP_CTOR_RE = re.compile(r"\b(MaterialApp|CupertinoApp|WidgetsApp)\b(?:\.router)?\s*\(")
FROMSEED_RE = re.compile(r"\bfromSeed\s*\(")
PRIMARYSWATCH_RE = re.compile(r"\bprimarySwatch\s*:\s*Colors\.")
THEMEDATA_RE = re.compile(r"\bThemeData\s*\(")
COLOR_HEX_RE = re.compile(r"\bColor\s*\(\s*0x", re.IGNORECASE)
COLORS_NAMED_RE = re.compile(r"\bColors\.([A-Za-z][A-Za-z0-9]*)")
RADIUS_RE = re.compile(r"\b(?:BorderRadius|Radius)\.circular\s*\(\s*([0-9]+(?:\.[0-9]+)?)\s*\)")
SPACING_CTX_RE = re.compile(r"\b(?:EdgeInsets\.(?:all|symmetric|only|fromLTRB)|SizedBox|Gap)\s*\(")
NUM_RE = re.compile(r"(?<![A-Za-z0-9_.])([0-9]+(?:\.[0-9]+)?)")
ICONS_RE = re.compile(r"\bIcons\.")

TYPOGRAPHY_SIGNALS = ("fontFamily", "GoogleFonts", "textTheme:", "TextTheme(", ".textTheme")


def check_app_theme(rel: str, code: str, findings: list[Finding]) -> None:
    for m in APP_CTOR_RE.finditer(code):
        name = m.group(1)
        open_idx = code.index("(", m.start())
        close_idx = matching_paren(code, open_idx)
        body = code[open_idx:close_idx]
        if "theme:" not in body:
            findings.append(Finding(
                rule="missing-app-theme", severity="warn", file=rel,
                line=line_of(code, m.start()),
                message=f"{name} sem `theme:` — o app está usando 100% dos defaults do Material.",
                hint="Defina theme: (e darkTheme:) com um ThemeData baseado em tokens. Veja assets/app_theme.dart.",
            ))


def check_stock_seed(rel: str, code: str, findings: list[Finding]) -> None:
    for m in FROMSEED_RE.finditer(code):
        open_idx = code.index("(", m.start())
        close_idx = matching_paren(code, open_idx)
        body = code[open_idx:close_idx]
        sm = re.search(r"seedColor\s*:\s*Colors\.([A-Za-z][A-Za-z0-9]*)", body)
        if sm:
            findings.append(Finding(
                rule="stock-seed-color", severity="warn", file=rel,
                line=line_of(code, m.start()),
                message=f"fromSeed com seed de cor stock (Colors.{sm.group(1)}) — gera o esquema genérico de tutorial.",
                hint="Use a cor da marca como seed (Color(0x..)) e ajuste, ou desenhe o ColorScheme à mão. Veja typography-color.md.",
            ))
    for m in PRIMARYSWATCH_RE.finditer(code):
        findings.append(Finding(
            rule="stock-seed-color", severity="warn", file=rel,
            line=line_of(code, m.start()),
            message="primarySwatch: Colors.X é padrão Material 2 e força o visual genérico.",
            hint="Migre para colorScheme/ColorScheme.fromSeed com a cor da marca. Veja typography-color.md.",
        ))


def check_typography(rel: str, code: str, findings: list[Finding]) -> None:
    tm = THEMEDATA_RE.search(code)
    if not tm:
        return
    if any(sig in code for sig in TYPOGRAPHY_SIGNALS):
        return
    findings.append(Finding(
        rule="default-typography", severity="warn", file=rel,
        line=line_of(code, tm.start()),
        message="Tema sem fonte/textTheme definidos — o app cai no Roboto cru (tell clássico de Flutter).",
        hint="Defina fontFamily ou um TextTheme (google_fonts ou fonte empacotada). Veja typography-color.md.",
    ))


def check_hardcoded_colors(rel: str, code: str, findings: list[Finding], cap: int = 8) -> None:
    if is_theme_file(rel):
        return  # cor crua é permitida na "casa" das cores
    def in_seed_context(start: int) -> bool:
        # cor usada como seedColor:/primarySwatch: é construção de tema (já coberta
        # por stock-seed-color) e não conta como cor descentralizada num widget.
        prefix = code[max(0, start - 24):start]
        return "seedColor:" in prefix or "primarySwatch:" in prefix

    hits: list[tuple[int, str]] = []
    for m in COLOR_HEX_RE.finditer(code):
        if in_seed_context(m.start()):
            continue
        hits.append((line_of(code, m.start()), "Color(0x..)"))
    for m in COLORS_NAMED_RE.finditer(code):
        name = m.group(1)
        if name == "transparent":
            continue
        if in_seed_context(m.start()):
            continue
        hits.append((line_of(code, m.start()), f"Colors.{name}"))
    hits.sort()
    for ln, what in hits[:cap]:
        findings.append(Finding(
            rule="hardcoded-color", severity="warn", file=rel, line=ln,
            message=f"Cor crua ({what}) dentro de um widget — cor descentralizada é tell de vibecoding.",
            hint="Mova para o arquivo de tema e consuma via colorScheme.* ou um token semântico. Veja design-tokens.md.",
        ))
    extra = len(hits) - cap
    if extra > 0:
        findings.append(Finding(
            rule="hardcoded-color", severity="warn", file=rel, line=hits[cap][0],
            message=f"(+{extra} outras cores cruas neste arquivo)",
            hint="Centralize todas no arquivo de tema.",
        ))


def check_magic_spacing(rel: str, code: str, findings: list[Finding], cap: int = 6) -> None:
    hits: list[int] = []
    for m in SPACING_CTX_RE.finditer(code):
        open_idx = code.index("(", m.start())
        close_idx = matching_paren(code, open_idx)
        body = code[open_idx + 1:close_idx]
        for nm in NUM_RE.finditer(body):
            raw = nm.group(1)
            val = float(raw)
            if "." in raw:
                # decimais que não são .0/.5 são "no olho"
                frac = val - int(val)
                if abs(frac - 0.0) < 1e-9 or abs(frac - 0.5) < 1e-9:
                    continue
                hits.append(line_of(code, m.start()))
            else:
                iv = int(val)
                # ímpares >= 3 fora de escala (3,5,7,9,11,13,...) são o tell mais forte
                if iv >= 3 and iv % 2 == 1:
                    hits.append(line_of(code, m.start()))
    seen = set()
    uniq = [ln for ln in hits if not (ln in seen or seen.add(ln))]
    for ln in uniq[:cap]:
        findings.append(Finding(
            rule="magic-spacing", severity="info", file=rel, line=ln,
            message="Espaçamento fora de uma escala (valor ímpar/quebrado) — tende a parecer 'no olho'.",
            hint="Use uma escala de espaço (4/8/12/16/24...) via tokens. Veja design-tokens.md.",
        ))


def collect_radii(code: str, acc: dict[str, list[tuple[str, int]]], rel: str) -> None:
    for m in RADIUS_RE.finditer(code):
        val = m.group(1).rstrip("0").rstrip(".") if "." in m.group(1) else m.group(1)
        acc.setdefault(val, []).append((rel, line_of(code, m.start())))


def count_icons(code: str) -> int:
    return len(ICONS_RE.findall(code))


# ---------------------------------------------------------------------------
# Varredura
# ---------------------------------------------------------------------------
def iter_dart_files(root: str) -> Iterable[str]:
    if os.path.isfile(root):
        if root.endswith(".dart"):
            yield root
        return
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if not fn.endswith(".dart"):
                continue
            if fn.endswith(GENERATED_SUFFIXES):
                continue
            yield os.path.join(dirpath, fn)


@dataclass
class Summary:
    files_scanned: int = 0
    warn_count: int = 0
    info_count: int = 0
    distinct_radii: list[str] = field(default_factory=list)
    icons_usages: int = 0


def scan(root: str) -> tuple[list[Finding], Summary]:
    findings: list[Finding] = []
    radii_acc: dict[str, list[tuple[str, int]]] = {}
    icons_total = 0
    files = 0

    for path in iter_dart_files(root):
        files += 1
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                raw = fh.read()
        except OSError:
            continue
        code = strip_comments_and_strings(raw)
        rel = os.path.relpath(path, root if os.path.isdir(root) else os.path.dirname(root) or ".")

        check_app_theme(rel, code, findings)
        check_stock_seed(rel, code, findings)
        check_typography(rel, code, findings)
        check_hardcoded_colors(rel, code, findings)
        check_magic_spacing(rel, code, findings)
        collect_radii(code, radii_acc, rel)
        icons_total += count_icons(code)

    # agregado: raios inconsistentes (achado a nível de projeto)
    distinct = sorted(radii_acc.keys(), key=lambda v: float(v))
    if len(distinct) > 4:
        findings.append(Finding(
            rule="inconsistent-radius", severity="warn", file="(projeto)", line=0,
            message=f"{len(distinct)} raios de canto distintos no projeto ({', '.join(distinct)}) — falta de escala é tell de vibecoding.",
            hint="Reduza para 2-3 raios numa escala (ex.: sm=8, md=12, lg=20) e use via tokens. Veja design-tokens.md.",
        ))

    # agregado: ícones Material
    if icons_total >= 10:
        findings.append(Finding(
            rule="material-icons", severity="info", file="(projeto)", line=0,
            message=f"{icons_total} usos de Icons. (Material Icons) — o icon set padrão tem 'cara de Google'.",
            hint="Considere um set com identidade (lucide_icons_flutter, phosphor_flutter) e use só ele. Veja components.md.",
        ))

    summary = Summary(
        files_scanned=files,
        warn_count=sum(1 for f in findings if f.severity == "warn"),
        info_count=sum(1 for f in findings if f.severity == "info"),
        distinct_radii=distinct,
        icons_usages=icons_total,
    )
    return findings, summary


# ---------------------------------------------------------------------------
# Saída
# ---------------------------------------------------------------------------
def print_human(findings: list[Finding], summary: Summary) -> None:
    if not findings:
        print(f"✅ Nenhum tell de default/vibecoding encontrado em {summary.files_scanned} arquivo(s).")
        return

    by_file: dict[str, list[Finding]] = {}
    for f in findings:
        by_file.setdefault(f.file, []).append(f)

    icon_map = {"warn": "⚠️ ", "info": "ℹ️ "}
    for file in sorted(by_file):
        print(f"\n{file}")
        for f in sorted(by_file[file], key=lambda x: x.line):
            loc = f":{f.line}" if f.line else ""
            print(f"  {icon_map.get(f.severity, '')}[{f.rule}]{loc}")
            print(f"     {f.message}")
            if f.hint:
                print(f"     → {f.hint}")

    print("\n" + "─" * 64)
    print(f"Resumo: {summary.warn_count} warn, {summary.info_count} info "
          f"em {summary.files_scanned} arquivo(s).")
    if len(summary.distinct_radii) > 4:
        print(f"  Raios distintos: {', '.join(summary.distinct_radii)}")
    if summary.icons_usages:
        print(f"  Usos de Icons.: {summary.icons_usages}")
    print("Lembre: o scanner é o despertador, não o juiz. Produza, mostre, itere.")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Detector de tells de default-Flutter e vibecoding.")
    ap.add_argument("path", help="arquivo .dart ou diretório (ex.: lib/)")
    ap.add_argument("--json", action="store_true", help="saída em JSON")
    ap.add_argument("--exit-zero", action="store_true", help="sempre sai com 0 (só reporta)")
    args = ap.parse_args(argv)

    if not os.path.exists(args.path):
        print(f"erro: caminho não encontrado: {args.path}", file=sys.stderr)
        return 2

    findings, summary = scan(args.path)

    if args.json:
        print(json.dumps({
            "findings": [f.to_dict() for f in findings],
            "summary": asdict(summary),
        }, ensure_ascii=False, indent=2))
    else:
        print_human(findings, summary)

    if args.exit_zero:
        return 0
    return 1 if summary.warn_count > 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
