"""Static locale checks: every literal key used in Lua exists in each language,
languages have the same keys and parameter counts, and no Cyrillic text is left in Lua code.

    python check_locale.py
"""
import pathlib, re, sys

sys.stdout.reconfigure(encoding='utf-8')
ROOT = pathlib.Path(__file__).resolve().parent
LANGS = ['en', 'ru']


def load(lang):
    keys = {}
    for cfg in sorted((ROOT / 'locale' / lang).glob('*.cfg')):
        section = None
        for n, line in enumerate(cfg.read_text(encoding='utf-8-sig').splitlines(), 1):
            line = line.strip()
            if not line or line[0] in '#;':
                continue
            m = re.fullmatch(r'\[(.+)\]', line)
            if m:
                section = m.group(1)
                continue
            if '=' not in line:
                print(f'{cfg.name}:{n}: not a key=value line')
                continue
            k, v = line.split('=', 1)
            full = f'{section}.{k}' if section else k
            if full in keys:
                print(f'{lang}: duplicate key {full} ({cfg.name}:{n})')
            keys[full] = (v, f'{cfg.name}:{n}')
    return keys


def params(v):
    return {int(x) for x in re.findall(r'__(\d+)__', v)}


errors = 0
tables = {lang: load(lang) for lang in LANGS}
for a in LANGS:
    for b in LANGS:
        if a < b:
            for k in sorted(set(tables[a]) ^ set(tables[b])):
                print(f'key only in {"/".join(l for l in LANGS if k in tables[l])}: {k}')
                errors += 1
            for k in sorted(set(tables[a]) & set(tables[b])):
                if params(tables[a][k][0]) != params(tables[b][k][0]):
                    print(f'parameter mismatch {k}: {a}={sorted(params(tables[a][k][0]))} {b}={sorted(params(tables[b][k][0]))}')
                    errors += 1

sections = {k.split('.')[0] for k in tables['en'] if '.' in k}
used = set()
for lua in sorted(ROOT.rglob('*.lua')):
    rel = lua.relative_to(ROOT).as_posix()
    for n, line in enumerate(lua.read_text(encoding='utf-8').splitlines(), 1):
        code = line.split('--', 1)[0]
        for key in re.findall(r"\{\s*'([a-z0-9-]+\.[a-z0-9-]+)'", code):
            used.add(key)
            if key.split('.')[0] in sections and key not in tables['en']:
                print(f'{rel}:{n}: missing locale key {key}')
                errors += 1
        if re.search('[А-Яа-яЁё]', code):
            print(f'{rel}:{n}: Cyrillic text in code: {code.strip()[:100]}')
            errors += 1

runtime = {k for k in tables['en'] if k.split('.')[0].startswith('tardis-') and k.split('.')[0] in
           {'tardis-voyage', 'tardis-eye', 'tardis-ship', 'tardis-interior', 'tardis-ui'}}
for k in sorted(runtime - used):
    print(f'note: key not referenced literally (may be built dynamically): {k}')

print('OK' if not errors else f'{errors} problem(s)')
sys.exit(1 if errors else 0)
