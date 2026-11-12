"""Extract function / event / table signatures from Blizzard_APIDocumentationGenerated files.

Usage: python -I tools/extract_api.py <doc.lua> [FuncName ...]
Reads the Lua table literal as text (never executes it) and prints compact signatures.
"""
import re
import sys

TOKEN = re.compile(r'\s+|--[^\n]*|"(?:\\.|[^"\\])*"|[{}=,;]|[A-Za-z_][A-Za-z0-9_.]*|-?\d+(?:\.\d+)?')


def tokens(text):
    pos = 0
    out = []
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            pos += 1
            continue
        t = m.group(0)
        pos = m.end()
        if t.isspace() or t.startswith('--'):
            continue
        out.append(t)
    return out


def parse(toks, i):
    """Parse a value starting at toks[i]; return (value, next_index)."""
    t = toks[i]
    if t == '{':
        i += 1
        arr, dct = [], {}
        while toks[i] != '}':
            if i + 1 < len(toks) and toks[i + 1] == '=' and re.match(r'[A-Za-z_]', toks[i]):
                key = toks[i]
                val, i = parse(toks, i + 2)
                dct[key] = val
            else:
                val, i = parse(toks, i)
                arr.append(val)
            if toks[i] in (',', ';'):
                i += 1
        i += 1
        if dct and arr:
            dct['_array'] = arr
        return (dct if dct else arr), i
    if t.startswith('"'):
        return t[1:-1], i + 1
    if t in ('true', 'false'):
        return t == 'true', i + 1
    return t, i + 1


def load(path):
    text = open(path, encoding='utf-8').read()
    start = text.index('=', text.index('local')) + 1
    toks = tokens(text[start:])
    val, _ = parse(toks, 0)
    return val


def fmt_params(params):
    parts = []
    for p in params or []:
        s = f"{p.get('Name')}: {p.get('Type')}"
        if p.get('InnerType'):
            s += f"<{p['InnerType']}>"
        if p.get('Mixin'):
            s += f" ({p['Mixin']})"
        if p.get('Nilable'):
            s += '?'
        if 'Default' in p:
            s += f" = {p['Default']}"
        parts.append(s)
    return ', '.join(parts)


def main():
    doc = load(sys.argv[1])
    wanted = set(sys.argv[2:])
    ns = doc.get('Namespace', '')
    for f in doc.get('Functions', []):
        if wanted and f['Name'] not in wanted:
            continue
        flags = [k for k in ('HasRestrictions', 'MayReturnNothing', 'IsProtectedFunction') if f.get(k)]
        sec = f.get('SecretArguments')
        if sec:
            flags.append('SecretArguments=' + str(sec))
        print(f"{ns}.{f['Name']}({fmt_params(f.get('Arguments'))}) -> {fmt_params(f.get('Returns')) or 'nil'}"
              + (f"  [{' '.join(flags)}]" if flags else ''))
    if not wanted:
        for e in doc.get('Events', []):
            print(f"EVENT {e.get('LiteralName')}({fmt_params(e.get('Payload'))})")
        for t in doc.get('Tables', []):
            if t.get('Type') == 'Structure':
                print(f"STRUCT {t['Name']} {{{fmt_params(t.get('Fields'))}}}")
            elif t.get('Type') == 'Enumeration':
                vals = ', '.join(f"{v['Name']}={v.get('EnumValue')}" for v in t.get('Fields', []))
                print(f"ENUM {t['Name']} {{{vals}}}")


if __name__ == '__main__':
    main()
