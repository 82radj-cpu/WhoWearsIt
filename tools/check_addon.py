"""Static checks for the addon without Lua or luacheck.

Usage (from anywhere): python -I tools/check_addon.py
Exit code 0 = every check passed.
Checks: TOC files, block/bracket balance, global writes and reads vs .luacheckrc,
locale keys, pure Rules.lua, no donation text, no local paths.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {'Libs', 'tools', 'tests', 'docs', '.github'}
KEYWORDS = set('and break do else elseif end false for function if in local nil not or repeat return then true until while'.split())
errors = []


def err(msg):
    errors.append(msg)


def addon_lua_files():
    out = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith('.')]
        for f in filenames:
            if f.endswith('.lua'):
                out.append(os.path.relpath(os.path.join(dirpath, f), ROOT).replace('/', '\\'))
    return sorted(out)


# ---------- tokenizer (strings and comments removed) ----------
TOK = re.compile(r'''
    (?P<lcomment>--\[(?P<leq>=*)\[.*?\](?P=leq)\])
  | (?P<comment>--[^\n]*)
  | (?P<lstring>\[(?P<seq>=*)\[.*?\](?P=seq)\])
  | (?P<string>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<number>0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?)
  | (?P<op>\.\.\.|\.\.|==|~=|<=|>=|[-+*/%^#<>=(){}\[\];:,.])
  | (?P<ws>\s+)
''', re.S | re.X)


def tokenize(text, path):
    toks, pos, line = [], 0, 1
    while pos < len(text):
        m = TOK.match(text, pos)
        if not m:
            err(f'{path}:{line}: unexpected character {text[pos]!r}')
            pos += 1
            continue
        kind = m.lastgroup
        val = m.group(0)
        if kind in ('name', 'number', 'op'):
            toks.append((kind, val, line))
        elif kind in ('string', 'lstring'):
            toks.append(('string', val, line))
        line += val.count('\n')
        pos = m.end()
    return toks


def check_balance(toks, path):
    stack = []
    pairs = {')': '(', ']': '[', '}': '{'}
    for kind, val, line in toks:
        if kind == 'name' and val in ('function', 'if', 'do', 'repeat'):
            stack.append((val, line))
        elif kind == 'name' and val == 'end':
            if not stack or stack[-1][0] not in ('function', 'if', 'do'):
                err(f'{path}:{line}: "end" without an open block')
                return
            stack.pop()
        elif kind == 'name' and val == 'until':
            if not stack or stack[-1][0] != 'repeat':
                err(f'{path}:{line}: "until" without "repeat"')
                return
            stack.pop()
        elif kind == 'op' and val in '([{':
            stack.append((val, line))
        elif kind == 'op' and val in ')]}':
            if not stack or stack[-1][0] != pairs[val]:
                err(f'{path}:{line}: unbalanced {val!r}')
                return
            stack.pop()
    # "while ... do" and "for ... do" are counted once through "do".
    for val, line in stack:
        err(f'{path}:{line}: "{val}" never closed')


def declared_locals(toks):
    names = set()
    for i, (kind, val, _) in enumerate(toks):
        if kind != 'name':
            continue
        if val in ('local', 'for'):
            j = i + 1
            if j < len(toks) and toks[j][1] == 'function':
                j += 1
            while j < len(toks) and toks[j][0] == 'name' and toks[j][1] not in KEYWORDS:
                names.add(toks[j][1])
                if j + 1 < len(toks) and toks[j + 1][1] == ',':
                    j += 2
                else:
                    break
        if val == 'function':
            j = i + 1
            while j < len(toks) and toks[j][1] != '(':
                j += 1
            j += 1
            while j < len(toks) and toks[j][1] != ')':
                if toks[j][0] == 'name':
                    names.add(toks[j][1])
                j += 1
    names.add('self')
    return names


def global_uses(toks, local_names):
    writes, reads = {}, {}
    depth_brace = 0
    for i, (kind, val, line) in enumerate(toks):
        if kind == 'op' and val == '{':
            depth_brace += 1
        elif kind == 'op' and val == '}':
            depth_brace -= 1
        if kind != 'name' or val in KEYWORDS or val in local_names:
            continue
        prev = toks[i - 1][1] if i else ''
        nxt = toks[i + 1][1] if i + 1 < len(toks) else ''
        if prev in ('.', ':', 'goto'):
            continue
        if depth_brace and nxt == '=' and prev in ('{', ',', ';'):
            continue  # table constructor key
        if prev == 'function' or (nxt == '=' and toks[i + 2][1] != '=' if i + 2 < len(toks) else False):
            writes.setdefault(val, line)
        else:
            reads.setdefault(val, line)
    return writes, reads


def luacheckrc_globals():
    path = os.path.join(ROOT, '.luacheckrc')
    if not os.path.exists(path):
        err('.luacheckrc missing')
        return set(), set()
    text = open(path, encoding='utf-8').read()

    def block(name):
        m = re.search(name + r'\s*=\s*\{(.*?)\n\}', text, re.S)
        return set(re.findall(r'"([A-Za-z_][A-Za-z0-9_]*)"', m.group(1))) if m else set()
    return block(r'\nglobals'), block(r'\nread_globals')


LUA51_STD = set('''assert collectgarbage error getmetatable ipairs load loadstring next pairs pcall print rawequal rawget
rawset select setmetatable tonumber tostring type unpack xpcall math string table os coroutine _G'''.split())


def main():
    files = addon_lua_files()

    # TOC
    toc_path = os.path.join(ROOT, 'WhoWearsIt.toc')
    listed = [l.strip() for l in open(toc_path, encoding='utf-8') if l.strip() and not l.startswith('#')]
    for f in listed:
        if f.startswith('Libs\\'):
            continue
        if not os.path.exists(os.path.join(ROOT, f.replace('\\', os.sep))):
            err(f'TOC lists a missing file: {f}')
    for f in files:
        n = listed.count(f)
        if n != 1:
            err(f'{f} is listed {n} times in the TOC')
    if '## Interface: 16001' not in open(toc_path, encoding='utf-8').read():
        err('TOC Interface is not 16001')

    write_ok, read_ok = luacheckrc_globals()
    all_reads, all_writes = {}, {}
    used_keys, all_strings = set(), set()
    for f in files:
        path = os.path.join(ROOT, f)
        text = open(path, encoding='utf-8').read()
        toks = tokenize(text, f)
        check_balance(toks, f)
        writes, reads = global_uses(toks, declared_locals(toks))
        for k, v in writes.items():
            all_writes.setdefault(k, f'{f}:{v}')
        for k, v in reads.items():
            all_reads.setdefault(k, f'{f}:{v}')
        for m in re.finditer(r'\bL\[\s*"((?:\\.|[^"\\])*)"\s*\]', text):
            if not f.startswith('Locales'):
                used_keys.add(m.group(1))
        for kind, val, _ in toks:
            if kind == 'string' and val[0] in '"\'' and not f.startswith('Locales'):
                all_strings.add(val[1:-1])
        low = text.lower()
        for word in ('donat', 'paypal', 'ko-fi', 'patreon', 'buymeacoffee', 'http://', 'https://'):
            if word in low:
                err(f'{f}: contains "{word}"')
        for pat in (r'[A-Za-z]:\\\\?Users', r'E:\\\\?06_', 'Legion', '82radj'):
            if re.search(pat, text):
                err(f'{f}: contains a local path or personal name ({pat})')
        if f == 'Rules.lua':
            for pat in (r'\bC_\w', r'CreateFrame', r'\bUnit\w*\('):
                if re.search(pat, text):
                    err(f'Rules.lua uses game API ({pat})')

    for name, where in sorted(all_writes.items()):
        if name not in write_ok:
            err(f'global write not allowed in .luacheckrc: {name} ({where})')
    for name, where in sorted(all_reads.items()):
        if name not in read_ok and name not in write_ok and name not in LUA51_STD:
            err(f'global read not listed in .luacheckrc: {name} ({where})')

    # Locale keys
    es_text = open(os.path.join(ROOT, 'Locales', 'esMX.lua'), encoding='utf-8').read()
    es_keys = set(re.findall(r'\["((?:\\.|[^"\\])*)"\]\s*=', es_text))
    en_text = open(os.path.join(ROOT, 'Locales', 'enUS.lua'), encoding='utf-8').read()
    en_keys = set(re.findall(r'"((?:\\.|[^"\\])*)"', en_text.split('ns.LOCALE_KEYS', 1)[1]))
    for k in sorted(used_keys):
        if k not in es_keys:
            err(f'L["{k}"] has no esMX text')
        if k not in en_keys:
            err(f'L["{k}"] missing from enUS LOCALE_KEYS')
    for k in sorted(es_keys | en_keys):
        if k not in used_keys and k not in all_strings:
            err(f'orphan locale key: "{k}"')
    for k in sorted(en_keys ^ es_keys):
        err(f'key only in one of enUS/esMX: "{k}"')

    print(f'checked {len(files)} Lua files, {len(all_reads)} global reads, {len(all_writes)} global writes, '
          f'{len(used_keys)} locale keys')
    for e in errors:
        print('ERROR', e)
    print('OK' if not errors else f'{len(errors)} problem(s)')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
