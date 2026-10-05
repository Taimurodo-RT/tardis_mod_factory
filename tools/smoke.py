"""Load the mod in an isolated headless Factorio: create a map, then run it for some ticks."""
import json, pathlib, shutil, subprocess, sys
sys.stdout.reconfigure(encoding='utf-8')
SRC = pathlib.Path(sys.argv[1])
LAB = pathlib.Path(sys.argv[2])
TICKS = sys.argv[3] if len(sys.argv) > 3 else '1200'
GAME = pathlib.Path(r'C:/Program Files (x86)/Steam/steamapps/common/Factorio')
EXE = GAME / 'bin/x64/factorio.exe'
if LAB.exists():
    shutil.rmtree(LAB)
(LAB / 'mods').mkdir(parents=True)
shutil.copytree(SRC, LAB / 'mods/tardis', ignore=shutil.ignore_patterns('.git', '.gitattributes', '.gitignore'))
mods = ['base', 'elevated-rails', 'quality', 'space-age', 'tardis']
if len(sys.argv) > 4:
    shutil.copytree(sys.argv[4], LAB / 'mods/tardis-smoke')
    mods.append('tardis-smoke')
    hook = (LAB / 'mods/tardis/control.lua')
    hook.write_text(hook.read_text(encoding='utf-8') + '''
-- smoke-test hook (lab copy only): mark a ship as fully repaired, like /tardis demo
remote.add_interface('tardis-smoke-hook', {repair_all = function(id)
  local f = M.get(id); f.voyage.console = true; f.voyage.eye = true; f.voyage.message = true; f.energy = M.C.capacity
  for _, key in ipairs(M.EyeCore.order) do M.EyeCore.ensure(f).modules[key] = true end
end})
''', encoding='utf-8')
(LAB / 'mods/mod-list.json').write_text(json.dumps({'mods': [{'name': n, 'enabled': True} for n in mods]}))
(LAB / 'config.ini').write_text('[path]\nread-data=' + str(GAME / 'data') + '\nwrite-data=' + str(LAB) +
                                '\n[general]\nlocale=en\n[other]\ncheck-updates=false\n', encoding='utf-8')
base = [str(EXE), '--config', str(LAB / 'config.ini'), '--mod-directory', str(LAB / 'mods'), '--disable-audio']
save = LAB / 'smoke.zip'
for step, extra in [('create', ['--create', str(save)]),
                    ('benchmark', ['--benchmark', str(save), '--benchmark-ticks', TICKS, '--benchmark-runs', '1'])]:
    r = subprocess.run(base + extra, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=600)
    out = r.stdout + r.stderr
    errors = [l for l in out.splitlines() if 'Error' in l or 'error' in l.lower() and 'Mod' in l]
    print(f'== {step}: exit {r.returncode}')
    print('\n'.join(errors[-20:]) if errors else out[-1500:])
    if r.returncode != 0:
        print(out[-4000:])
        sys.exit(1)
